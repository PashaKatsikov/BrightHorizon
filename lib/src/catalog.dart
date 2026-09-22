import 'dart:ui';

import 'frames.dart';

enum Kind { coin, fruit, star, seven }

enum Rarity { common, uncommon, rare, special }

extension RarityLabel on Rarity {
  String get label {
    switch (this) {
      case Rarity.common:
        return 'Common';
      case Rarity.uncommon:
        return 'Uncommon';
      case Rarity.rare:
        return 'Rare';
      case Rarity.special:
        return 'Special';
    }
  }
}

class ItemDef {
  final String id;
  final String name;
  final String detail;
  final Rarity rarity;
  final Kind kind;
  final Frame frame;
  final int value;

  const ItemDef({
    required this.id,
    required this.name,
    required this.detail,
    required this.rarity,
    required this.kind,
    required this.frame,
    required this.value,
  });
}

class Dressing {
  final Frame frame;
  final double x;
  final double y;
  final double width;
  final bool floor;

  const Dressing(this.frame, this.x, this.y, this.width, {this.floor = false});
}

class Room {
  final String id;
  final String name;
  final String blurb;
  final String background;
  final int cost;
  final double coinMul;
  final double fruitMul;
  final double starMul;
  final double sevenMul;
  final double eventMul;
  final double coinLife;
  final List<Offset> spawns;
  final List<Dressing> dressing;
  final Map<String, double> events;

  const Room({
    required this.id,
    required this.name,
    required this.blurb,
    required this.background,
    required this.cost,
    required this.coinMul,
    required this.fruitMul,
    required this.starMul,
    required this.sevenMul,
    required this.eventMul,
    required this.coinLife,
    required this.spawns,
    required this.dressing,
    required this.events,
  });
}

class UpgradeDef {
  final String id;
  final String name;
  final String detail;
  final List<int> costs;

  const UpgradeDef(this.id, this.name, this.detail, this.costs);

  int get maxLevel => costs.length;
}

class AlbumEvent {
  final String id;
  final String name;
  final String where;
  final String detail;
  final Frame frame;
  final int bonus;

  const AlbumEvent({
    required this.id,
    required this.name,
    required this.where,
    required this.detail,
    required this.frame,
    required this.bonus,
  });
}

const upgradeSpawn = 'spawn';
const upgradeDuration = 'duration';
const upgradeValue = 'value';
const upgradeEvents = 'events';
const upgradeSlots = 'slots';

final upgrades = <UpgradeDef>[
  const UpgradeDef(
    upgradeSpawn,
    'Quicker Rooms',
    'Objects show up more often.',
    [40, 75, 130, 210, 320],
  ),
  const UpgradeDef(
    upgradeDuration,
    'Longer Glow',
    'Stars and sevens linger a little longer.',
    [60, 110, 180, 280, 420],
  ),
  const UpgradeDef(
    upgradeValue,
    'Fuller Hands',
    'Everything you pick up is worth more gleam.',
    [70, 120, 200, 320, 480],
  ),
  const UpgradeDef(
    upgradeEvents,
    'Keen Weather',
    'Rare motions come around sooner.',
    [80, 140, 230, 360, 520],
  ),
  const UpgradeDef(
    upgradeSlots,
    'Wider Gaze',
    'More objects can share the room at once.',
    [55, 100, 170, 260, 400],
  ),
];

final items = <ItemDef>[
  ItemDef(
    id: 'bright_coin',
    name: 'Bright Coin',
    detail: 'The ordinary coin of these rooms. It drifts, it shines, it adds up.',
    rarity: Rarity.common,
    kind: Kind.coin,
    frame: coinFrame,
    value: 1,
  ),
  ItemDef(
    id: 'star_disc',
    name: 'Star Disc',
    detail: 'A coin stamped with a star. Worth a little more than the plain ones.',
    rarity: Rarity.uncommon,
    kind: Kind.coin,
    frame: starDiscFrame,
    value: 2,
  ),
  ItemDef(
    id: 'gilded_diamond',
    name: 'Gilded Diamond',
    detail: 'Turned on its corner, easy to lose among the round coins.',
    rarity: Rarity.uncommon,
    kind: Kind.coin,
    frame: diamondFrame,
    value: 2,
  ),
  ItemDef(
    id: 'solar_burst',
    name: 'Solar Burst',
    detail: 'A coin that forgot it was a coin. It shows up in the richer streams.',
    rarity: Rarity.rare,
    kind: Kind.coin,
    frame: burstFrame,
    value: 4,
  ),
  ItemDef(
    id: 'hex_seal',
    name: 'Hex Seal',
    detail: 'Six sides, a small gem, and a habit of arriving with company.',
    rarity: Rarity.rare,
    kind: Kind.coin,
    frame: hexFrame,
    value: 4,
  ),
  ItemDef(
    id: 'apple',
    name: 'Garden Apple',
    detail: 'Red, heavy, and in no particular hurry.',
    rarity: Rarity.uncommon,
    kind: Kind.fruit,
    frame: appleFrame,
    value: 5,
  ),
  ItemDef(
    id: 'orange',
    name: 'Sun Orange',
    detail: 'Warm even in a violet room. It rolls a slow arc across the floor.',
    rarity: Rarity.uncommon,
    kind: Kind.fruit,
    frame: orangeFrame,
    value: 5,
  ),
  ItemDef(
    id: 'grapes',
    name: 'Violet Grapes',
    detail: 'A cluster that catches the same light as the stars.',
    rarity: Rarity.uncommon,
    kind: Kind.fruit,
    frame: grapesFrame,
    value: 5,
  ),
  ItemDef(
    id: 'cherries',
    name: 'Twin Cherries',
    detail: 'Two of them, always. If you see one stem, the other is right there.',
    rarity: Rarity.uncommon,
    kind: Kind.fruit,
    frame: cherriesFrame,
    value: 5,
  ),
  ItemDef(
    id: 'apple_streak',
    name: 'Apple Streak',
    detail: 'An apple moving fast enough to leave a gold trail.',
    rarity: Rarity.rare,
    kind: Kind.fruit,
    frame: appleStreakFrame,
    value: 8,
  ),
  ItemDef(
    id: 'orange_streak',
    name: 'Orange Streak',
    detail: 'The trail is brighter than the fruit. Follow the light, then tap.',
    rarity: Rarity.rare,
    kind: Kind.fruit,
    frame: orangeStreakFrame,
    value: 8,
  ),
  ItemDef(
    id: 'grape_streak',
    name: 'Grape Streak',
    detail: 'Violet light smears behind the cluster when the room gets busy.',
    rarity: Rarity.rare,
    kind: Kind.fruit,
    frame: grapeStreakFrame,
    value: 8,
  ),
  ItemDef(
    id: 'cherry_streak',
    name: 'Cherry Streak',
    detail: 'A pink wake. It does not last, and neither do the cherries.',
    rarity: Rarity.rare,
    kind: Kind.fruit,
    frame: cherryStreakFrame,
    value: 8,
  ),
  ItemDef(
    id: 'violet_star',
    name: 'Violet Star',
    detail: 'A cut star. It stays only a few seconds, and it is worth the wait.',
    rarity: Rarity.rare,
    kind: Kind.star,
    frame: starFrame,
    value: 25,
  ),
  ItemDef(
    id: 'spiral_star',
    name: 'Spiral Star',
    detail: 'The center turns. If you blink, it is already gone.',
    rarity: Rarity.special,
    kind: Kind.star,
    frame: spiralStarFrame,
    value: 40,
  ),
  ItemDef(
    id: 'core_star',
    name: 'Core Star',
    detail: 'A white heart inside the crystal. Brighter than the ordinary star.',
    rarity: Rarity.special,
    kind: Kind.star,
    frame: coreStarFrame,
    value: 40,
  ),
  ItemDef(
    id: 'lattice_star',
    name: 'Lattice Star',
    detail: 'Facets stacked like a window. It likes the violet rooms.',
    rarity: Rarity.special,
    kind: Kind.star,
    frame: latticeStarFrame,
    value: 40,
  ),
  ItemDef(
    id: 'tide_star',
    name: 'Tide Star',
    detail: 'Blue at the edges, as if the room remembered the sky.',
    rarity: Rarity.special,
    kind: Kind.star,
    frame: tideStarFrame,
    value: 40,
  ),
  ItemDef(
    id: 'violet_seven',
    name: 'Violet Seven',
    detail: 'The rarest ordinary thing in the building. Two to four seconds, then nothing.',
    rarity: Rarity.special,
    kind: Kind.seven,
    frame: sevenFrame,
    value: 75,
  ),
  ItemDef(
    id: 'crest_seven',
    name: 'Crest Seven',
    detail: 'Gold corners, a jewel at the joint. It announces itself and then leaves.',
    rarity: Rarity.special,
    kind: Kind.seven,
    frame: crestSevenFrame,
    value: 110,
  ),
  ItemDef(
    id: 'pillar_seven',
    name: 'Pillar Seven',
    detail: 'Taller than the others. It stands where R can see it.',
    rarity: Rarity.special,
    kind: Kind.seven,
    frame: pillarSevenFrame,
    value: 110,
  ),
  ItemDef(
    id: 'curl_seven',
    name: 'Curl Seven',
    detail: 'The foot curls like a hook. Easy to mistake for a reflection.',
    rarity: Rarity.special,
    kind: Kind.seven,
    frame: curlSevenFrame,
    value: 110,
  ),
  ItemDef(
    id: 'shard_seven',
    name: 'Shard Seven',
    detail: 'Cut rough, on purpose. It flashes once before it fades.',
    rarity: Rarity.special,
    kind: Kind.seven,
    frame: shardSevenFrame,
    value: 110,
  ),
];

ItemDef itemById(String id) => items.firstWhere((item) => item.id == id);

final album = <AlbumEvent>[
  AlbumEvent(
    id: 'orbit',
    name: 'Orbit of Coins',
    where: 'Any room, often the Atrium',
    detail: 'Coins leave their paths and take a lap around R.',
    frame: coinFrame,
    bonus: 80,
  ),
  AlbumEvent(
    id: 'veiled',
    name: 'Veiled Star',
    where: 'Violet Room',
    detail: 'A star appears off to the side, away from the usual drift.',
    frame: starFrame,
    bonus: 100,
  ),
  AlbumEvent(
    id: 'sevenfold',
    name: 'Sevenfold',
    where: 'R Chamber',
    detail: 'Seven things arrive in a row. The last one is the seven.',
    frame: sevenFrame,
    bonus: 150,
  ),
  AlbumEvent(
    id: 'current',
    name: 'Shared Current',
    where: 'Fruit Chamber',
    detail: 'Several fruits take the same line across the floor.',
    frame: orangeStreakFrame,
    bonus: 70,
  ),
  AlbumEvent(
    id: 'pull',
    name: "R's Attraction",
    where: 'R Chamber',
    detail: 'R wakes and draws whatever is nearby toward the center.',
    frame: letterFrame,
    bonus: 90,
  ),
  AlbumEvent(
    id: 'stream',
    name: 'Coin Stream',
    where: 'Golden Atrium',
    detail: 'A run of coins crosses the hall. Take three of them.',
    frame: burstFrame,
    bonus: 60,
  ),
  AlbumEvent(
    id: 'leaves',
    name: 'Among the Leaves',
    where: 'Violet Garden',
    detail: 'A star tucks into the plants. Part of it still shows.',
    frame: spiralStarFrame,
    bonus: 120,
  ),
  AlbumEvent(
    id: 'chain',
    name: 'The Chain',
    where: 'Any room',
    detail: 'Coins, then a fruit, then R, then a star. You only have to be there for it.',
    frame: coreStarFrame,
    bonus: 100,
  ),
];

AlbumEvent albumById(String id) => album.firstWhere((event) => event.id == id);

final rooms = <Room>[
  Room(
    id: 'horizon',
    name: 'Horizon Hall',
    blurb: 'The first room. Coins, fruit, stars and sevens arrive at an even pace. Stay with it and R will start to move things.',
    background: bgHorizon,
    cost: 0,
    coinMul: 1,
    fruitMul: 1,
    starMul: 1,
    sevenMul: 1,
    eventMul: 1,
    coinLife: 1,
    spawns: const [Offset(0.18, 0.62), Offset(0.82, 0.58), Offset(0.5, 0.74), Offset(0.32, 0.46)],
    dressing: [
      Dressing(rZoneFrame, 0.50, 0.58, 0.30, floor: true),
      Dressing(spawnZoneFrame, 0.18, 0.74, 0.13, floor: true),
      Dressing(colTaperFrame, 0.08, 0.60, 0.09),
      Dressing(colFlutedFrame, 0.92, 0.60, 0.09),
      Dressing(archFrame, 0.50, 0.24, 0.13),
    ],
    events: const {
      'orbit': 1.2,
      'veiled': 1,
      'sevenfold': 0.7,
      'current': 0.8,
      'pull': 1,
      'stream': 0.5,
      'leaves': 0,
    },
  ),
  Room(
    id: 'fruit',
    name: 'Fruit Chamber',
    blurb: 'Fruit crosses this room more often, and some of it slips behind the columns. Follow the arc, not only the center.',
    background: bgFruit,
    cost: 100,
    coinMul: 0.85,
    fruitMul: 1.35,
    starMul: 0.9,
    sevenMul: 0.9,
    eventMul: 1,
    coinLife: 1,
    spawns: const [Offset(0.16, 0.55), Offset(0.84, 0.62), Offset(0.28, 0.74), Offset(0.70, 0.42)],
    dressing: [
      Dressing(panelHexFrame, 0.50, 0.70, 0.16, floor: true),
      Dressing(spawnZoneFrame, 0.80, 0.66, 0.12, floor: true),
      Dressing(colCurveFrame, 0.08, 0.58, 0.09),
      Dressing(colGothicFrame, 0.92, 0.58, 0.09),
      Dressing(railFrame, 0.72, 0.78, 0.14),
    ],
    events: const {
      'orbit': 0.6,
      'veiled': 0.7,
      'sevenfold': 0.5,
      'current': 3,
      'pull': 0.8,
      'stream': 0.4,
      'leaves': 0,
    },
  ),
  Room(
    id: 'violet',
    name: 'Violet Room',
    blurb: 'Stars prefer this light. They do not stay long, and they rarely arrive where you were already looking.',
    background: bgViolet,
    cost: 250,
    coinMul: 0.8,
    fruitMul: 0.85,
    starMul: 1.5,
    sevenMul: 1.15,
    eventMul: 1.1,
    coinLife: 1,
    spawns: const [Offset(0.22, 0.48), Offset(0.78, 0.70), Offset(0.50, 0.40), Offset(0.62, 0.76)],
    dressing: [
      Dressing(rZoneFrame, 0.50, 0.60, 0.28, floor: true),
      Dressing(panelDiamondFrame, 0.28, 0.74, 0.12, floor: true),
      Dressing(colGothicFrame, 0.08, 0.56, 0.09),
      Dressing(colCurveFrame, 0.92, 0.56, 0.09),
      Dressing(shrineFrame, 0.50, 0.24, 0.12),
    ],
    events: const {
      'orbit': 0.5,
      'veiled': 3,
      'sevenfold': 1,
      'current': 0.4,
      'pull': 1,
      'stream': 0.3,
      'leaves': 0,
    },
  ),
  Room(
    id: 'rchamber',
    name: 'R Chamber',
    blurb: 'Built around the letter. When R wakes, the floor answers, and the rare motions come closer together.',
    background: bgR,
    cost: 500,
    coinMul: 0.9,
    fruitMul: 0.9,
    starMul: 1.1,
    sevenMul: 1.25,
    eventMul: 1.4,
    coinLife: 1,
    spawns: const [Offset(0.24, 0.66), Offset(0.76, 0.64), Offset(0.50, 0.36), Offset(0.40, 0.76)],
    dressing: [
      Dressing(rZoneFrame, 0.50, 0.60, 0.32, floor: true),
      Dressing(platformFrame, 0.50, 0.62, 0.22, floor: true),
      Dressing(colFlutedFrame, 0.08, 0.56, 0.09),
      Dressing(colTaperFrame, 0.92, 0.56, 0.09),
      Dressing(shrineFrame, 0.50, 0.22, 0.12),
    ],
    events: const {
      'orbit': 1.4,
      'veiled': 0.8,
      'sevenfold': 2.6,
      'current': 0.5,
      'pull': 2.8,
      'stream': 0.6,
      'leaves': 0,
    },
  ),
  Room(
    id: 'garden',
    name: 'Violet Garden',
    blurb: 'Stars tuck into the plants. If something glints and then seems to vanish, it is probably still there.',
    background: bgGarden,
    cost: 900,
    coinMul: 0.85,
    fruitMul: 1.3,
    starMul: 1.15,
    sevenMul: 1,
    eventMul: 1.25,
    coinLife: 1,
    spawns: const [Offset(0.18, 0.70), Offset(0.82, 0.68), Offset(0.36, 0.44), Offset(0.64, 0.76)],
    dressing: [
      Dressing(spawnZoneFrame, 0.50, 0.72, 0.14, floor: true),
      Dressing(bloomFrame, 0.12, 0.64, 0.12),
      Dressing(lampVineFrame, 0.88, 0.58, 0.11),
      Dressing(urnFrame, 0.26, 0.78, 0.11),
      Dressing(bushFrame, 0.74, 0.76, 0.12),
    ],
    events: const {
      'orbit': 0.5,
      'veiled': 1.2,
      'sevenfold': 0.6,
      'current': 1.3,
      'pull': 0.8,
      'stream': 0.3,
      'leaves': 4,
    },
  ),
  Room(
    id: 'atrium',
    name: 'Golden Atrium',
    blurb: 'Coins travel in groups, and sometimes they take a lap around R. They leave sooner here than they do in the hall.',
    background: bgAtrium,
    cost: 1500,
    coinMul: 1.6,
    fruitMul: 0.7,
    starMul: 0.85,
    sevenMul: 0.85,
    eventMul: 1.15,
    coinLife: 0.72,
    spawns: const [Offset(0.14, 0.60), Offset(0.86, 0.58), Offset(0.30, 0.74), Offset(0.70, 0.42), Offset(0.50, 0.78)],
    dressing: [
      Dressing(medallionFrame, 0.50, 0.66, 0.18, floor: true),
      Dressing(daisFrame, 0.50, 0.58, 0.20, floor: true),
      Dressing(lanternFrame, 0.10, 0.60, 0.09),
      Dressing(goldArchFrame, 0.86, 0.40, 0.16),
    ],
    events: const {
      'orbit': 2.4,
      'veiled': 0.4,
      'sevenfold': 0.5,
      'current': 0.4,
      'pull': 1.2,
      'stream': 3.2,
      'leaves': 0,
    },
  ),
];

Room roomById(String id) => rooms.firstWhere((room) => room.id == id);

Room? nextLocked(Set<String> unlocked) {
  for (final room in rooms) {
    if (!unlocked.contains(room.id)) return room;
  }
  return null;
}

Set<String> sheetsFor(Room room) {
  final assets = <String>{
    letterFrame.asset,
    orbFrame.asset,
    pickupFrame.asset,
    spawnFxFrame.asset,
    disappearFrame.asset,
    rActivateFrame.asset,
    rareFxFrame.asset,
  };
  for (final item in items) {
    assets.add(item.frame.asset);
  }
  for (final piece in room.dressing) {
    assets.add(piece.frame.asset);
  }
  return assets;
}
