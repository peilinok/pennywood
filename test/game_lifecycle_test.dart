import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/domain/model.dart';
import 'package:pennywood/game/navigation.dart';
import 'package:pennywood/game/town_game.dart';

void main() {
  test(
    'Reduced motion disables bobbing while retaining walking, arrival saves, and entry',
    () async {
      var saved = 0;
      final entered = <String>[];
      final scene = SceneState();
      final game = TownGame(
        scene,
        onEnter: (place) async => entered.add(place),
        onSave: () async => saved++,
      );
      game.assetsReady = true;
      game.update(.02);
      expect(game.phase, greaterThan(0));
      game.reduceMotion = true;
      game.path = [const Point2(401, 380)];
      game.destination = 'tasks';
      game.update(.02);
      await Future<void>.delayed(Duration.zero);
      expect(game.phase, 0);
      expect(scene.x, 401);
      expect(saved, 1);
      expect(entered, ['tasks']);
      game.reduceMotion = false;
      game.update(.02);
      expect(game.phase, greaterThan(0));
    },
  );

  test(
    'Arrival save failure prevents entry and footprints without leaking async errors',
    () async {
      final uncaught = <Object>[];
      final entered = <String>[];
      final scene = SceneState();
      await runZonedGuarded(() async {
        final game = TownGame(
          scene,
          onEnter: (p) async => entered.add(p),
          onSave: () async => throw StateError('模拟磁盘写入失败'),
        );
        game.assetsReady = true;
        game.path = [const Point2(400, 380)];
        game.destination = 'tasks';
        game.update(.016);
        await Future<void>.delayed(Duration.zero);
      }, (error, _) => uncaught.add(error));
      expect(entered, isEmpty);
      expect(uncaught, isEmpty);
      expect(scene.visited, isEmpty);
    },
  );

  test(
    'Changing destination during an arrival save cancels the previous building callback',
    () async {
      final save = Completer<void>();
      final entered = <String>[];
      final game = TownGame(
        SceneState(),
        onEnter: (p) async {
          entered.add(p);
        },
        onSave: () => save.future,
      );
      game.map = TownMap(
        jsonDecode(File('assets/scene-layout.json').readAsStringSync()),
      );
      game.assetsReady = true;
      game.path = [const Point2(400, 380)];
      game.destination = 'tasks';
      game.update(.016);
      game.walk(const Point2(360, 400));
      save.complete();
      await Future<void>.delayed(Duration.zero);
      expect(entered, isEmpty);
    },
  );
}
