import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/chrome_guard.dart';
import 'boot/boot_screen.dart';
import 'relay/config/relay_config.dart';
import 'relay/core/landing.dart';
import 'relay/relay_coordinator.dart';
import 'relay/stage/offline_stage.dart';
import 'relay/wire/alert_channel.dart';
import 'relay/wire/attribution_pulse.dart';
import 'relay/wire/beacon_keystore.dart';
import 'relay/wire/device_signature.dart';
import 'relay/wire/pulse_probe.dart';
import 'relay/wire/verdict_call.dart';
import 'src/profile.dart';
import 'src/widgets.dart';

// ============================================================
// BOOTSTRAP
// ============================================================
// Everything here is either cheap or wrapped in try/catch: a failure in
// Firebase, App Check or the device probe must degrade to "boot anyway",
// never to a black screen.
//
// Order matters:
//   1. Binding, then the immersive policy — set before the first frame
//      so the bars never flash into view.
//   2. Firebase + App Check, so `AlertChannel.boot()` later finds an
//      initialised app. Optional: no `google-services.json` simply
//      leaves push dormant.
//   3. `DeviceSignature.prime()` — the forged UA must be resolved before
//      either the HTTP client or the WebView asks for it, otherwise the
//      two would disagree for the first request.
//   4. `BeaconKeystore.prime()` — the route memory is needed by the
//      offline pre-gate below.
//   5. The white game's profile, unchanged.
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await applyImmersiveChrome();

  // Both orientations while the route is undecided: the loading, invite
  // and offline plates all ship portrait and landscape art, and the
  // WebView needs both. `lockLandscape()` narrows this down if and when
  // the arcade opens.
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {
    // Credentials not packed yet, or Play Integrity unavailable on this
    // device. Push and App Check stay dormant; the boot continues.
  }

  await DeviceSignature.prime();

  final BeaconKeystore keystore = BeaconKeystore();
  await keystore.prime();

  final PulseProbe probe = PulseProbe();
  final AlertChannel alerts = AlertChannel(keystore);
  final RelayCoordinator coordinator = RelayCoordinator(
    keystore: keystore,
    probe: probe,
    pulse: AttributionPulse(),
    verdict: VerdictCall(keystore),
    alerts: alerts,
  );

  final Profile profile = Profile();
  await profile.load();

  runApp(
    ProfileScope(
      profile: profile,
      child: HorizonApp(
        keystore: keystore,
        alerts: alerts,
        coordinator: coordinator,
        home: await _firstSurface(
          keystore: keystore,
          probe: probe,
          alerts: alerts,
          coordinator: coordinator,
        ),
      ),
    ),
  );
}

/// Picks the surface the very first frame paints.
///
/// Normally that is the boot screen. The exception exists because a
/// progress bar that advances on a boot which cannot succeed is actively
/// misleading: when the install still has to reach the network and there
/// is no live adapter at all, the no-connection screen is shown
/// IMMEDIATELY — the loading art never appears and the bar never moves.
///
/// Three details make this safe to do before `runApp`:
///   • [PulseProbe.hasAdapter] is a single platform-channel query. It
///     does not perform a DNS lookup, so it cannot stall startup the way
///     [PulseProbe.canDialOut] can.
///   • A committed native route skips the check entirely. That install
///     has already been sent to the arcade, which is fully playable
///     offline, so demanding connectivity there would be a regression.
///   • An adapter that is up but cannot resolve anything still lands on
///     the boot screen. The coordinator withholds every progress
///     emission until DNS succeeds, so the bar sits at the local
///     warm-up mark and then the offline stage takes over — it never
///     creeps toward 100 %.
Future<Widget> _firstSurface({
  required BeaconKeystore keystore,
  required PulseProbe probe,
  required AlertChannel alerts,
  required RelayCoordinator coordinator,
}) async {
  Widget boot() => BootScreen(
        coordinator: coordinator,
        keystore: keystore,
        alerts: alerts,
      );

  // No credentials packed yet → the gate is closed and this install is
  // a plain offline-capable game. Nothing to pre-check.
  if (!RelayConfig.credentialsReady) return boot();
  if (keystore.route == RouteMemory.native) return boot();

  bool adapterUp = true;
  try {
    adapterUp = await probe.hasAdapter();
  } catch (_) {
    // Probe unavailable — assume online and let the pipeline decide.
  }
  if (adapterUp) return boot();

  return OfflineStage(onRetryBuild: (_) => boot());
}

class HorizonApp extends StatelessWidget {
  const HorizonApp({
    super.key,
    required this.keystore,
    required this.alerts,
    required this.coordinator,
    required this.home,
  });

  final BeaconKeystore keystore;
  final AlertChannel alerts;
  final RelayCoordinator coordinator;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return ChromeGuard(
      child: MaterialApp(
        title: 'Bright Horizon',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: ink,
          colorScheme: const ColorScheme.dark(
            primary: gold,
            surface: ink,
          ),
          fontFamily: 'Roboto',
          splashFactory: InkSplash.splashFactory,
        ),
        home: home,
      ),
    );
  }
}
