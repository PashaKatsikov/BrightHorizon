import 'marks.dart';

/// Store builds set this to false. While it is true, an invisible control
/// on the cabinet opens situation presets and dismisses itself after a choice,
/// so the screen underneath can be captured cleanly.
const bool cheatMenuEnabled = true;

enum Cheat {
  bigWin,
  megaWin,
  jackpot,
  freeSpins,
  smallWin,
  deadSpin,
  refill,
}

/// Hand-built windows. [Cabinet] evaluates them with the real paytable,
/// so the banner matches the credits that land.
const cheatGrids = <Cheat, List<List<Mark>>>{
  Cheat.bigWin: [
    [Mark.crown, Mark.crown, Mark.crown, Mark.crown, Mark.crown],
    [Mark.cherry, Mark.orange, Mark.grape, Mark.bell, Mark.bar],
    [Mark.star, Mark.ring, Mark.diamond, Mark.seven, Mark.cherry],
  ],
  Cheat.megaWin: [
    [Mark.seven, Mark.seven, Mark.seven, Mark.seven, Mark.seven],
    [Mark.cherry, Mark.orange, Mark.grape, Mark.bell, Mark.bar],
    [Mark.star, Mark.ring, Mark.diamond, Mark.crown, Mark.cherry],
  ],
  Cheat.jackpot: [
    [Mark.wild, Mark.wild, Mark.wild, Mark.wild, Mark.wild],
    [Mark.cherry, Mark.orange, Mark.grape, Mark.bell, Mark.bar],
    [Mark.star, Mark.ring, Mark.diamond, Mark.crown, Mark.seven],
  ],
  Cheat.freeSpins: [
    [Mark.scatter, Mark.grape, Mark.star, Mark.crown, Mark.bar],
    [Mark.cherry, Mark.bell, Mark.scatter, Mark.diamond, Mark.grape],
    [Mark.orange, Mark.bar, Mark.ring, Mark.seven, Mark.scatter],
  ],
  Cheat.smallWin: [
    [Mark.cherry, Mark.cherry, Mark.cherry, Mark.orange, Mark.grape],
    [Mark.star, Mark.ring, Mark.crown, Mark.diamond, Mark.seven],
    [Mark.bar, Mark.bell, Mark.grape, Mark.star, Mark.ring],
  ],
  Cheat.deadSpin: [
    [Mark.cherry, Mark.orange, Mark.grape, Mark.bell, Mark.bar],
    [Mark.star, Mark.ring, Mark.crown, Mark.diamond, Mark.seven],
    [Mark.bar, Mark.grape, Mark.orange, Mark.cherry, Mark.star],
  ],
};

/// Grids above are stored row-major. The engine wants reel-major.
List<List<Mark>> cheatReelGrid(Cheat cheat) {
  final rows = cheatGrids[cheat]!;
  return List.generate(5, (reel) {
    return List.generate(3, (row) => rows[row][reel]);
  });
}
