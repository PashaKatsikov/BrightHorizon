import 'package:bright_horizon/src/catalog.dart';
import 'package:bright_horizon/src/observation.dart';
import 'package:bright_horizon/src/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Observation open() {
    return Observation(room: roomById('horizon'), profile: Profile());
  }

  test('objects show up and a tap pays gleam', () {
    final game = open();
    for (var i = 0; i < 80; i++) {
      game.tick(0.05);
    }
    expect(game.actors, isNotEmpty);
    final before = game.profile.gleam;
    final actor = game.actors.first;
    final result = game.collect(actor);
    expect(result.paid, greaterThan(0));
    expect(game.profile.gleam, before + result.paid);
    expect(game.sessionGleam, result.paid);
    expect(game.actors.contains(actor), isFalse);
    expect(game.collect(actor).paid, 0);
  });

  test('five coins start the chain', () {
    final game = open();
    game.chainWait = 0;
    var got = 0;
    for (var i = 0; i < 500 && got < 5; i++) {
      game.tick(0.05);
      final coin = game.actors.where((actor) => actor.item.kind == Kind.coin).firstOrNull;
      if (coin != null) {
        game.collect(coin);
        got += 1;
      } else if (game.actors.length >= game.cap - 1 && game.actors.isNotEmpty) {
        game.collect(game.actors.first);
      }
    }
    expect(got, 5);
    expect(game.chainPhase, 1);
    expect(game.actors.where((actor) => actor.motion == Motion.homing), isNotEmpty);
  });

  test('catching the marked object records the motion', () {
    final game = open();
    game.elapsed = 56;
    for (var i = 0; i < 400 && game.capture == null; i++) {
      game.tick(0.2);
      final marked = game.actors.where((actor) => actor.key).toList();
      for (final actor in marked) {
        if (game.capture != null) break;
        game.collect(actor);
      }
    }
    expect(game.capture, isNotNull);
    expect(game.profile.rareEvents, 1);
    expect(game.profile.albumCounts, isNotEmpty);
  });

  test('a missed chain star lets the room move on', () {
    final game = open();
    final star = Actor(
      id: 9,
      item: itemById('violet_star'),
      x: 0.5,
      y: 0.5,
      life: 0.05,
      motion: Motion.drift,
    );
    star.eventId = 'chain';
    star.key = true;
    game.actors.add(star);
    game.chainPhase = 3;
    game.tick(0.2);
    expect(game.chainPhase, 0);
    expect(game.chainWait, greaterThan(0));
  });

  test('finishing keeps the session numbers', () {
    final game = open();
    game.tick(1.3);
    final actor = game.actors.first;
    game.collect(actor);
    final report = game.finish();
    expect(report.gleam, game.sessionGleam);
    expect(report.roomName, 'Horizon Hall');
    expect(game.profile.visited, contains('horizon'));
    expect(game.profile.bestSession, report.gleam);
  });
}
