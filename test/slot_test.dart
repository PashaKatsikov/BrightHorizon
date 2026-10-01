import 'dart:math';

import 'package:bright_horizon/src/slot/cheat.dart';
import 'package:bright_horizon/src/slot/engine.dart';
import 'package:bright_horizon/src/slot/marks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SpinOutcome play(Cheat cheat, {int stake = 100}) {
    return SlotEngine().spin(stake: stake, cheat: cheat);
  }

  test('the opening window pays nothing', () {
    final outcome = evaluate(openingGrid, 100);
    expect(outcome.payout, 0);
    expect(outcome.freeSpins, 0);
  });

  test('a crown line is a big win', () {
    final outcome = play(Cheat.bigWin);
    expect(outcome.payout, 250 * (100 ~/ 20));
    expect(outcome.tier, Tier.big);
    expect(outcome.freeSpins, 0);
  });

  test('five sevens are a mega win', () {
    final outcome = play(Cheat.megaWin);
    expect(outcome.payout, 600 * 5);
    expect(outcome.tier, Tier.mega);
  });

  test('five wilds are a jackpot', () {
    final outcome = play(Cheat.jackpot);
    expect(outcome.tier, Tier.jackpot);
    expect(outcome.payout, greaterThanOrEqualTo(1000 * 5));
  });

  test('three scatters award free spins and no line prize', () {
    final outcome = play(Cheat.freeSpins);
    expect(outcome.scatterCount, 3);
    expect(outcome.freeSpins, 8);
    expect(outcome.payout, 2 * 100);
    expect(outcome.tier, Tier.none);
    expect(outcome.hits, hasLength(3));
  });

  test('three cherries stay a small win', () {
    final outcome = play(Cheat.smallWin);
    expect(outcome.payout, 10 * 5);
    expect(outcome.tier, Tier.none);
    expect(outcome.hits, hasLength(3));
  });

  test('a dead spin pays nothing', () {
    final outcome = play(Cheat.deadSpin);
    expect(outcome.payout, 0);
    expect(outcome.freeSpins, 0);
    expect(outcome.hits, isEmpty);
  });

  test('wilds extend a cherry run', () {
    final grid = <List<Mark>>[
      [Mark.cherry, Mark.orange, Mark.star],
      [Mark.wild, Mark.bell, Mark.bar],
      [Mark.cherry, Mark.grape, Mark.ring],
      [Mark.orange, Mark.seven, Mark.crown],
      [Mark.bar, Mark.diamond, Mark.star],
    ];
    final outcome = evaluate(grid, 100);
    expect(outcome.payout, 10 * 5);
    expect(outcome.hits, containsAll(const [Cell(0, 0), Cell(1, 0), Cell(2, 0)]));
  });

  test('return stays inside a social-casino range', () {
    final engine = SlotEngine(random: Random(7));
    var wagered = 0;
    var returned = 0;
    for (var i = 0; i < 8000; i++) {
      const stake = 20;
      wagered += stake;
      final outcome = engine.spin(stake: stake);
      returned += outcome.payout;
      var free = outcome.freeSpins;
      var guard = 0;
      while (free > 0 && guard < 80) {
        guard++;
        free--;
        final extra = engine.spin(stake: stake);
        returned += extra.payout * 2;
        free += extra.freeSpins;
      }
    }
    final rtp = returned / wagered;
    expect(rtp, inInclusiveRange(0.82, 1.08), reason: 'rtp=$rtp');
  });
}
