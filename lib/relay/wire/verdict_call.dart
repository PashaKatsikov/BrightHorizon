import 'dart:convert';

import '../config/relay_config.dart';
import '../core/landing.dart';
import 'beacon_keystore.dart';
import 'relay_agent.dart';
import 'seal_gate.dart';

// ============================================================
// VERDICT CALL — seal the body in native code, POST, cache the answer
// ============================================================
// The backend is the single source of truth for the routing decision.
// The assembled attribution body is sealed by `libskyward_seal.so` into
// an opaque envelope and POSTed to the edge relay, which unpacks it and
// forwards the clean JSON to the partner config; the relay's answer is
// returned verbatim. The relay endpoint and the shared secret live only
// inside the native library — never as a plaintext/obfuscated string in
// the Dart image — so this file holds no endpoint literal at all.
//
// On an approved response we cache both the URL AND its expiry so
// returning launches can skip the network call while the URL is still
// fresh. On any failure — gate unavailable, HTTP error, timeout,
// malformed JSON — we return a rejected verdict; the coordinator turns
// that into a game landing (or an offline landing if the network is
// down).
// ============================================================

class VerdictCall {
  VerdictCall(this._keystore);

  final BeaconKeystore _keystore;

  Future<Verdict> ask(Map<String, dynamic> body) async {
    // Seal in native code. The envelope and the destination both come
    // from the gate; if it is unavailable (non-Android / dev build) we
    // reject, which routes the install to the offline-capable game.
    final SealGate gate = SealGate.instance;
    final String? endpoint = gate.endpoint();
    final String? envelope = gate.seal(jsonEncode(body));
    if (endpoint == null || envelope == null) {
      return Verdict.rejected('gate_unavailable');
    }

    try {
      final dynamic response = await relayAgent
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: envelope,
          )
          .timeout(Duration(seconds: RelayConfig.verdictTimeoutSeconds));

      if (response.statusCode != 200) {
        return Verdict.rejected('http_${response.statusCode}');
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) return Verdict.rejected('malformed');
      final Verdict verdict = Verdict.fromJson(
        Map<String, dynamic>.from(decoded),
      );

      if (verdict.hasDestination) {
        await _keystore.cacheDestination(verdict.url!, verdict.expiresAt);
      }
      return verdict;
    } catch (e) {
      return Verdict.rejected('network:$e');
    }
  }
}
