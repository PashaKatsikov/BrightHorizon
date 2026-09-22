import 'dart:math' as math;
import 'dart:ui';

import 'catalog.dart';
import 'frames.dart';
import 'profile.dart';
import 'sheets.dart';

enum Motion { drift, orbit, lane, homing }

class Actor {
  Actor({
    required this.id,
    required this.item,
    required this.x,
    required this.y,
    required this.life,
    required this.motion,
  });

  final int id;
  final ItemDef item;
  double x;
  double y;
  double vx = 0;
  double vy = 0;
  double life;
  double age = 0;
  double phase = 0;
  Motion motion;
  double orbitAngle = 0;
  double pathT = 0;
  double pathOffset = 0;
  bool key = false;
  bool behind = false;
  String? eventId;
}

class Burst {
  Burst({required this.frame, required this.x, required this.y, required this.life, required this.width});

  final Frame frame;
  final double x;
  final double y;
  final double life;
  final double width;
  double age = 0;
}

class Floater {
  Floater(this.text, this.x, this.y, this.color);

  final String text;
  final double x;
  final double y;
  final Color color;
  double age = 0;
}

class Capture {
  Capture(this.eventId, this.bonus);

  final String eventId;
  final int bonus;
}

class SessionReport {
  SessionReport({
    required this.roomId,
    required this.roomName,
    required this.coins,
    required this.fruits,
    required this.stars,
    required this.sevens,
    required this.events,
    required this.gleam,
    required this.seconds,
    required this.eventNames,
  });

  final String roomId;
  final String roomName;
  final int coins;
  final int fruits;
  final int stars;
  final int sevens;
  final int events;
  final int gleam;
  final int seconds;
  final List<String> eventNames;
}

class Observation {
  Observation({required this.room, required this.profile});

  final Room room;
  final Profile profile;
  final math.Random rng = math.Random();

  final List<Actor> actors = [];
  final List<Burst> bursts = [];
  final List<Floater> floaters = [];

  int _seq = 1;
  double elapsed = 0;
  double dry = 0;
  double spawnClock = 0.4;
  double eventClock = 0;
  double attuneLeft = 0;
  double pullLeft = 0;
  double rFlash = 0;
  double chainWait = 8;
  int coinsTowardChain = 0;
  int chainPhase = 0;
  double chainArm = 0;
  bool paused = false;
  bool finished = false;

  int sessionCoins = 0;
  int sessionFruits = 0;
  int sessionStars = 0;
  int sessionSevens = 0;
  int sessionEvents = 0;
  int sessionGleam = 0;
  final List<String> sessionEventNames = [];

  String? liveEvent;
  double eventLeft = 0;
  int eventCaught = 0;
  int sevenfoldStep = 0;
  double sevenfoldClock = 0;
  double _watchRemainder = 0;

  Capture? capture;
  bool cueRare = false;
  bool cueStream = false;
  bool cueR = false;
  int cueSpawn = 0;
  int cueMiss = 0;
  double eventSpan = 8;

  double get valueMul => 1 + 0.15 * profile.levelOf(upgradeValue);

  double get durationMul => 1 + 0.12 * profile.levelOf(upgradeDuration);

  int get cap => 5 + profile.levelOf(upgradeSlots);

  double get spawnEvery {
    final quicker = 1 - 0.09 * profile.levelOf(upgradeSpawn);
    return (1.25 * quicker).clamp(0.45, 2);
  }

  void tick(double dt) {
    if (paused || finished) return;
    elapsed += dt;
    dry += dt;
    rFlash = math.max(0, rFlash - dt);
    attuneLeft = math.max(0, attuneLeft - dt);
    if (pullLeft > 0) pullLeft = math.max(0, pullLeft - dt);

    _watchRemainder += dt;
    if (_watchRemainder >= 10) {
      final whole = _watchRemainder.floor();
      profile.addWatch(whole);
      _watchRemainder -= whole;
      profile.save();
    }

    _tickChain(dt);
    _tickEvent(dt);
    _tickSpawn(dt);
    _tickActors(dt);
    _tickBursts(dt);
    actors.removeWhere((actor) => actor.life <= 0);
    bursts.removeWhere((burst) => burst.age >= burst.life);
    floaters.removeWhere((floater) => floater.age >= 0.9);
  }

  void _tickSpawn(double dt) {
    spawnClock += dt;
    if (spawnClock < spawnEvery) return;
    if (actors.length >= cap) return;
    spawnClock = 0;
    final kind = _rollKind();
    _spawnKind(kind, key: false);
    if (room.id == 'atrium' && kind == Kind.coin && rng.nextDouble() < 0.45 && actors.length < cap + 2) {
      _spawnKind(Kind.coin, key: false, cluster: true);
    }
  }

  Kind _rollKind() {
    final pity = math.max(0, dry - 18) * 0.85;
    final early = elapsed < 12 ? 0.25 : 1.0;
    var coin = 66.0 * room.coinMul;
    var fruit = 23.0 * room.fruitMul;
    var star = (8.0 * room.starMul + pity) * early;
    var seven = (3.0 * room.sevenMul + pity * 0.35) * early;
    if (attuneLeft > 6) {
      star += 6;
      fruit += 4;
    }
    final total = coin + fruit + star + seven;
    var roll = rng.nextDouble() * total;
    if ((roll -= coin) <= 0) return Kind.coin;
    if ((roll -= fruit) <= 0) return Kind.fruit;
    if ((roll -= star) <= 0) return Kind.star;
    return Kind.seven;
  }

  Actor _spawnKind(
    Kind kind, {
    required bool key,
    bool cluster = false,
    Offset? at,
    Motion motion = Motion.drift,
    String? eventId,
    bool behind = false,
    double? lifeScale,
  }) {
    final item = _pickItem(kind);
    final spot = at ?? room.spawns[rng.nextInt(room.spawns.length)];
    final life = _lifeFor(kind) * (lifeScale ?? 1);
    final actor = Actor(
      id: _seq++,
      item: item,
      x: (spot.dx + (rng.nextDouble() - 0.5) * 0.04).clamp(0.08, 0.92),
      y: (spot.dy + (rng.nextDouble() - 0.5) * 0.04).clamp(0.34, 0.84),
      life: life,
      motion: motion,
    );
    actor.phase = rng.nextDouble() * math.pi * 2;
    actor.key = key;
    actor.eventId = eventId;
    actor.behind = behind || (!key && _tuck(kind));
    _aimDrift(actor, cluster);
    if (kind == Kind.star || kind == Kind.seven) {
      dry = 0;
      cueSpawn += 1;
      bursts.add(Burst(frame: spawnFxFrame, x: actor.x, y: actor.y, life: 0.45, width: 0.22));
    }
    actors.add(actor);
    return actor;
  }

  bool _tuck(Kind kind) {
    if (room.id == 'fruit' && kind == Kind.fruit) return rng.nextDouble() < 0.4;
    if (room.id == 'garden' && kind == Kind.star) return rng.nextDouble() < 0.45;
    return false;
  }

  void _aimDrift(Actor actor, bool cluster) {
    final dir = actor.x < 0.5 ? 1.0 : -1.0;
    final speed = cluster ? 0.13 : 0.05 + rng.nextDouble() * 0.035;
    actor.vx = dir * speed;
    actor.vy = (rng.nextDouble() - 0.5) * 0.025;
    if (actor.item.kind == Kind.seven) {
      actor.vx *= 0.25;
      actor.vy *= 0.25;
    } else if (actor.item.kind == Kind.star) {
      actor.vx *= 0.55;
    }
  }

  ItemDef _pickItem(Kind kind) {
    final roll = rng.nextDouble();
    switch (kind) {
      case Kind.coin:
        if (roll < 0.62) return itemById('bright_coin');
        if (roll < 0.76) return itemById('star_disc');
        if (roll < 0.88) return itemById('gilded_diamond');
        if (roll < 0.95) return itemById('solar_burst');
        return itemById('hex_seal');
      case Kind.fruit:
        final moving = room.id == 'fruit' ? 0.42 : room.id == 'garden' ? 0.34 : 0.22;
        if (roll < moving) {
          const movingIds = ['apple_streak', 'orange_streak', 'grape_streak', 'cherry_streak'];
          return itemById(movingIds[rng.nextInt(movingIds.length)]);
        }
        const still = ['apple', 'orange', 'grapes', 'cherries'];
        return itemById(still[rng.nextInt(still.length)]);
      case Kind.star:
        final rare = room.id == 'violet' || room.id == 'garden' ? 0.55 : 0.32;
        if (roll < rare) {
          const rareIds = ['spiral_star', 'core_star', 'lattice_star', 'tide_star'];
          return itemById(rareIds[rng.nextInt(rareIds.length)]);
        }
        return itemById('violet_star');
      case Kind.seven:
        if (roll < 0.45) return itemById('violet_seven');
        const rareIds = ['crest_seven', 'pillar_seven', 'curl_seven', 'shard_seven'];
        return itemById(rareIds[rng.nextInt(rareIds.length)]);
    }
  }

  double _lifeFor(Kind kind) {
    final roll = rng.nextDouble();
    switch (kind) {
      case Kind.coin:
        return (5 + roll * 3) * room.coinLife;
      case Kind.fruit:
        return 4 + roll * 3;
      case Kind.star:
        return (3 + roll * 2) * durationMul;
      case Kind.seven:
        return (2 + roll * 2) * durationMul;
    }
  }

  void _tickActors(double dt) {
    for (final actor in actors) {
      actor.age += dt;
      actor.life -= dt;
      switch (actor.motion) {
        case Motion.drift:
          if (pullLeft > 0) {
            _pull(actor, dt, 0.55);
          } else {
            actor.x += actor.vx * dt;
            actor.y += actor.vy * dt;
          }
        case Motion.orbit:
          actor.orbitAngle += dt * 1.15;
          actor.x = 0.50 + math.cos(actor.orbitAngle) * 0.18;
          actor.y = 0.52 + math.sin(actor.orbitAngle) * 0.10;
        case Motion.lane:
          actor.pathT += dt * 0.22;
          actor.x = -0.08 + actor.pathT;
          actor.y = 0.60 + math.sin(actor.pathT * 5 + actor.pathOffset) * 0.045;
        case Motion.homing:
          _pull(actor, dt, 0.9);
          final dx = actor.x - 0.50;
          final dy = actor.y - 0.50;
          if (dx * dx + dy * dy < 0.014 && chainPhase == 1) {
            _advanceChain();
          }
      }
      final offLeft = actor.x < -0.15;
      final offRight = actor.x > 1.15;
      if (actor.motion == Motion.drift || actor.motion == Motion.homing) {
        actor.y = actor.y.clamp(0.30, 0.86);
      }
      if (actor.motion == Motion.lane) {
        if (offRight) actor.life = 0;
      } else if (actor.motion != Motion.orbit && (offLeft || offRight)) {
        actor.life = 0;
      }
      if (actor.life <= 0) {
        if (actor.item.kind == Kind.star || actor.item.kind == Kind.seven) {
          cueMiss += 1;
          bursts.add(Burst(frame: disappearFrame, x: actor.x, y: actor.y, life: 0.4, width: 0.2));
        }
        if (actor.motion == Motion.homing && chainPhase == 1) {
          chainPhase = 0;
          coinsTowardChain = 3;
        } else if (actor.eventId == 'chain' && chainPhase == 3) {
          chainPhase = 0;
          chainWait = 32;
        }
      }
    }
  }

  void _pull(Actor actor, double dt, double strength) {
    final dx = 0.50 - actor.x;
    final dy = 0.50 - actor.y;
    actor.vx += dx * strength * dt * 3;
    actor.vy += dy * strength * dt * 3;
    final speed = math.sqrt(actor.vx * actor.vx + actor.vy * actor.vy);
    if (speed > 0.34) {
      actor.vx *= 0.34 / speed;
      actor.vy *= 0.34 / speed;
    }
    actor.x += actor.vx * dt;
    actor.y += actor.vy * dt;
  }

  void _tickBursts(double dt) {
    for (final burst in bursts) {
      burst.age += dt;
    }
    for (final floater in floaters) {
      floater.age += dt;
    }
  }

  void _tickChain(double dt) {
    if (chainWait > 0) {
      chainWait -= dt;
      return;
    }
    if (chainPhase == 2) {
      chainArm -= dt;
      if (chainArm <= 0) {
        final star = _spawnKind(
          Kind.star,
          key: true,
          eventId: 'chain',
          at: const Offset(0.50, 0.42),
          lifeScale: 1.15,
        );
        star.vx *= 0.2;
        chainPhase = 3;
        rFlash = 1;
        bursts.add(Burst(frame: rareFxFrame, x: 0.5, y: 0.48, life: 0.7, width: 0.42));
      }
    }
  }

  void _advanceChain() {
    chainPhase = 2;
    chainArm = 1.05;
    cueR = true;
    rFlash = 1.2;
    pullLeft = math.max(pullLeft, 2.2);
    bursts.add(Burst(frame: rActivateFrame, x: 0.5, y: 0.50, life: 0.7, width: 0.46));
  }

  void noteCoinForChain() {
    if (chainPhase != 0 || liveEvent != null || chainWait > 0) return;
    coinsTowardChain += 1;
    if (coinsTowardChain >= 5) {
      coinsTowardChain = 0;
      chainPhase = 1;
      final fruit = _spawnKind(
        Kind.fruit,
        key: false,
        at: Offset(0.18 + rng.nextDouble() * 0.64, 0.72),
        motion: Motion.homing,
      );
      fruit.vx = 0;
      fruit.vy = 0;
      fruit.life = math.max(fruit.life, 6);
    }
  }

  void _tickEvent(double dt) {
    if (liveEvent != null) {
      eventLeft -= dt;
      if (liveEvent == 'sevenfold') {
        sevenfoldClock -= dt;
        if (sevenfoldClock <= 0 && sevenfoldStep < 7) {
          _spawnSevenfoldStep();
        }
      }
      if (eventLeft <= 0) {
        _clearEventKeys();
        liveEvent = null;
      }
      return;
    }
    if (elapsed < 55 || chainPhase != 0) return;
    eventClock += dt;
    var gap = elapsed > 120 ? 30.0 : 44.0;
    gap *= 1 - 0.07 * profile.levelOf(upgradeEvents);
    gap /= room.eventMul;
    if (eventClock >= gap) {
      eventClock = 0;
      _beginEvent(_pickEvent());
    }
  }

  String _pickEvent() {
    final table = room.events.entries.where((entry) => entry.value > 0).toList();
    final total = table.fold<double>(0, (sum, entry) => sum + entry.value);
    var roll = rng.nextDouble() * total;
    for (final entry in table) {
      roll -= entry.value;
      if (roll <= 0) return entry.key;
    }
    return table.last.key;
  }

  void _beginEvent(String id) {
    liveEvent = id;
    eventCaught = 0;
    sevenfoldStep = 0;
    cueRare = true;
    if (id == 'stream') cueStream = true;
    if (id == 'pull') cueR = true;
    switch (id) {
      case 'orbit':
        eventLeft = 8;
        for (var i = 0; i < 7; i++) {
          final actor = _spawnKind(Kind.coin, key: true, eventId: id, motion: Motion.orbit, lifeScale: 1.3);
          actor.orbitAngle = i / 7 * math.pi * 2;
          actor.life = 8;
        }
        bursts.add(Burst(frame: rareFxFrame, x: 0.5, y: 0.5, life: 0.8, width: 0.5));
      case 'veiled':
        eventLeft = 5;
        final at = rng.nextBool() ? const Offset(0.16, 0.74) : const Offset(0.84, 0.40);
        final star = _spawnKind(Kind.star, key: true, eventId: id, at: at, lifeScale: 1.2);
        star.vx *= 0.15;
      case 'sevenfold':
        eventLeft = 12;
        sevenfoldClock = 0.15;
      case 'current':
        eventLeft = 7.5;
        for (var i = 0; i < 4; i++) {
          final actor = _spawnKind(
            Kind.fruit,
            key: true,
            eventId: id,
            motion: Motion.lane,
            at: const Offset(0.1, 0.6),
            lifeScale: 1.4,
          );
          actor.pathT = -0.12 * i;
          actor.pathOffset = 0.4;
          actor.life = 7;
        }
      case 'pull':
        eventLeft = 7;
        pullLeft = math.max(pullLeft, 6.5);
        rFlash = 1.4;
        final star = _spawnKind(Kind.star, key: true, eventId: id, at: const Offset(0.86, 0.70));
        star.life = 6.5;
        bursts.add(Burst(frame: rActivateFrame, x: 0.5, y: 0.5, life: 0.85, width: 0.55));
      case 'stream':
        eventLeft = 6.5;
        for (var i = 0; i < 10; i++) {
          final actor = _spawnKind(
            Kind.coin,
            key: true,
            eventId: id,
            motion: Motion.lane,
          );
          actor.pathT = -0.07 * i;
          actor.pathOffset = i * 0.55;
          actor.life = 6.2;
        }
      case 'leaves':
        eventLeft = 5;
        final star = _spawnKind(
          Kind.star,
          key: true,
          eventId: id,
          at: const Offset(0.20, 0.66),
          behind: true,
          lifeScale: 1.25,
        );
        star.vx = 0.01;
        star.vy = 0;
    }
    eventSpan = eventLeft;
  }

  void _spawnSevenfoldStep() {
    sevenfoldStep += 1;
    sevenfoldClock = 0.72;
    final step = sevenfoldStep;
    final at = Offset(0.22 + (step - 1) * 0.09, 0.46 + (step.isOdd ? 0.16 : 0));
    if (step < 7) {
      final kind = step.isEven ? Kind.fruit : Kind.coin;
      if (step == 5) {
        _spawnKind(Kind.star, key: false, at: at, eventId: 'sevenfold');
      } else {
        _spawnKind(kind, key: false, at: at, eventId: 'sevenfold');
      }
      return;
    }
    final seven = _spawnKind(Kind.seven, key: true, eventId: 'sevenfold', at: const Offset(0.62, 0.48));
    seven.life = math.max(seven.life, 3.2);
  }

  void _clearEventKeys() {
    for (final actor in actors) {
      if (actor.eventId == liveEvent) actor.key = false;
    }
  }

  int payout(ItemDef item) => (item.value * valueMul).round();

  Actor? hit(Offset local, Size size) {
    Actor? found;
    var best = -1.0;
    for (final actor in actors) {
      final rect = actorRectOf(actor, size);
      final slop = (rect.shortestSide * 0.12).clamp(6.0, 14.0);
      final foot = actor.y + (actor.behind ? -0.12 : 0);
      if (rect.inflate(slop).contains(local) && foot >= best) {
        best = foot;
        found = actor;
      }
    }
    return found;
  }

  bool hitR(Offset local, Size size) {
    final rect = letterRect(size);
    final slop = (rect.shortestSide * 0.08).clamp(8.0, 16.0);
    return rect.inflate(slop).contains(local);
  }

  bool attune() {
    if (attuneLeft > 0 || paused) return false;
    attuneLeft = 9;
    pullLeft = math.max(pullLeft, 3.2);
    rFlash = 1.3;
    bursts.add(Burst(frame: rActivateFrame, x: 0.5, y: 0.50, life: 0.65, width: 0.48));
    return true;
  }

  int _marksNeeded(String id) {
    switch (id) {
      case 'orbit':
      case 'stream':
        return 3;
      case 'current':
        return 2;
      default:
        return 1;
    }
  }

  String? get motionHint {
    switch (liveEvent) {
      case 'orbit':
        return 'Coins are circling R';
      case 'veiled':
        return 'A star is off to the side';
      case 'sevenfold':
        return 'Seven arrivals. The last one matters';
      case 'current':
        return 'Fruit is crossing in a line';
      case 'pull':
        return 'R is pulling the room inward';
      case 'stream':
        return 'Coins in a stream. Take three';
      case 'leaves':
        return 'A star is hiding in the plants';
    }
    switch (chainPhase) {
      case 1:
        return 'A fruit is drawn toward R';
      case 2:
        return 'R is waking';
      case 3:
        return 'A star just left R';
      default:
        return null;
    }
  }

  int flushWatch() {
    final whole = _watchRemainder.round();
    _watchRemainder = 0;
    return whole;
  }

  CollectResult collect(Actor actor) {
    if (!actors.remove(actor)) return CollectResult(actor.item, 0, false);
    final paid = payout(actor.item);
    sessionGleam += paid;
    switch (actor.item.kind) {
      case Kind.coin:
        sessionCoins += 1;
        noteCoinForChain();
      case Kind.fruit:
        sessionFruits += 1;
        if (actor.motion == Motion.homing && chainPhase == 1) _advanceChain();
      case Kind.star:
        sessionStars += 1;
      case Kind.seven:
        sessionSevens += 1;
    }
    final first = profile.takeFind(actor.item, paid);
    floaters.add(Floater('+$paid', actor.x, actor.y, _colorFor(actor.item.kind)));
    bursts.add(Burst(frame: pickupFrame, x: actor.x, y: actor.y, life: 0.42, width: 0.2));

    if (actor.key && actor.eventId != null) {
      final id = actor.eventId!;
      eventCaught += 1;
      final need = _marksNeeded(id);
      if (eventCaught >= need && !sessionEventNames.contains(albumById(id).name)) {
        _resolve(id);
      }
    }
    return CollectResult(actor.item, paid, first);
  }

  void _resolve(String id) {
    final spec = albumById(id);
    final bonus = (spec.bonus * valueMul).round();
    sessionGleam += bonus;
    sessionEvents += 1;
    sessionEventNames.add(spec.name);
    profile.gleam += bonus;
    profile.noteEvent(id);
    floaters.add(Floater('+$bonus', 0.50, 0.40, const Color(0xFFF0C14B)));
    eventCaught = 0;
    capture = Capture(id, bonus);
    if (id == 'chain') {
      chainPhase = 0;
      chainWait = 48;
    } else {
      _clearEventKeys();
      liveEvent = null;
      eventLeft = 0;
    }
    profile.save();
  }

  Color _colorFor(Kind kind) {
    switch (kind) {
      case Kind.coin:
        return const Color(0xFFF0C14B);
      case Kind.fruit:
        return const Color(0xFFFFB089);
      case Kind.star:
        return const Color(0xFFD2B6FF);
      case Kind.seven:
        return const Color(0xFFE7D2FF);
    }
  }

  SessionReport finish() {
    finished = true;
    profile.addWatch(flushWatch());
    profile.noteBest(sessionGleam);
    profile.noteVisit(room.id);
    profile.save();
    return SessionReport(
      roomId: room.id,
      roomName: room.name,
      coins: sessionCoins,
      fruits: sessionFruits,
      stars: sessionStars,
      sevens: sessionSevens,
      events: sessionEvents,
      gleam: sessionGleam,
      seconds: elapsed.round(),
      eventNames: List.of(sessionEventNames),
    );
  }
}

class CollectResult {
  CollectResult(this.item, this.paid, this.first);

  final ItemDef item;
  final int paid;
  final bool first;
}

Rect actorRectOf(Actor actor, Size size) {
  final width = switch (actor.item.kind) {
    Kind.coin => 0.10,
    Kind.fruit => 0.125,
    Kind.star => 0.115,
    Kind.seven => 0.11,
  };
  final bob = math.sin(actor.age * 2.1 + actor.phase) * 0.012;
  final pop = actor.age < 0.22 ? (actor.age / 0.22) : 1.0;
  final eased = 1 - math.pow(1 - pop, 3).toDouble();
  return place(size, actor.x, actor.y + bob, width * (0.35 + 0.65 * eased), actor.item.frame.aspect);
}
