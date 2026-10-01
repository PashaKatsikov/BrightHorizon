import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../relay/config/relay_assets.dart';
import '../relay/core/landing.dart';
import '../relay/relay_coordinator.dart';
import '../relay/stage/offline_stage.dart';
import '../relay/stage/permission_stage.dart';
import '../relay/stage/portal_stage.dart';
import '../relay/wire/alert_channel.dart';
import '../relay/wire/beacon_keystore.dart';
import '../src/frames.dart';
import '../src/screens/menu.dart';
import '../src/widgets.dart';

// ============================================================
// BOOT SCREEN — the ONLY startup surface
// ============================================================
// Shows the loading art plus a progress bar while
// [RelayCoordinator.decide] resolves, then destructures the sealed
// `Landing` and pushes exactly one route. No routing logic lives here
// beyond `switch (outcome)`.
//
// ─────────────────────────────────────────────────────────────
// PROGRESS MODEL
// ─────────────────────────────────────────────────────────────
// The bar is driven by two cooperating pieces:
//
//   • CHECKPOINTS. `_target` only ever moves when a real boot stage
//     completes: local art decode, DNS reachability, Firebase bring-up,
//     attribution signals, the verdict reply, game art decode, the
//     orientation lock. Nothing is a timer. The coordinator owns
//     [RelayCoordinator.pipelineCeiling]; everything above it is the
//     local work this screen performs itself.
//
//   • A TICKER that eases `_shown` toward `_target` every frame, so a
//     stage that completes in one jump still renders as a smooth glide
//     instead of a snap. Arrival is gentle, and the rate floor keeps a
//     long wait from looking frozen.
//
// The bar therefore hits exactly 1.0 on the frame the next surface is
// pushed — never earlier (no fake 100 % followed by a stall) and never
// later (no visible gap). Both landings honour this: the game path fills
// the top slice with sprite-sheet decoding plus the landscape lock, the
// portal path settles the remainder just before the WebView mounts.
//
// The offline landing is the deliberate exception: it must NOT fill the
// bar. A user with no connection should never watch a progress bar
// complete on a boot that cannot succeed, so the stage is pushed from
// wherever the bar happens to be.
// ============================================================

class BootScreen extends StatefulWidget {
  const BootScreen({
    super.key,
    required this.coordinator,
    required this.keystore,
    required this.alerts,
  });

  final RelayCoordinator coordinator;
  final BeaconKeystore keystore;
  final AlertChannel alerts;

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen>
    with SingleTickerProviderStateMixin {
  /// Local asset warm-up, before any network work. Safe to advance even
  /// with no connectivity — it is genuinely local progress.
  static const double _localWarmDone = 0.12;

  /// Sprite-sheet decode for the game path.
  static const double _gameArtDone = 0.94;

  /// Orientation settled; only the push is left.
  static const double _orientationDone = 0.985;

  double _target = 0;
  double _shown = 0;
  bool _landed = false;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ── Progress plumbing ───────────────────────────────────

  void _onTick(Duration elapsed) {
    final double dt =
        ((elapsed - _lastTick).inMicroseconds / 1000000).clamp(0.0, 0.05);
    _lastTick = elapsed;
    if (dt <= 0) return;

    final double delta = _target - _shown;
    if (delta <= 0.0005) {
      if (_shown != _target) setState(() => _shown = _target);
      return;
    }
    // Fast when far from the checkpoint, gentle on arrival, and never
    // slower than a visible crawl.
    final double speed = (delta * 5.5).clamp(0.12, 1.6);
    setState(() => _shown = math.min(_target, _shown + speed * dt));
  }

  /// Checkpoints are monotonic — a later stage can never rewind the bar.
  void _liftTo(double value) {
    if (!mounted || value <= _target) return;
    _target = value;
  }

  /// Lifts to [value] and waits until the bar has visually caught up.
  Future<void> _settleTo(double value) async {
    _liftTo(value);
    while (mounted && _shown < value - 0.002) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  /// Precaches [assets], attributing the span [from]…[to] to the decode.
  Future<void> _warm(
    List<String> assets, {
    required double from,
    required double to,
  }) async {
    _liftTo(from);
    for (int i = 0; i < assets.length; i++) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(assets[i]), context);
      } catch (_) {
        // A missing plate must never block startup.
      }
      _liftTo(from + (to - from) * ((i + 1) / assets.length));
    }
  }

  // ── Boot pipeline ───────────────────────────────────────

  Future<void> _drive() async {
    // Purely local, so it runs before the connectivity verdict.
    await _warm(RelayAssets.warmup, from: 0, to: _localWarmDone);

    final Landing outcome =
        await widget.coordinator.decide(onProgress: _liftTo);
    if (!mounted || _landed) return;
    _landed = true;

    switch (outcome) {
      case GameLanding():
        await _enterGame();
      case PortalLanding(url: final String url):
        await _enterPortal(url);
      case OfflineLanding():
        // No fill — see the progress model note above.
        _replaceWith(_buildOffline());
    }
  }

  Future<void> _enterGame() async {
    // The arcade is landscape-only; the plates above are orientation
    // aware, so the bar keeps rendering correctly while the device turns.
    await _warm(
      const <String>[bgHorizon, logoAsset, bgFruit, bgViolet],
      from: RelayCoordinator.pipelineCeiling,
      to: _gameArtDone,
    );
    await lockLandscape();
    if (!mounted) return;
    await _settleTo(_orientationDone);
    await _settleTo(1);
    if (!mounted) return;
    _replaceWith(const MenuPage());
  }

  Future<void> _enterPortal(String url) async {
    await _settleTo(1);
    if (!mounted) return;
    _replaceWith(
      widget.keystore.shouldInvitePermission
          ? PermissionStage(
              keystore: widget.keystore,
              alerts: widget.alerts,
              destinationUrl: url,
            )
          : PortalStage(
              url: url,
              keystore: widget.keystore,
              alerts: widget.alerts,
            ),
    );
  }

  Widget _buildOffline() => OfflineStage(
        onRetryBuild: (_) => BootScreen(
          coordinator: widget.coordinator,
          keystore: widget.keystore,
          alerts: widget.alerts,
        ),
      );

  void _replaceWith(Widget next) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => next),
    );
  }

  // ── UI ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    return Scaffold(
      backgroundColor: ink,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            portrait
                ? RelayAssets.loadingPortrait
                : RelayAssets.loadingLandscape,
            fit: BoxFit.cover,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            // Horizontal SafeArea off: in landscape the side notch inset
            // would push the centred bar sideways. Bottom stays so the bar
            // clears the gesture area.
            child: SafeArea(
              left: false,
              right: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 48, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _PercentReadout(value: _shown),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: SizedBox(
                        height: 10,
                        child: LinearProgressIndicator(
                          value: _shown.clamp(0.0, 1.0),
                          backgroundColor: const Color(0x55FFFFFF),
                          color: violet,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The numeric read-out above the bar.
///
/// The loading plates are gold-on-violet at the bottom edge, so flat text
/// would vanish into the artwork. The digits are drawn twice: a dark
/// stroked pass underneath and the cream fill on top. That outline keeps
/// them legible over coins, fruit and the violet floor alike, without
/// putting a chip or panel on top of art that must stay unchanged.
class _PercentReadout extends StatelessWidget {
  const _PercentReadout({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final String text = '${(value.clamp(0.0, 1.0) * 100).round()}%';
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            height: 1.0,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.4
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xE60B0414),
          ),
        ),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            height: 1.0,
            color: cream,
          ),
        ),
      ],
    );
  }
}
