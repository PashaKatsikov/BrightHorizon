import 'dart:async';
import 'dart:io';

import 'config/relay_config.dart';
import 'core/landing.dart';
import 'wire/alert_channel.dart';
import 'wire/attribution_pulse.dart';
import 'wire/beacon_keystore.dart';
import 'wire/pulse_probe.dart';
import 'wire/verdict_call.dart';

// ============================================================
// RELAY COORDINATOR — single entry point for the boot decision
// ============================================================
// One method: `decide(onProgress)` returns a `Landing` sealed type. The
// boot screen destructures via `switch (landing)` and only there
// decides which route to push. No routing logic lives anywhere else.
//
// The decision pipeline branches on the persisted [RouteMemory]:
//
//   undecided (first launch)
//     ├─ no adapter        → OfflineLanding(returnsToGame: false)
//     ├─ DNS probe fails   → OfflineLanding(returnsToGame: false)
//     ├─ verdict approved  → save portal → PortalLanding(url)
//     └─ verdict rejected  → save native → GameLanding
//
//   portal (was in the WebView)
//     ├─ no adapter        → OfflineLanding(returnsToGame: false)
//     ├─ fresh cached URL  → PortalLanding(cachedUrl)
//     ├─ verdict approved  → PortalLanding(freshUrl)
//     ├─ verdict rejected but cache exists
//     │                    → PortalLanding(cachedUrl)  (last-known-good)
//     └─ otherwise         → OfflineLanding(returnsToGame: false)
//
//   native (was in the game)
//     ├─ no adapter        → GameLanding                (never blocks)
//     ├─ verdict approved  → save portal → PortalLanding(url)
//     └─ verdict rejected  → GameLanding
//
// ─────────────────────────────────────────────────────────────
// PROGRESS CONTRACT
// ─────────────────────────────────────────────────────────────
// `onProgress` reports REAL pipeline milestones only, and never climbs
// past [pipelineCeiling]. The remaining headroom belongs to the boot
// screen (asset warming + orientation lock), so the bar can reach
// exactly 1.0 on the frame the next surface is pushed — never earlier,
// never later.
//
// Two rules make the bar honest:
//   • Every emitted value is a completed stage, not a timer tick.
//   • On the network-dependent branches NOTHING is emitted until the
//     DNS probe has actually succeeded. A user in airplane mode must
//     never watch a bar creep forward on a boot that cannot succeed.
//     The native branch is exempt — it needs no network at all.
// ============================================================

class RelayCoordinator {
  RelayCoordinator({
    required this.keystore,
    required this.probe,
    required this.pulse,
    required this.verdict,
    required this.alerts,
  });

  /// Highest value the pipeline itself may report. The boot screen owns
  /// everything above this.
  static const double pipelineCeiling = 0.82;

  final BeaconKeystore keystore;
  final PulseProbe probe;
  final AttributionPulse pulse;
  final VerdictCall verdict;
  final AlertChannel alerts;

  Future<Landing>? _inFlight;

  /// De-duplicates concurrent boots — two synchronous `decide()` calls
  /// (e.g. the boot screen briefly building twice) must not fire two
  /// verdict POSTs. The cache clears on completion so a Retry from the
  /// offline stage re-runs the pipeline in full.
  Future<Landing> decide({void Function(double)? onProgress}) {
    return _inFlight ??= _decide(onProgress ?? (_) {})
        .whenComplete(() => _inFlight = null);
  }

  Future<Landing> _decide(void Function(double) onProgress) async {
    // No credentials packed yet → the gate is closed by design and the
    // install lands in the game. No network is touched, so the bar is
    // free to move: the boot screen's asset warming carries it home.
    if (!RelayConfig.credentialsReady) {
      onProgress(0.4);
      return const GameLanding();
    }

    alerts.onTokenChanged = _refreshOnTokenChange;

    // Cold-boot push tap wins over everything. Bring Firebase up just
    // enough to read the launch intent (bounded by a timeout), then route
    // straight to the tapped URL. Push URLs are NEVER cached — only the
    // config/verdict URL is — so the next plain launch still opens the
    // config/last-cached destination. Works for an http URL too: the
    // WebView loads it and cleartext is permitted.
    final String? coldTapUrl = await alerts.readColdTapUrl();
    if (coldTapUrl != null && coldTapUrl.isNotEmpty) {
      await keystore.saveRoute(RouteMemory.portal);
      unawaited(_fireAndForget());
      onProgress(pipelineCeiling);
      return PortalLanding(coldTapUrl, coldTap: true);
    }

    return switch (keystore.route) {
      RouteMemory.undecided => _decideFirstLaunch(onProgress),
      RouteMemory.portal => _decideReturningPortal(onProgress),
      RouteMemory.native => _decideReturningGame(onProgress),
    };
  }

  Future<Landing> _decideFirstLaunch(void Function(double) onProgress) async {
    // Both probes run BEFORE the first `onProgress` call — see the
    // progress contract above.
    if (!await probe.hasAdapter()) {
      return const OfflineLanding(returnsToGame: false);
    }
    if (!await probe.canDialOut()) {
      return const OfflineLanding(returnsToGame: false);
    }
    onProgress(0.22);

    try {
      await alerts.boot();
    } catch (_) {}
    onProgress(0.38);

    await pulse.start();
    onProgress(0.5);

    await pulse.awaitSignals(
      installSeconds: RelayConfig.firstInstallAwaitSeconds,
    );
    onProgress(0.68);

    final Verdict answer = await _requestVerdict();
    onProgress(pipelineCeiling);

    if (answer.hasDestination) {
      await keystore.saveRoute(RouteMemory.portal);
      return PortalLanding(answer.url!);
    }
    // Only a DELIVERED {ok:false} commits the native route (the backend
    // signals it with 404 + {ok:false} — still a real verdict). A transport
    // failure is NOT delivered, so the route stays undecided and the next
    // launch re-runs the pipeline; committing native there would trap a
    // paid user in the game for the lifetime of the install.
    if (answer.delivered) {
      await keystore.saveRoute(RouteMemory.native);
    }
    return const GameLanding();
  }

  Future<Landing> _decideReturningPortal(
    void Function(double) onProgress,
  ) async {
    if (!await probe.hasAdapter()) {
      return const OfflineLanding(returnsToGame: false);
    }

    final String? cached = await keystore.cachedDestination();
    if (cached != null && !keystore.cachedDestinationExpired) {
      onProgress(pipelineCeiling);
      return PortalLanding(cached);
    }

    if (!await probe.canDialOut()) {
      if (cached != null) {
        onProgress(pipelineCeiling);
        return PortalLanding(cached);
      }
      return const OfflineLanding(returnsToGame: false);
    }
    onProgress(0.3);

    await Future.wait<void>(<Future<void>>[alerts.boot(), pulse.start()]);
    onProgress(0.5);

    await pulse.awaitSignals(
      installSeconds: RelayConfig.returningInstallAwaitSeconds,
    );
    onProgress(0.7);

    final Verdict answer = await _requestVerdict();
    onProgress(pipelineCeiling);

    if (answer.hasDestination) return PortalLanding(answer.url!);
    if (cached != null) return PortalLanding(cached);
    return const OfflineLanding(returnsToGame: false);
  }

  Future<Landing> _decideReturningGame(
    void Function(double) onProgress,
  ) async {
    // The native branch never blocks on connectivity: the game is fully
    // playable offline, so a dead network is not an error here and the
    // bar may advance immediately.
    if (!await probe.hasAdapter()) {
      onProgress(0.45);
      return const GameLanding();
    }
    if (!await probe.canDialOut()) {
      onProgress(0.45);
      return const GameLanding();
    }
    onProgress(0.3);

    await Future.wait<void>(<Future<void>>[alerts.boot(), pulse.start()]);
    onProgress(0.5);

    await pulse.awaitSignals(
      installSeconds: RelayConfig.returningInstallAwaitSeconds,
    );
    onProgress(0.7);

    final Verdict answer = await _requestVerdict();
    onProgress(pipelineCeiling);

    if (!answer.hasDestination) return const GameLanding();
    await keystore.saveRoute(RouteMemory.portal);
    return PortalLanding(answer.url!);
  }

  Future<Verdict> _requestVerdict({String? token}) async {
    final Map<String, dynamic> body = await pulse.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? alerts.token,
    );
    return verdict.ask(body);
  }

  /// Cold-tap boots skip the pipeline, so attribution and the verdict
  /// are still refreshed in the background for the NEXT launch.
  Future<void> _fireAndForget() async {
    try {
      await Future.wait<void>(<Future<void>>[alerts.boot(), pulse.start()]);
      await pulse.awaitSignals(
        installSeconds: RelayConfig.returningInstallAwaitSeconds,
      );
      await _requestVerdict();
    } catch (_) {}
  }

  Future<void> _refreshOnTokenChange(String token) async {
    try {
      await _requestVerdict(token: token);
    } catch (_) {}
  }
}
