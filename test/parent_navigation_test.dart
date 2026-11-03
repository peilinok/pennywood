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
    final svc = TownService(
      db,
      Auth(MemoryCredentials()),
      FixedClock('2026-11-03'),
    );
    await svc.createFamily('real', '719385', ['小满', '小禾']);
    c = TownController(svc, 'real', 'first');
    await c.load();
    await c.unlock('719385');
    await c.perform('addTask', ['整理书桌', 5000, '分类收好']);
    final id = c.account.tasks.single.id;
    for (final action in ['accept', 'submit', 'approve', 'pay']) {
      await c.perform(action, [id]);
    }
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: paperTheme(Brightness.light), home: WishHome(c)),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tap(tester, find.byKey(const Key('parent-entry')));
    await tester.runAsync(() => c.unlock('719385'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Parent inbox directly delivers money and excludes child-waiting offers from actionable count',
    (tester) async {
      await tester.runAsync(() async {
        await c.perform('request', [1000, '买文具', '']);
        await c.perform('loanRequest', ['望远镜', 2000, 3, '2026-12-03', '']);
        final id = c.account.loans.single.id;
        await c.perform('offerLoan', [id, 3, '2026-12-03', 0]);
      });
      final request = c.account.requests.single.id;
      await mount(tester);
      expect(find.text('1 件待办'), findsOneWidget);
      expect(find.text('等待孩子阅读并接受'), findsOneWidget);
      expect(find.text('管理领取、预支和收益预算'), findsNothing);
      await tap(tester, find.byKey(Key('deliver-$request')));
      expect(c.account.pendingCash, 1000);
      await tap(tester, find.byKey(const Key('confirm-action')));
      expect(c.account.pendingCash, 0);
      expect(c.account.withdrawn, 1000);
      expect(c.account.assets, 4000);
      expect(c.parent, isNotNull);
      expect(find.text('0 件待办'), findsOneWidget);
      expect(
        (await tester.runAsync(() => db.load('real', 'second')))!.assets,
        0,
      );
    },
  );
  testWidgets(
    'Child budget and profile are separate forms and shared rates stay in Family',
    (tester) async {
      await mount(tester);
      await tap(tester, find.text('孩子'));
      await tap(tester, find.byKey(const Key('edit-child-budget')));
      expect(find.byKey(const Key('book-field-1')), findsNothing);
      await tester.enterText(find.byKey(const Key('book-field-0')), '40');
      await tap(tester, find.byKey(const Key('book-continue')));
      expect(c.account.budget, 4000);
      expect(c.account.name, '小满');
      expect(c.parent, isNotNull);
      await tap(tester, find.byKey(const Key('edit-child-name')));
      await tester.enterText(find.byKey(const Key('book-field-0')), '满满');
      await tap(tester, find.byKey(const Key('book-continue')));
      expect(c.account.budget, 4000);
      expect(c.account.name, '满满');
      final other = await tester.runAsync(() => db.load('real', 'second'));
      expect(other!.budget, 0);
      expect(other.name, '小禾');
      expect(find.byKey(const Key('edit-product-rates')), findsNothing);
      expect(find.byKey(const Key('profiles')), findsOneWidget);
      expect(find.text('选择另一个孩子'), findsNothing);
      await tap(tester, find.text('家庭'));
      expect(find.byKey(const Key('edit-product-rates')), findsOneWidget);
      expect(find.byKey(const Key('edit-child-budget')), findsNothing);
      expect(find.byKey(const Key('family-data')), findsOneWidget);
    },
  );
}
