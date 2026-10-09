import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:ffi/ffi.dart';

// ============================================================
// SEAL GATE — FFI bridge to the native envelope sealer
// ============================================================
// The relay endpoint, the shared secret and the "veil" seal codec live
// in `libskyward_seal.so` (crate `native/skyward_seal`), never as a
// plaintext string in the Dart AOT image. This bridge hands the native
// side the attribution JSON plus a fresh random nonce and gets back the
// opaque envelope the edge relay unpacks; Dart performs the HTTPS POST
// itself (see `verdict_call.dart`). The secret never crosses FFI.
//
// Android-only: every entry point returns null off-device so the dev /
// desktop build skips the gate and routes straight to the native game.
// ============================================================

typedef _PackNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _PackDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _EdgeNative = Pointer<Utf8> Function();
typedef _EdgeDart = Pointer<Utf8> Function();
typedef _JsNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _JsDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _StrNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _StrDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _FetchNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _FetchDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);

class SealGate {
  SealGate._();
  static final SealGate instance = SealGate._();

  static const String _soName = 'libskyward_seal.so';

  bool _tried = false;
  _PackDart? _pack;
  _EdgeDart? _edge;
  _JsDart? _js;
  _StrDart? _str;
  _FreeDart? _free;
  final Random _rng = Random.secure();

  bool get _ready {
    if (_tried) return _pack != null;
    _tried = true;
    if (!Platform.isAndroid) return false;
    try {
      final DynamicLibrary lib = DynamicLibrary.open(_soName);
      _pack = lib.lookupFunction<_PackNative, _PackDart>('skyward_pack');
      _edge = lib.lookupFunction<_EdgeNative, _EdgeDart>('skyward_edge');
      _js = lib.lookupFunction<_JsNative, _JsDart>('skyward_js');
      _str = lib.lookupFunction<_StrNative, _StrDart>('skyward_str');
      _free = lib.lookupFunction<_FreeNative, _FreeDart>('skyward_free');
      // `skyward_fetch` is intentionally NOT looked up here: it is resolved
      // per call inside a worker isolate (FFI handles cannot cross isolate
      // boundaries). Probing it here would also couple the whole gate to it
      // — an older `.so` that predates the transport would then disable
      // seal/str/js too, instead of degrading only `fetch()`.
      return true;
    } catch (_) {
      _pack = null;
      _edge = null;
      _js = null;
      _str = null;
      _free = null;
      return false;
    }
  }

  /// The relay endpoint (de-obfuscated in native code), or null when the
  /// gate is unavailable.
  String? endpoint() {
    if (!_ready) return null;
    final Pointer<Utf8> p = _edge!();
    if (p == nullptr) return null;
    try {
      final String out = p.toDartString();
      return out.isEmpty ? null : out;
    } finally {
      _free!(p);
    }
  }

  /// The de-obfuscated WebView enhancer body for [name] ("safeArea" |
  /// "keyboard" | "autoplay" | "chromeTrim"), reconstructed in native code
  /// so no JS string ships as plaintext. Null off-Android, on an unknown
  /// name, or when the gate is unavailable.
  String? jsBody(String name) {
    if (!_ready) return null;
    final Pointer<Utf8> arg = name.toNativeUtf8();
    try {
      final Pointer<Utf8> r = _js!(arg);
      if (r == nullptr) return null;
      try {
        final String out = r.toDartString();
        return out.isEmpty ? null : out;
      } finally {
        _free!(r);
      }
    } finally {
      malloc.free(arg);
    }
  }

  /// The de-obfuscated wire/game string for the opaque [name]
  /// (see `tool/_gen_str_blobs.dart`), reconstructed in native code so no
  /// plaintext wire literal ships in the Dart image. Null off-Android, on
  /// an unknown name, or when the gate is unavailable — callers fall back
  /// to the code-unit copy in `veiled_strings.dart`.
  String? str(String name) {
    if (!_ready) return null;
    final Pointer<Utf8> arg = name.toNativeUtf8();
    try {
      final Pointer<Utf8> r = _str!(arg);
      if (r == nullptr) return null;
      try {
        final String out = r.toDartString();
        return out.isEmpty ? null : out;
      } finally {
        _free!(r);
      }
    } finally {
      malloc.free(arg);
    }
  }

  /// POST [body] (plain, unencrypted request body) to the Cloudflare-fronted
  /// config endpoint through the native browser-emulating transport (wreq +
  /// Chrome emulation) and return the raw `"{status}\n{body}"` reply. The
  /// URL, method, header names and MIME never leave native code, so none of
  /// them ships as a plaintext literal in the Dart image.
  ///
  /// Returns null off-Android or when the gate is unavailable. A transport
  /// failure comes back as `"0\n"` (status 0) — the caller treats that as a
  /// rejected verdict.
  ///
  /// The native call performs the whole HTTPS round-trip synchronously
  /// (BoringSSL + blocking `block_on`), so it runs on a worker isolate to
  /// keep the boot animation's progress ticker alive on the UI isolate.
  Future<String?> fetch(String body) async {
    if (!_ready) return null;
    try {
      final String result = await Isolate.run<String>(
        () => _nativeFetch(body),
      );
      return result.isEmpty ? null : result;
    } catch (_) {
      // Symbol missing (an older `.so`) or the isolate failed to open the
      // library — degrade to "gate unavailable" rather than throwing.
      return null;
    }
  }

  /// Runs on a worker isolate: FFI handles cannot cross isolate boundaries,
  /// so the library is re-opened here (a cheap, ref-counted `dlopen` of an
  /// already-loaded `.so`) and the two symbols are looked up locally.
  static String _nativeFetch(String body) {
    final DynamicLibrary lib = DynamicLibrary.open(_soName);
    final _FetchDart fetch =
        lib.lookupFunction<_FetchNative, _FetchDart>('skyward_fetch');
    final _FreeDart free =
        lib.lookupFunction<_FreeNative, _FreeDart>('skyward_free');
    final Pointer<Utf8> arg = body.toNativeUtf8();
    try {
      final Pointer<Utf8> r = fetch(arg);
      if (r == nullptr) return '';
      try {
        return r.toDartString();
      } finally {
        free(r);
      }
    } finally {
      malloc.free(arg);
    }
  }

  /// Seal [bodyJson] into the relay envelope with a fresh 16-byte nonce.
  /// Returns null when the gate is unavailable or sealing failed.
  String? seal(String bodyJson) {
    if (!_ready) return null;
    final String nonceHex = _nonceHex();
    final Pointer<Utf8> body = bodyJson.toNativeUtf8();
    final Pointer<Utf8> nonce = nonceHex.toNativeUtf8();
    try {
      final Pointer<Utf8> r = _pack!(body, nonce);
      if (r == nullptr) return null;
      try {
        final String out = r.toDartString();
        return out.isEmpty ? null : out;
      } finally {
        _free!(r);
      }
    } finally {
      malloc.free(body);
      malloc.free(nonce);
    }
  }

  String _nonceHex() {
    const String hex = '0123456789abcdef';
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < 16; i++) {
      final int b = _rng.nextInt(256);
      sb.write(hex[b >> 4]);
      sb.write(hex[b & 0x0F]);
    }
    return sb.toString();
  }
}
