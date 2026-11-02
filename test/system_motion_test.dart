import 'package:drift/native.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/app/controller.dart';
import 'package:pennywood/app/paper_theme.dart';
import 'package:pennywood/app/screens.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/money.dart';
import 'package:pennywood/game/town_game.dart';
import 'database_service_test.dart' show MemoryCredentials;

void main() {
  late PennyDatabase db;
  late TownController c;
  setUp(() async {
    db = PennyDatabase(NativeDatabase.memory());
    final service = TownService(
      db,
      Auth(MemoryCredentials()),
      FixedClock('2026-11-01'),
    );
    await service.createFamily('real', '719385', ['小满', '小禾']);
    c = TownController(service, 'real', 'first');
    await c.load();
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<void> inTown(
    WidgetTester tester,
    FakeAccessibilityFeatures features,
    Future<void> Function(TownGame) verify, {
    Size size = const Size(1194, 390),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final dispatcher = tester.binding.platformDispatcher;
    dispatcher.accessibilityFeaturesTestValue = features;
    try {
      await tester.pumpWidget(
        MaterialApp(theme: paperTheme(Brightness.light), home: TownHome(c)),
      );
      expect(tester.takeException(), isNull);
      final game =
          tester
                  .widget<GameWidget>(
                    find.byWidgetPredicate((w) => w is GameWidget),
                  )
                  .game
              as TownGame;
      // This widget regression covers system-event wiring and state retention; simulators verify asset loading and walking.
      game.pauseEngine();
      try {
        await verify(game);
      } finally {
        game.pauseEngine();
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      dispatcher.clearAccessibilityFeaturesTestValue();
    }
  }

  testWidgets(
    'Zero-setup families enter a wide town without legacy demo tasks',
    (tester) async {
      await inTown(tester, const FakeAccessibilityFeatures(), (game) async {
        expect(find.text('先和家长约好一份现实任务'), findsOneWidget);
        expect(c.account.tasks, isEmpty);
        expect(c.account.wallet, 0);
        expect(c.account.ledger, isEmpty);
      }, size: const Size(1194, 834));
    },
  );

  for (final feature in [
    'iOS Reduce Motion',
    'framework disabled animations',
  ]) {
    testWidgets(
      'Initial town entry respects $feature without changing the zero ledger',
      (tester) async {
        await inTown(
          tester,
          FakeAccessibilityFeatures(
            reduceMotion: feature == 'iOS Reduce Motion',
            disableAnimations: feature == 'framework disabled animations',
          ),
          (game) async {
            expect(game.reduceMotion, isTrue);
            expect(c.account.wallet, 0);
            expect(c.account.ledger, isEmpty);
          },
        );
      },
    );
  }

  testWidgets(
    'Changing iOS Reduce Motion retains the game instance, position, and ledger',
    (tester) async {
      await inTown(tester, const FakeAccessibilityFeatures(), (game) async {
        final position = (c.scene.x, c.scene.y);
        expect(game.reduceMotion, isFalse);
        for (final enabled in [true, false]) {
          tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(reduceMotion: enabled);
          await tester.pump();
          expect(game.reduceMotion, enabled);
          expect(
            tester
                .widget<GameWidget>(
                  find.byWidgetPredicate((w) => w is GameWidget),
                )
                .game,
            same(game),
          );
          expect((c.scene.x, c.scene.y), position);
          expect(c.account.wallet, 0);
          expect(c.account.ledger, isEmpty);
        }
      });
    },
  );
}
