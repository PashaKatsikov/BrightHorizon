import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio.dart';
import 'catalog.dart';

class Profile extends ChangeNotifier {
  static const _key = 'horizon_save_v1';

  int gleam = 0;
  bool sfxOn = true;
  bool notifPrompted = false;
  bool coachSeen = false;
  final Set<String> unlocked = {'horizon'};
  final Set<String> visited = {};
  final Map<String, int> upgradeLevels = {};
  final Map<String, int> found = {};
  final Map<String, int> albumCounts = {};
  int objects = 0;
  int coins = 0;
  int fruits = 0;
  int stars = 0;
  int sevens = 0;
  int rareEvents = 0;
  int watchSeconds = 0;
  int bestSession = 0;
  String? rarestId;
  String lastRoom = 'horizon';

  int levelOf(String id) => upgradeLevels[id] ?? 0;

  int foundCount(String id) => found[id] ?? 0;

  bool owns(String roomId) => unlocked.contains(roomId);

  int get foundKinds => found.length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      Sfx.instance.enabled = sfxOn;
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      gleam = (map['gleam'] as num?)?.toInt() ?? 0;
      sfxOn = map['sfx'] as bool? ?? true;
      notifPrompted = map['notif'] as bool? ?? false;
      coachSeen = map['coach'] as bool? ?? false;
      unlocked
        ..clear()
        ..addAll((map['rooms'] as List?)?.cast<String>() ?? const ['horizon']);
      if (unlocked.isEmpty) unlocked.add('horizon');
      visited
        ..clear()
        ..addAll((map['visited'] as List?)?.cast<String>() ?? const []);
      upgradeLevels
        ..clear()
        ..addAll(_intMap(map['upgrades']));
      found
        ..clear()
        ..addAll(_intMap(map['found']));
      albumCounts
        ..clear()
        ..addAll(_intMap(map['album']));
      objects = (map['objects'] as num?)?.toInt() ?? 0;
      coins = (map['coins'] as num?)?.toInt() ?? 0;
      fruits = (map['fruits'] as num?)?.toInt() ?? 0;
      stars = (map['stars'] as num?)?.toInt() ?? 0;
      sevens = (map['sevens'] as num?)?.toInt() ?? 0;
      rareEvents = (map['events'] as num?)?.toInt() ?? 0;
      watchSeconds = (map['watch'] as num?)?.toInt() ?? 0;
      bestSession = (map['best'] as num?)?.toInt() ?? 0;
      rarestId = map['rarest'] as String?;
      lastRoom = map['lastRoom'] as String? ?? 'horizon';
    } catch (_) {
      unlocked.add('horizon');
    }
    Sfx.instance.enabled = sfxOn;
    notifyListeners();
  }

  Map<String, int> _intMap(Object? raw) {
    if (raw is! Map) return {};
    return raw.map((key, value) => MapEntry('$key', (value as num).toInt()));
  }

  Future<void>? _pendingSave;
  int _saveEpoch = 0;

  void save() {
    final epoch = ++_saveEpoch;
    final payload = jsonEncode({
      'gleam': gleam,
      'sfx': sfxOn,
      'notif': notifPrompted,
      'coach': coachSeen,
      'rooms': unlocked.toList(),
      'visited': visited.toList(),
      'upgrades': Map<String, int>.from(upgradeLevels),
      'found': Map<String, int>.from(found),
      'album': Map<String, int>.from(albumCounts),
      'objects': objects,
      'coins': coins,
      'fruits': fruits,
      'stars': stars,
      'sevens': sevens,
      'events': rareEvents,
      'watch': watchSeconds,
      'best': bestSession,
      'rarest': rarestId,
      'lastRoom': lastRoom,
    });
    final previous = _pendingSave ?? Future<void>.value();
    _pendingSave = previous.catchError((Object _) {}).then((_) => _commit(epoch, payload));
  }

  Future<void> _commit(int epoch, String payload) async {
    if (epoch != _saveEpoch) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (epoch != _saveEpoch) return;
      await prefs.setString(_key, payload).timeout(const Duration(seconds: 3));
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'profile', context: ErrorDescription('while saving')),
      );
    }
  }

  void setSfx(bool value) {
    sfxOn = value;
    Sfx.instance.enabled = value;
    notifyListeners();
    save();
  }

  void markNotified() {
    notifPrompted = true;
    notifyListeners();
    save();
  }

  void markCoach() {
    if (coachSeen) return;
    coachSeen = true;
    notifyListeners();
    save();
  }

  bool takeFind(ItemDef item, int paid) {
    final first = foundCount(item.id) == 0;
    gleam += paid;
    objects += 1;
    found[item.id] = foundCount(item.id) + 1;
    switch (item.kind) {
      case Kind.coin:
        coins += 1;
      case Kind.fruit:
        fruits += 1;
      case Kind.star:
        stars += 1;
      case Kind.seven:
        sevens += 1;
    }
    if (rarestId == null || item.rarity.index > itemById(rarestId!).rarity.index) {
      rarestId = item.id;
    }
    notifyListeners();
    save();
    return first;
  }

  void noteEvent(String id) {
    albumCounts[id] = (albumCounts[id] ?? 0) + 1;
    rareEvents += 1;
    notifyListeners();
    save();
  }

  void addWatch(int seconds) {
    if (seconds <= 0) return;
    watchSeconds += seconds;
  }

  void noteVisit(String roomId) {
    lastRoom = roomId;
    final added = visited.add(roomId);
    if (added) notifyListeners();
  }

  void noteBest(int sessionGleam) {
    if (sessionGleam > bestSession) bestSession = sessionGleam;
  }

  bool buyUpgrade(UpgradeDef upgrade) {
    final level = levelOf(upgrade.id);
    if (level >= upgrade.maxLevel) return false;
    final cost = upgrade.costs[level];
    if (gleam < cost) return false;
    gleam -= cost;
    upgradeLevels[upgrade.id] = level + 1;
    notifyListeners();
    save();
    return true;
  }

  bool buyRoom(Room room) {
    if (owns(room.id)) return false;
    final index = rooms.indexWhere((entry) => entry.id == room.id);
    if (index > 0 && !owns(rooms[index - 1].id)) return false;
    if (gleam < room.cost) return false;
    gleam -= room.cost;
    unlocked.add(room.id);
    notifyListeners();
    save();
    return true;
  }
}

class ProfileScope extends InheritedNotifier<Profile> {
  const ProfileScope({super.key, required Profile profile, required super.child})
    : super(notifier: profile);

  static Profile of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ProfileScope>();
    return scope!.notifier!;
  }

  static Profile read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ProfileScope>();
    return scope!.notifier!;
  }
}
