import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/app/controller.dart';
import 'package:pennywood/app/paper_theme.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/money.dart';
import 'package:pennywood/features/wish_home.dart';
import 'database_service_test.dart' show MemoryCredentials;

void main() {
  late PennyDatabase db;
  late TownController c;
  setUp(() async {
    db = PennyDatabase(NativeDatabase.memory());
    final service = TownService(
      db,
      Auth(MemoryCredentials()),
      FixedClock('2026-11-03'),
    );
    await service.createFamily('real', '719385', ['小满', '小禾']);
    c = TownController(service, 'real', 'first');
    await c.load();
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: paperTheme(Brightness.light), home: WishHome(c)),
    );
    await tester.pumpAndSettle();
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  Future<void> action(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Only tasks exposes the full task area, retaining paused pending promises',
    (tester) async {
      await tester.runAsync(() async {
        await c.unlock('719385');
        await c.perform('configureQuick', ['dishes', 200, '洗净并归位']);
        await c.perform('quickSubmit', ['dishes']);
        await c.perform('setQuickEnabled', ['dishes', false]);
        (c.service.clock as FixedClock).advance(1);
        await c.resume();
      });
      await mount(tester);
      expect(find.byKey(const Key('quick-dishes')), findsNothing);
      expect(find.text('查看任务 ›'), findsNothing);
      expect(find.text('现实劳动与小任务'), findsNothing);
      expect(find.text('和家长聊聊预支'), findsNothing);
      await action(tester, find.text('我的任务'));
      expect(find.byKey(const Key('quick-dishes')), findsOneWidget);
      expect(find.byKey(const Key('quick-mop')), findsNothing);
      await action(tester, find.byKey(const Key('quick-dishes')));
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('洗净并归位'),
        ),
        findsOneWidget,
      );
      await action(
        tester,
        find.byKey(Key('withdraw-${c.account.tasks.single.id}')),
      );
      expect(c.account.tasks.single.status, 'available');
      expect(c.account.wallet, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Temporary task submission acts on its card without crediting income',
    (tester) async {
      await tester.runAsync(() async {
        await c.unlock('719385');
        await c.perform('addTask', ['整理书架', 300, '按类别归位']);
      });
      final id = c.account.tasks.single.id;
      await mount(tester);
      await action(tester, find.text('我的任务'));
      await action(tester, find.byKey(Key('accept-$id')));
      await action(tester, find.byKey(Key('submit-$id')));
      expect(c.account.tasks.single.status, 'submitted');
      expect(c.account.wallet, 0);
      expect(find.text('等待家长检查'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Task scroll survives tab visits and window reflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await c.unlock('719385');
      for (var i = 0; i < 16; i++) {
        await c.perform('addTask', ['任务 $i', 100, '原约定标准']);
      }
    });
    await mount(tester);
    await action(tester, find.text('我的任务'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -650));
    await tester.pumpAndSettle();
    double offset() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    final before = offset();
    expect(before, greaterThan(0));
    await action(tester, find.text('我的零钱'));
    await action(tester, find.text('我的任务'));
    expect(offset(), closeTo(before, 1));
    tester.view.physicalSize = const Size(1194, 834);
    await tester.pumpAndSettle();
    expect(offset(), closeTo(before, 1));
    expect(c.account.tasks.length, 16);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'One concrete feedback hint leads to rework without adding income',
    (tester) async {
      await tester.runAsync(() async {
        await c.unlock('719385');
        await c.perform('configureQuick', ['dishes', 200, '洗净餐具']);
        await c.perform('quickSubmit', ['dishes']);
        await c.perform('requestChanges', [c.account.tasks.single.id, '水槽再擦干']);
      });
      await mount(tester);
      expect(find.text('家长给了你一条小提醒'), findsOneWidget);
      await action(tester, find.text('家长给了你一条小提醒'));
      expect(find.text('家长的小提醒：水槽再擦干'), findsOneWidget);
      await action(
        tester,
        find.byKey(Key('submit-${c.account.tasks.single.id}')),
      );
      expect(c.account.tasks.single.status, 'submitted');
      expect(c.account.wallet, 0);
      expect(find.text('家长给了你一条小提醒'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
