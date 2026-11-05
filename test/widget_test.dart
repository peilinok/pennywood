import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/money.dart';
import 'package:pennywood/app/controller.dart';
import 'package:pennywood/features/wish_home.dart';
import 'package:pennywood/main.dart';
import 'database_service_test.dart' show MemoryCredentials;

void main() {
  testWidgets(
    'Large growth projections may exceed the account cap without changing assets',
    (tester) async {
      final db = PennyDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final service = TownService(
        db,
        Auth(MemoryCredentials()),
        FixedClock('2026-11-01'),
      );
      final c = TownController(service, 'real', 'first');
      addTearDown(c.dispose);
      await tester.runAsync(() async {
        await service.createFamily('real', '719385', ['小满', '小禾']);
        await c.load();
      });
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      c.account.weeklyPlan = Money.maxCents;
      c.account.rateBps = 1000;
      await tester.pumpWidget(MaterialApp(home: WishHome(c)));
      await tester.tap(find.text('我的零钱'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('open-lesson')));
      await tester.tap(find.byKey(const Key('open-lesson')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lesson-projection')));
      await tester.pumpAndSettle();
      final checkbox = find.byType(CheckboxListTile);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(c.account.assets, 0);
      await tester.runAsync(() async {
        expect((await service.account(c.access)).assets, 0);
      });
    },
  );

  testWidgets(
    'First use starts at zero and retains an unfinished form through window changes',
    (tester) async {
      final db = PennyDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final service = TownService(
        db,
        Auth(MemoryCredentials()),
        FixedClock('2026-11-01'),
      );
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(PennywoodApp(service));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-real')));
      await tester.pumpAndSettle();
      expect(find.textContaining('建档后可在家长空间生成恢复码'), findsOneWidget);
      expect(find.textContaining('暂不支持找回'), findsNothing);
      await tester.enterText(find.byKey(const Key('first-name')), '小满');
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(find.text('小满'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(400, 700);
      await tester.pumpAndSettle();
      expect(find.text('小满'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(await db.rows('SELECT * FROM families'), isEmpty);
    },
  );
}
