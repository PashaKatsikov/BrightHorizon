import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================
// CHROME GUARD — one immersive policy for the whole app
// ============================================================
// Both the status bar ("top HUD") and the navigation bar stay hidden on
// EVERY surface: boot screen, push invite, offline screen, WebView, and
// the native game.
//
// `SystemUiMode.immersiveSticky` is the mode that matches the intent:
//   • the bars are hidden by default;
//   • a swipe from an edge reveals them as a TRANSIENT overlay drawn ON
//     TOP of the content — the app is never resized and no extra safe
//     area appears;
//   • the bars hide themselves again after a couple of seconds.
//
// The mode is process-wide, but it is not permanent: returning from
// another activity (the file chooser, an external `tel:` / `intent://`
// hand-off, the system push dialog) or a plugin that touches the window
// can restore the bars. Re-asserting on every `resumed` transition is
// what keeps the policy sticky in practice, which is why this widget
// wraps the whole `MaterialApp` instead of living in one screen.
//
// Note on the camera cutout: hiding the bars does NOT give up the notch
// inset. `NormalTheme` sets `windowLayoutInDisplayCutoutMode=shortEdges`
// (see `res/values/styles.xml`), so Android keeps reporting the cutout
// through `MediaQuery.viewPadding` and the WebView can still carve a
// safe zone around the camera — see `portal_stage.dart`.
// ============================================================

/// Applies the immersive policy. Safe to call repeatedly.
Future<void> applyImmersiveChrome() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    // Stops Android from painting its own scrim behind a transient bar,
    // which would otherwise read as a grey band over the artwork.
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  ));
}

class ChromeGuard extends StatefulWidget {
  const ChromeGuard({super.key, required this.child});

  final Widget child;

  @override
  State<ChromeGuard> createState() => _ChromeGuardState();
}

class _ChromeGuardState extends State<ChromeGuard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    applyImmersiveChrome();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) applyImmersiveChrome();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
