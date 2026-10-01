enum Mark {
  cherry,
  orange,
  grape,
  bell,
  bar,
  ring,
  star,
  crown,
  diamond,
  seven,
  wild,
  scatter;

  String get asset => 'assets/symbols/$name.webp';

  String get label => switch (this) {
        Mark.cherry => 'Cherry',
        Mark.orange => 'Orange',
        Mark.grape => 'Grapes',
        Mark.bell => 'Bell',
        Mark.bar => 'Bar',
        Mark.ring => 'Ring',
        Mark.star => 'Star',
        Mark.crown => 'Crown',
        Mark.diamond => 'Diamond',
        Mark.seven => 'Seven',
        Mark.wild => 'Wild',
        Mark.scatter => 'Scatter',
      };

  bool get isWild => this == Mark.wild;

  bool get isScatter => this == Mark.scatter;
}

/// Line-bet multipliers for 3, 4 and 5 of a kind, left to right.
const linePays = <Mark, List<int>>{
  Mark.cherry: [10, 24, 60],
  Mark.orange: [10, 24, 60],
  Mark.grape: [12, 32, 80],
  Mark.bell: [12, 32, 90],
  Mark.bar: [15, 40, 110],
  Mark.ring: [18, 50, 140],
  Mark.star: [24, 70, 200],
  Mark.crown: [30, 90, 250],
  Mark.diamond: [40, 120, 400],
  Mark.seven: [50, 160, 600],
  Mark.wild: [60, 220, 1000],
};

int linePay(Mark mark, int count) {
  if (count < 3 || count > 5) return 0;
  final table = linePays[mark];
  if (table == null) return 0;
  return table[count - 3];
}

/// Total-stake multipliers and free-spin awards, indexed by scatter count.
const scatterStakePay = <int>[0, 0, 0, 2, 10, 50];
const scatterFreeSpins = <int>[0, 0, 0, 8, 12, 20];
