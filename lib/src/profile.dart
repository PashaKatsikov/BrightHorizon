import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'slot/engine.dart';

class Profile extends ChangeNotifier {
  static const _key = 'horizon_cabinet_v1';
  static const openingCredits = 5000;
  static const giftCredits = 2500;
  static const giftGap = Duration(hours: 4);

  int credits = openingCredits;
  int stake = stakes.first;
  int spins = 0;
  int totalWon = 0;
  int biggestWin = 0;
  DateTime giftAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool notifPrompted = false;

  bool get giftReady => !DateTime.now().isBefore(giftAt);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      credits = (map['credits'] as num?)?.toInt() ?? openingCredits;
      final savedStake = (map['stake'] as num?)?.toInt() ?? stakes.first;
      stake = stakes.contains(savedStake) ? savedStake : stakes.first;
      spins = (map['spins'] as num?)?.toInt() ?? 0;
      totalWon = (map['won'] as num?)?.toInt() ?? 0;
      biggestWin = (map['best'] as num?)?.toInt() ?? 0;
      giftAt = DateTime.fromMillisecondsSinceEpoch((map['gift'] as num?)?.toInt() ?? 0);
      notifPrompted = map['notif'] as bool? ?? false;
      if (credits < 0) credits = 0;
    } catch (_) {
      credits = openingCredits;
    }
    notifyListeners();
  }

  Future<void>? _pendingSave;
  int _saveEpoch = 0;

  void save() {
    final epoch = ++_saveEpoch;
    final payload = jsonEncode({
      'credits': credits,
      'stake': stake,
      'spins': spins,
      'won': totalWon,
      'best': biggestWin,
      'gift': giftAt.millisecondsSinceEpoch,
      'notif': notifPrompted,
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
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'profile',
          context: ErrorDescription('while saving'),
        ),
      );
    }
  }

  void setStake(int value) {
    if (!stakes.contains(value) || value == stake) return;
    stake = value;
    notifyListeners();
    save();
  }

  /// Returns false when the stake cannot be covered.
  bool spend(int amount) {
    if (amount < 0 || credits < amount) return false;
    credits -= amount;
    spins += 1;
    notifyListeners();
    save();
    return true;
  }

  void award(int amount) {
    if (amount <= 0) return;
    credits += amount;
    totalWon += amount;
    if (amount > biggestWin) biggestWin = amount;
    notifyListeners();
    save();
  }

  void grant(int amount) {
    if (amount <= 0) return;
    credits += amount;
    notifyListeners();
    save();
  }

  bool claimGift() {
    if (!giftReady) return false;
    credits += giftCredits;
    giftAt = DateTime.now().add(giftGap);
    notifyListeners();
    save();
    return true;
  }

  void markNotified() {
    notifPrompted = true;
    notifyListeners();
    save();
  }
}

class ProfileScope extends InheritedNotifier<Profile> {
  const ProfileScope({super.key, required Profile profile, required super.child}) : super(notifier: profile);

  static Profile of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ProfileScope>();
    return scope!.notifier!;
  }

  static Profile read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ProfileScope>();
    return scope!.notifier!;
  }
}
