import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/relay_config.dart';

// ============================================================
// PULSE PROBE — connectivity + DNS reachability
// ============================================================
// `connectivity_plus` alone is unreliable — a captive portal, a
// half-brought-up VPN interface, or a mobile-data cell without a route
// all report "connected". We layer a real DNS lookup on top so the
// pipeline never commits to online routing without a working DNS path.
//
// [FORGE] The DNS probe rotates between two sibling hosts on each call
// (index modulo 2). The candidate list is rotated per project so no two
// apps share the same reachability fingerprint. Never probe a partner
// or config-endpoint host — that would (a) log traffic even before the
// verdict and (b) create a probe → own-host correlation in traffic
// sniffs.
// ============================================================

// [FORGE] Rotated for this project. Two well-known, cheap-DNS hosts
// unrelated to the partner and the config endpoint. Siblings use
// cloudflare/apple — this project deliberately does not.
const List<String> _probeHosts = <String>[
  'wikipedia.org',
  'microsoft.com',
];

/// Which adapters count as "up". VPN + Bluetooth + Ethernet are
/// included — dropping any of them created false offline verdicts on
/// real users (VPN especially — see `gray_part_pitfalls.md` §3).
const Set<ConnectivityResult> _liveAdapters = <ConnectivityResult>{
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn,
  ConnectivityResult.bluetooth,
  ConnectivityResult.other,
};

class PulseProbe {
  PulseProbe({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  int _rotor = 0;

  /// True if AT LEAST one adapter reports as live. Does NOT run a DNS
  /// probe — use [canDialOut] for that.
  ///
  /// This is the cheap check (a single platform-channel round trip), so
  /// it is also what the pre-boot offline gate in `main()` uses: it can
  /// decide "airplane mode" before the first frame without stalling
  /// startup on a DNS timeout.
  Future<bool> hasAdapter() async {
    try {
      final List<ConnectivityResult> states =
          await _connectivity.checkConnectivity();
      return states.any(_liveAdapters.contains);
    } catch (_) {
      return false;
    }
  }

  /// True if we can resolve at least one probe host within the
  /// configured timeout. Rotates through the host list so a temporarily
  /// unresolvable host does not force a retry.
  Future<bool> canDialOut() async {
    if (!await hasAdapter()) return false;
    final Duration timeout =
        Duration(seconds: RelayConfig.reachProbeTimeoutSeconds);
    for (int i = 0; i < _probeHosts.length; i++) {
      final String host = _probeHosts[(_rotor + i) % _probeHosts.length];
      try {
        final List<InternetAddress> answer =
            await InternetAddress.lookup(host).timeout(timeout);
        if (answer.any((InternetAddress a) => a.rawAddress.isNotEmpty)) {
          _rotor = (_rotor + 1) % _probeHosts.length;
          return true;
        }
      } catch (_) {
        // Try the next host before declaring offline.
      }
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get statusStream =>
      _connectivity.onConnectivityChanged;
}
