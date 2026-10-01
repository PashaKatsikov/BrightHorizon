import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../app/chrome_guard.dart';
import '../../app/relay_theme.dart';
import '../config/relay_config.dart';
import '../wire/alert_channel.dart';
import '../wire/beacon_keystore.dart';
import '../wire/device_signature.dart';
import '../wire/pulse_probe.dart';
import '../wire/veiled_strings.dart';
import '../wire/web_scripts.dart';
import 'offline_stage.dart';

// ============================================================
// PORTAL STAGE — the WebView shell
// ============================================================
// Hosts the destination URL with:
//   • forged device UA (identical to the HTTP client's UA)
//   • both orientations, fully immersive system UI
//   • external-scheme hand-off (tel:, mailto:, intent://, tg:, …)
//   • redirect-loop recovery (bounded retry on -1007 / -9)
//   • live connectivity guard (debounced)
//   • warm push URL delivery via [AlertChannel.onIncomingUrl]
//   • native file chooser over a MethodChannel (no file_picker dep)
//   • JS behaviours composed by `WebScripts.installAll`
//
// There is NO client-side classification of the partner site — no
// matching on funnel keywords, no payment or sign-up detection, no
// funnel events. Any funnel the business needs lives server side; this
// is a dumb shell.
//
// ─────────────────────────────────────────────────────────────
// INSET MODEL (the part that is easy to get wrong)
// ─────────────────────────────────────────────────────────────
// The WebView is laid out ONCE and never resizes while it is on screen:
//
//   • The navigation bar contributes NO inset. Bars are hidden through
//     `immersiveSticky`; a swipe — OR the IME in landscape — reveals them
//     as a transient overlay drawn ON TOP of the page (see `MainActivity`
//     — the window is edge-to-edge and does not fit system windows). We
//     must therefore NOT derive the WebView inset from
//     `MediaQuery.viewPadding`: that value folds the nav-bar inset back in
//     the moment the keyboard forces the bar visible in landscape, which
//     would shove the page up and leave a dead band under the bar.
//   • The camera cutout DOES inset. `NormalTheme` sets
//     `windowLayoutInDisplayCutoutMode=shortEdges`, so Android reports the
//     notch on whichever edge it sits (a long edge in landscape). The cutout
//     is cached PER ORIENTATION and applied synchronously, so a rotation
//     resizes the WebView exactly once at the already-known new size. Each
//     orientation's inset is seeded from the engine's viewPadding (bars are
//     hidden under immersive, so viewPadding == the cutout) and confirmed by
//     the native `cutout` call (`_refreshCutout`), which excludes the bars.
//     We inset by the cutout alone, dropping the bottom entirely so the nav
//     bar stays a pure overlay (`gray_part_pitfalls.md` §14).
//   • The keyboard contributes NO inset either. The window does not pan
//     or resize for the IME (`MainActivity`), so the WebView keeps its
//     full height and the keyboard simply draws over the bottom of the
//     page. Instead of shrinking the WebView, we read the IME height
//     from the Flutter engine (`FlutterView.viewInsets.bottom` — reliable
//     in both orientations, unlike a native channel), turn it into a
//     fraction of the visible height, and push it into the page through
//     `window.__hzSetKb(fraction)`. The keyboard JS enhancer then lifts
//     the focused field's fixed container (or scrolls) so the field lands
//     directly above the keyboard on the first frame.
//
// A `MediaQuery` override zeroes the keyboard viewInset and the system-bar
// padding for the WebView subtree, so the platform view can never observe
// either and resize itself. Only the manual notch padding reaches it.
// This is also why the WebView is NOT wrapped in `SafeArea`.
// ============================================================

class PortalStage extends StatefulWidget {
  const PortalStage({
    super.key,
    required this.url,
    required this.keystore,
    required this.alerts,
  });

  final String url;
  final BeaconKeystore keystore;
  final AlertChannel alerts;

  @override
  State<PortalStage> createState() => _PortalStageState();
}

class _PortalStageState extends State<PortalStage> with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _spinner = true;
  bool _offlineShown = false;
  String? _lastMainFrame;
  int _retryCounter = 0;
  Timer? _dropDebounce;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  final PulseProbe _probe = PulseProbe();
  ui.FlutterView? _view;

  // Logical-pixel camera-cutout safe insets, cached PER ORIENTATION. Both
  // orientations' sizes become known after each has been seen once, so a
  // rotation reuses the target orientation's cached inset in the SAME layout
  // pass — the WebView resizes exactly once, with no second async step.
  //
  // Each orientation is seeded ONCE, synchronously, from the engine's
  // viewPadding (bars are hidden under immersive, so viewPadding == the
  // cutout); after that, updates belong solely to the authoritative native
  // `cutout` query, which excludes the navigation bar on every edge. The
  // one-time seed is also skipped while the IME is up. This matters on
  // keyboard close in landscape: there viewPadding briefly folds the
  // IME-revealed nav bar's side inset back in, and re-sampling it would
  // reserve a stray safe area under the bar for a couple of frames.
  final Map<Orientation, EdgeInsets> _cutoutByOrientation =
      <Orientation, EdgeInsets>{};

  /// Current orientation from the engine's physical size. Keyed consistently
  /// with the build-time orientation used by [_webInsets].
  Orientation _viewOrientation() {
    final Size? size = _view?.physicalSize;
    if (size == null || size.height <= 0) return Orientation.portrait;
    return size.width > size.height
        ? Orientation.landscape
        : Orientation.portrait;
  }

  // [FORGE] Rotated per project. Keep in sync with MainActivity.kt →
  // `channelName`.
  static const MethodChannel _uploadChannel = MethodChannel('hzn/chooser');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    applyImmersiveChrome();
    _buildController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCutout());

    widget.alerts.onIncomingUrl = (String url) {
      if (mounted) _web.loadRequest(Uri.parse(url));
    };

    // Debounce connectivity drops — a VPN reconnect or a brief cell
    // switch produces a burst of `none` events that must not fire the
    // offline stage (`gray_part_pitfalls.md` §3).
    _connSub = _probe.statusStream.listen((List<ConnectivityResult> r) {
      final bool allNone = r.isNotEmpty &&
          r.every((ConnectivityResult e) => e == ConnectivityResult.none);
      if (!allNone) {
        _dropDebounce?.cancel();
        return;
      }
      _dropDebounce?.cancel();
      _dropDebounce = Timer(
        Duration(milliseconds: RelayConfig.reachDropDebounceMs),
        _showOffline,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.maybeOf(context);
  }

  /// One-time synchronous cutout seed for an orientation not yet in the
  /// cache, applied in the same frame as the first rotation into it so the
  /// WebView lays out once at the new size. Under immersive the system bars
  /// are hidden, so the engine's viewPadding equals the camera cutout.
  ///
  /// Only seeds a NOT-yet-cached orientation — once known, updates belong
  /// solely to the authoritative native [_refreshCutout]. That is deliberate:
  /// on keyboard close in landscape there is a frame where viewInsets.bottom
  /// is already 0 but the IME-revealed nav bar is still fading, and viewPadding
  /// folds that bar's SIDE inset in. Re-seeding then would reserve a safe area
  /// under the nav bar for a couple of frames. Skipping cached orientations
  /// (and skipping while the IME is up) prevents that entirely.
  void _syncCutout() {
    final ui.FlutterView? view = _view;
    if (view == null) return;
    final Orientation o = _viewOrientation();
    if (_cutoutByOrientation.containsKey(o)) return;
    if (view.viewInsets.bottom > 0) return;
    final double dpr = view.devicePixelRatio;
    if (dpr <= 0) return;
    final ui.ViewPadding p = view.viewPadding;
    setState(() {
      _cutoutByOrientation[o] = EdgeInsets.only(
        top: p.top / dpr,
        left: p.left / dpr,
        right: p.right / dpr,
      );
    });
  }

  /// Authoritative camera-cutout query (native, nav-bar-excluded) for the
  /// CURRENT orientation, stored in the per-orientation cache. The synchronous
  /// [_syncCutout] seed usually already holds this value, so this only
  /// confirms it — no second layout pass. Cheap enough to call on every
  /// metrics change; the cutout is stable across keyboard show/hide and only
  /// actually moves on rotation.
  Future<void> _refreshCutout() async {
    try {
      final Map<Object?, Object?>? m = await _uploadChannel
          .invokeMethod<Map<Object?, Object?>>(VeiledStrings.get('mc_cut'));
      if (m == null || !mounted) return;
      double at(String k) => (m[k] as num?)?.toDouble() ?? 0.0;
      final EdgeInsets next = EdgeInsets.only(
        top: at(VeiledStrings.get('in_top')),
        left: at(VeiledStrings.get('in_left')),
        right: at(VeiledStrings.get('in_right')),
      );
      final Orientation o = _viewOrientation();
      if (_cutoutByOrientation[o] != next) {
        setState(() => _cutoutByOrientation[o] = next);
      }
    } catch (_) {
      // Pre-P devices (no cutout) or an early call before the window has
      // insets — leave the cache; a later metrics change re-queries.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the file chooser or an external app restores the
    // system bars — re-hide them.
    if (state == AppLifecycleState.resumed) applyImmersiveChrome();
  }

  @override
  void didChangeMetrics() {
    // Fires on keyboard show/hide and on rotation. The window itself does
    // not resize for the IME (see MainActivity), so this is the only
    // signal that the geometry changed.
    //
    // Rotation is applied in a SINGLE step: `_syncCutout` sets the new
    // orientation's cutout synchronously (the WebView resizes once in this
    // frame), and the async native `_refreshCutout` only confirms it.
    _syncCutout();
    _pushKeyboardFraction();
    _refreshCutout();
  }

  /// Turns the engine-reported IME height into a 0..1 fraction of the
  /// visible height (minus the camera cutout) and hands it to the page's
  /// single setter. Units cancel, so a fraction is orientation-agnostic.
  void _pushKeyboardFraction() {
    final ui.FlutterView? view = _view;
    if (view == null) return;
    final double dpr = view.devicePixelRatio;
    if (dpr <= 0) return;
    final double keyboard = view.viewInsets.bottom / dpr;
    final double topCutout = view.viewPadding.top / dpr;
    final double screenH = view.physicalSize.height / dpr;
    final double visible = screenH - topCutout;
    final double fraction =
        visible > 1 ? (keyboard / visible).clamp(0.0, 1.0) : 0.0;
    _runJsSafely('window.__hzSetKb && window.__hzSetKb($fraction);');
  }

  void _runJsSafely(String js) {
    // runJavaScript throws before the first document exists; ignore that.
    _web.runJavaScript(js).catchError((Object _) {});
  }

  void _buildController() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(DeviceSignature.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spinner = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _spinner = false);
          _retryCounter = 0;
          WebScripts.installAll(_web);
          // A page can load while the keyboard is already open (e.g. an
          // in-page redirect after a form focus). Re-push so the fresh
          // document positions the field immediately.
          _pushKeyboardFraction();
        },
        onWebResourceError: _onError,
        onNavigationRequest: _onNavigate,
      ));

    _configureAndroid();
    _web.loadRequest(Uri.parse(widget.url));
  }

  void _onError(WebResourceError err) {
    if (err.isForMainFrame != true) return;

    final String desc = err.description.toLowerCase();
    final bool isLoop = desc.contains(VeiledStrings.get('e_tmr')) ||
        desc.contains('too many redirects') ||
        err.errorCode == -1007 ||
        err.errorCode == -9;

    if (isLoop &&
        _lastMainFrame != null &&
        _retryCounter < RelayConfig.redirectLoopRetries) {
      _retryCounter++;
      _web.loadRequest(Uri.parse(_lastMainFrame!));
      return;
    }

    // Cover the WebView's native error page IMMEDIATELY so the Android
    // robot never leaks visually (`gray_part_pitfalls.md` §4).
    if (mounted) setState(() => _spinner = true);

    final bool isConnectivity = desc.contains('name_not_resolved') ||
        desc.contains('address_unreachable') ||
        desc.contains('internet_disconnected') ||
        desc.contains('network_changed') ||
        err.errorCode == -105 ||
        err.errorCode == -106 ||
        err.errorCode == -21 ||
        err.errorCode == -2 ||
        err.errorCode == -6;

    if (isConnectivity) {
      // Skip the redundant DNS probe — these codes already mean "down",
      // and the extra lookup keeps the error page on screen for seconds.
      _showOffline();
    } else {
      _guardOffline();
    }
  }

  NavigationDecision _onNavigate(NavigationRequest req) {
    final Uri? uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    const Set<String> inApp = <String>{'http', 'https', 'about', 'data', 'blob'};
    if (inApp.contains(uri.scheme)) {
      if (req.isMainFrame) _lastMainFrame = req.url;
      return NavigationDecision.navigate;
    }
    _openExternally(uri);
    return NavigationDecision.prevent;
  }

  void _configureAndroid() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController controller =
        _web.platform as AndroidWebViewController;

    controller.setMediaPlaybackRequiresUserGesture(false);
    controller.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest r) => r.grant(),
    );
    controller.setOnShowFileSelector(_pickFiles);

    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(controller, true);
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final List<Object?>? picked = await _uploadChannel
          .invokeMethod<List<Object?>>('pick', <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes': params.acceptTypes
            .where((String t) => t.trim().isNotEmpty)
            .toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _openExternally(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _guardOffline() async {
    if (_offlineShown) return;
    if (await _probe.canDialOut()) return;
    _showOffline();
  }

  void _showOffline() {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    final String current = _lastMainFrame ?? widget.url;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflineStage(
          onRetryBuild: (_) => PortalStage(
            url: current,
            keystore: widget.keystore,
            alerts: widget.alerts,
          ),
        ),
      ),
    );
  }

  /// System back walks the WebView history one step. On the first page it
  /// does NOTHING — the portal must never be closed by a back gesture.
  Future<void> _stepBack() async {
    if (await _web.canGoBack()) await _web.goBack();
  }

  /// See the INSET MODEL block at the top of this file. Only the camera
  /// cutout insets the WebView — never the navigation bar, never the
  /// keyboard. Returns the per-orientation cached cutout, applied in the
  /// same frame the orientation changes so the WebView resizes exactly once.
  EdgeInsets _webInsets(Orientation orientation) =>
      _cutoutByOrientation[orientation] ?? EdgeInsets.zero;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dropDebounce?.cancel();
    _connSub?.cancel();
    widget.alerts.onIncomingUrl = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final Orientation orientation = mq.orientation;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _stepBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // Flutter must not resize for the keyboard — the page handles it.
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // The WebView subtree must never observe the keyboard inset or
            // the system-bar padding, or the platform view would resize
            // when either changes. Only the manual notch padding is kept.
            MediaQuery(
              data: mq.copyWith(
                viewInsets: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
              ),
              child: Padding(
                padding: _webInsets(orientation),
                child: WebViewWidget(controller: _web),
              ),
            ),
            if (_spinner)
              const ColoredBox(
                color: Color(0xCC0B0414),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(RelayPalette.gold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
