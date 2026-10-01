import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'marks.dart';

// ============================================================
// SLOT GATE — FFI bridge to the native slot math
// ============================================================
// All of the game's arithmetic — rolling a window, pricing the paylines,
// scoring scatters, picking a win tier — lives in `libskyward_seal.so`
// (crate `native/skyward_seal`, module `slot`), never in the Dart AOT
// image. This bridge hands the native side a stake (plus an optional
// cheat preset and RNG seed) and parses the outcome JSON back into the
// value types the cabinet renders.
//
// Android-only: every entry point returns null off-device, so the dev /
// desktop / `flutter test` build transparently falls back to the Dart
// mirror in `engine.dart`.
// ============================================================

typedef _SpinNative = Pointer<Utf8> Function(Int64, Int32, Uint64);
typedef _SpinDart = Pointer<Utf8> Function(int, int, int);
typedef _EvalNative = Pointer<Utf8> Function(Pointer<Utf8>, Int64);
typedef _EvalDart = Pointer<Utf8> Function(Pointer<Utf8>, int);
typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);

/// Native outcome, decoded into the shapes `engine.dart` wraps. Grid is
/// reel-major (`grid[reel][row]`), hits are `(reel, row)` pairs.
class NativeSpin {
  const NativeSpin({
    required this.grid,
    required this.payout,
    required this.scatterCount,
    required this.freeSpins,
    required this.tierIndex,
    required this.hits,
  });

  final List<List<Mark>> grid;
  final int payout;
  final int scatterCount;
  final int freeSpins;
  final int tierIndex;
  final List<(int, int)> hits;
}

class SlotGate {
  SlotGate._();
  static final SlotGate instance = SlotGate._();

  static const String _soName = 'libskyward_seal.so';

  bool _tried = false;
  _SpinDart? _spin;
  _EvalDart? _eval;
  _FreeDart? _free;

  bool get _ready {
    if (_tried) return _spin != null;
    _tried = true;
    if (!Platform.isAndroid) return false;
    try {
      final DynamicLibrary lib = DynamicLibrary.open(_soName);
      _spin = lib.lookupFunction<_SpinNative, _SpinDart>('skyward_slot_spin');
      _eval = lib.lookupFunction<_EvalNative, _EvalDart>('skyward_slot_eval');
      _free = lib.lookupFunction<_FreeNative, _FreeDart>('skyward_free');
      return true;
    } catch (_) {
      _spin = null;
      _eval = null;
      _free = null;
      return false;
    }
  }

  /// Whether native math is live. Used by callers to decide if a Dart
  /// fallback is needed.
  bool get available => _ready;

  /// Roll and price a spin natively. [cheat] is the native cheat code
  /// (0..5) or -1 for a random roll; [seed] seeds the native RNG. Null
  /// when the gate is unavailable.
  NativeSpin? spin({required int stake, required int cheat, required int seed}) {
    if (!_ready) return null;
    final Pointer<Utf8> p = _spin!(stake, cheat, seed & 0x7FFFFFFFFFFFFFFF);
    return _consume(p);
  }

  /// Price a caller-supplied window natively. [grid] is reel-major. Null
  /// when the gate is unavailable or the grid is rejected.
  NativeSpin? evaluate(List<List<Mark>> grid, int stake) {
    if (!_ready) return null;
    final String csv = <String>[
      for (final reel in grid)
        for (final mark in reel) mark.index.toString(),
    ].join(',');
    final Pointer<Utf8> arg = csv.toNativeUtf8();
    try {
      return _consume(_eval!(arg, stake));
    } finally {
      malloc.free(arg);
    }
  }

  NativeSpin? _consume(Pointer<Utf8> p) {
    if (p == nullptr) return null;
    try {
      final String out = p.toDartString();
      if (out.isEmpty) return null;
      return _decode(out);
    } catch (_) {
      return null;
    } finally {
      _free!(p);
    }
  }

  NativeSpin? _decode(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final rawGrid = map['grid'] as List<dynamic>;
    final grid = <List<Mark>>[
      for (final reel in rawGrid)
        <Mark>[
          for (final cell in reel as List<dynamic>) Mark.values[cell as int],
        ],
    ];
    final hits = <(int, int)>[
      for (final pair in map['hits'] as List<dynamic>)
        ((pair as List<dynamic>)[0] as int, pair[1] as int),
    ];
    return NativeSpin(
      grid: grid,
      payout: (map['payout'] as num).toInt(),
      scatterCount: (map['scatter'] as num).toInt(),
      freeSpins: (map['free'] as num).toInt(),
      tierIndex: (map['tier'] as num).toInt(),
      hits: hits,
    );
  }
}
