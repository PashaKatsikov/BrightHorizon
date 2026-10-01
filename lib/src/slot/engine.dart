import 'dart:math' as math;

import 'cheat.dart';
import 'marks.dart';
import 'slot_gate.dart';

const lineCount = 20;

const stakes = <int>[20, 40, 100, 200, 500];

/// Row index per reel, 0 at the top.
const paylines = <List<int>>[
  [1, 1, 1, 1, 1],
  [0, 0, 0, 0, 0],
  [2, 2, 2, 2, 2],
  [0, 1, 2, 1, 0],
  [2, 1, 0, 1, 2],
  [0, 0, 1, 0, 0],
  [2, 2, 1, 2, 2],
  [1, 0, 0, 0, 1],
  [1, 2, 2, 2, 1],
  [0, 1, 1, 1, 0],
  [2, 1, 1, 1, 2],
  [1, 0, 1, 2, 1],
  [1, 2, 1, 0, 1],
  [0, 1, 0, 1, 0],
  [2, 1, 2, 1, 2],
  [1, 1, 0, 1, 1],
  [1, 1, 2, 1, 1],
  [0, 2, 0, 2, 0],
  [2, 0, 2, 0, 2],
  [0, 2, 2, 2, 0],
];

enum Tier { none, big, mega, jackpot }

Tier tierFor(int payout, int stake) {
  if (stake <= 0 || payout <= 0) return Tier.none;
  final times = payout / stake;
  if (times >= 40) return Tier.jackpot;
  if (times >= 25) return Tier.mega;
  if (times >= 10) return Tier.big;
  return Tier.none;
}

class Cell {
  const Cell(this.reel, this.row);

  final int reel;
  final int row;

  @override
  bool operator ==(Object other) => other is Cell && other.reel == reel && other.row == row;

  @override
  int get hashCode => Object.hash(reel, row);
}

class SpinOutcome {
  const SpinOutcome({
    required this.grid,
    required this.payout,
    required this.scatterCount,
    required this.freeSpins,
    required this.tier,
    required this.hits,
  });

  /// Reel-major: `grid[reel][row]`, row 0 at the top.
  final List<List<Mark>> grid;
  final int payout;
  final int scatterCount;
  final int freeSpins;
  final Tier tier;
  final Set<Cell> hits;
}

class SlotEngine {
  SlotEngine({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  /// Rolls a window and prices it. The arithmetic runs in Rust whenever
  /// `libskyward_seal.so` is present (every shipped Android build); the
  /// Dart body below is the off-device fallback for dev / `flutter test`.
  SpinOutcome spin({required int stake, Cheat? cheat}) {
    final native = SlotGate.instance.spin(
      stake: stake,
      cheat: cheat?.index ?? -1,
      seed: _seed(),
    );
    if (native != null) return _fromNative(native);

    final grid = cheat == null ? _roll() : cheatReelGrid(cheat);
    return _evaluateDart(grid, stake);
  }

  int _seed() {
    final hi = _random.nextInt(0x100000000);
    final lo = _random.nextInt(0x100000000);
    return (hi << 32) ^ lo;
  }

  List<List<Mark>> _roll() {
    return List.generate(5, (reel) {
      final strip = reelStrips[reel];
      final start = _random.nextInt(strip.length);
      return List.generate(3, (row) => strip[(start + row) % strip.length]);
    });
  }
}

/// Turns a native outcome into the value type the cabinet renders.
SpinOutcome _fromNative(NativeSpin n) {
  return SpinOutcome(
    grid: n.grid,
    payout: n.payout,
    scatterCount: n.scatterCount,
    freeSpins: n.freeSpins,
    tier: Tier.values[n.tierIndex],
    hits: <Cell>{for (final (reel, row) in n.hits) Cell(reel, row)},
  );
}

/// Prices [grid] at [stake]. Delegates to the native evaluator when it is
/// available and falls back to the Dart mirror otherwise.
SpinOutcome evaluate(List<List<Mark>> grid, int stake) {
  final native = SlotGate.instance.evaluate(grid, stake);
  if (native != null) return _fromNative(native);
  return _evaluateDart(grid, stake);
}

SpinOutcome _evaluateDart(List<List<Mark>> grid, int stake) {
  final lineBet = stake ~/ lineCount;
  final hits = <Cell>{};
  var payout = 0;

  for (var line = 0; line < paylines.length; line++) {
    final rows = paylines[line];
    final cells = List<Mark>.generate(5, (reel) => grid[reel][rows[reel]]);
    final run = _bestRun(cells);
    if (run.pay <= 0 || lineBet <= 0) continue;
    payout += run.pay * lineBet;
    for (var reel = 0; reel < run.length; reel++) {
      hits.add(Cell(reel, rows[reel]));
    }
  }

  final scatters = <Cell>[];
  for (var reel = 0; reel < 5; reel++) {
    for (var row = 0; row < 3; row++) {
      if (grid[reel][row].isScatter) scatters.add(Cell(reel, row));
    }
  }
  final scatterCount = scatters.length.clamp(0, 5);
  final scatterPay = stake * scatterStakePay[scatterCount];
  payout += scatterPay;
  if (scatterCount >= 3) hits.addAll(scatters);

  return SpinOutcome(
    grid: grid,
    payout: payout,
    scatterCount: scatterCount,
    freeSpins: scatterFreeSpins[scatterCount],
    tier: tierFor(payout, stake),
    hits: hits,
  );
}

class _Run {
  const _Run(this.pay, this.length);

  final int pay;
  final int length;
}

_Run _bestRun(List<Mark> cells) {
  var wilds = 0;
  for (final mark in cells) {
    if (!mark.isWild) break;
    wilds++;
  }
  var bestPay = wilds >= 3 ? linePay(Mark.wild, wilds) : 0;
  var bestLength = wilds >= 3 ? wilds : 0;

  Mark? target;
  var count = 0;
  for (final mark in cells) {
    if (mark.isScatter) break;
    if (mark.isWild) {
      count++;
      continue;
    }
    if (target == null) {
      target = mark;
      count++;
      continue;
    }
    if (mark != target) break;
    count++;
  }
  if (target != null && count >= 3) {
    final pay = linePay(target, count);
    if (pay > bestPay) {
      bestPay = pay;
      bestLength = count;
    }
  }
  return _Run(bestPay, bestLength);
}

/// Fixed strips. Scatters sit only on reels 1, 3 and 5, with gaps so a
/// single reel cannot show three of them.
final reelStrips = <List<Mark>>[
  _strip(
    body: const [
      Mark.cherry, Mark.orange, Mark.grape, Mark.bell, Mark.bar,
      Mark.cherry, Mark.star, Mark.ring, Mark.orange, Mark.crown,
      Mark.cherry, Mark.grape, Mark.diamond, Mark.orange, Mark.seven,
      Mark.bell, Mark.bar, Mark.cherry, Mark.star, Mark.orange,
      Mark.grape, Mark.ring, Mark.cherry, Mark.crown, Mark.bar,
      Mark.bell, Mark.orange, Mark.grape, Mark.star, Mark.cherry,
    ],
    inserts: const [Mark.wild, Mark.scatter, Mark.wild, Mark.scatter, Mark.diamond],
  ),
  _strip(
    body: const [
      Mark.orange, Mark.grape, Mark.cherry, Mark.bell, Mark.star,
      Mark.bar, Mark.orange, Mark.ring, Mark.grape, Mark.crown,
      Mark.cherry, Mark.bell, Mark.orange, Mark.seven, Mark.bar,
      Mark.grape, Mark.star, Mark.cherry, Mark.ring, Mark.orange,
      Mark.diamond, Mark.bell, Mark.grape, Mark.bar, Mark.cherry,
      Mark.crown, Mark.orange, Mark.star, Mark.grape, Mark.bell,
    ],
    inserts: const [Mark.wild, Mark.seven, Mark.wild, Mark.diamond],
  ),
  _strip(
    body: const [
      Mark.grape, Mark.cherry, Mark.orange, Mark.star, Mark.bell,
      Mark.bar, Mark.grape, Mark.crown, Mark.cherry, Mark.ring,
      Mark.orange, Mark.seven, Mark.grape, Mark.bar, Mark.star,
      Mark.cherry, Mark.diamond, Mark.orange, Mark.bell, Mark.grape,
      Mark.ring, Mark.cherry, Mark.bar, Mark.crown, Mark.orange,
      Mark.star, Mark.grape, Mark.bell, Mark.cherry, Mark.bar,
    ],
    inserts: const [Mark.scatter, Mark.wild, Mark.scatter, Mark.wild, Mark.scatter],
  ),
  _strip(
    body: const [
      Mark.bell, Mark.orange, Mark.cherry, Mark.grape, Mark.ring,
      Mark.bar, Mark.star, Mark.orange, Mark.crown, Mark.cherry,
      Mark.grape, Mark.seven, Mark.bell, Mark.bar, Mark.orange,
      Mark.diamond, Mark.cherry, Mark.star, Mark.grape, Mark.ring,
      Mark.orange, Mark.bell, Mark.bar, Mark.cherry, Mark.crown,
      Mark.grape, Mark.star, Mark.orange, Mark.bell, Mark.cherry,
    ],
    inserts: const [Mark.wild, Mark.diamond, Mark.wild, Mark.seven],
  ),
  _strip(
    body: const [
      Mark.bar, Mark.cherry, Mark.orange, Mark.grape, Mark.star,
      Mark.ring, Mark.bar, Mark.bell, Mark.cherry, Mark.crown,
      Mark.orange, Mark.grape, Mark.seven, Mark.bar, Mark.star,
      Mark.cherry, Mark.diamond, Mark.orange, Mark.ring, Mark.grape,
      Mark.bell, Mark.bar, Mark.cherry, Mark.crown, Mark.star,
      Mark.orange, Mark.grape, Mark.bell, Mark.cherry, Mark.bar,
    ],
    inserts: const [Mark.scatter, Mark.wild, Mark.scatter, Mark.wild, Mark.diamond],
  ),
];

List<Mark> _strip({required List<Mark> body, required List<Mark> inserts}) {
  final out = <Mark>[];
  final gap = body.length / inserts.length;
  var next = gap / 2;
  var insertAt = 0;
  for (var i = 0; i < body.length; i++) {
    if (insertAt < inserts.length && i >= next) {
      out.add(inserts[insertAt]);
      insertAt++;
      next += gap;
    }
    out.add(body[i]);
  }
  while (insertAt < inserts.length) {
    out.add(inserts[insertAt]);
    insertAt++;
  }
  return out;
}

/// First frame of the cabinet: reel-major, nothing to collect.
const openingGrid = <List<Mark>>[
  [Mark.crown, Mark.orange, Mark.star],
  [Mark.cherry, Mark.seven, Mark.bell],
  [Mark.diamond, Mark.grape, Mark.crown],
  [Mark.bell, Mark.ring, Mark.orange],
  [Mark.star, Mark.bar, Mark.cherry],
];
