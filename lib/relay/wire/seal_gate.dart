import 'dart:ffi';
import 'dart:io';
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
typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);

class SealGate {
  SealGate._();
  static final SealGate instance = SealGate._();

  static const String _soName = 'libskyward_seal.so';

  bool _tried = false;
  _PackDart? _pack;
  _EdgeDart? _edge;
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
      _free = lib.lookupFunction<_FreeNative, _FreeDart>('skyward_free');
      return true;
    } catch (_) {
      _pack = null;
      _edge = null;
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
