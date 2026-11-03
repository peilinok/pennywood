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
    await c.unlock('719385');
    await c.perform('addTask', ['劳动报酬', 10000, '实际完成']);
    final task = c.account.tasks.single.id;
    for (final action in ['accept', 'submit', 'approve', 'pay']) {
      await c.perform(action, [task]);
    }
    await c.perform('settings', [10000, c.account.name]);
    await c.perform('familyRates', [1000, 500, 300]);
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
    await tester.pumpAndSettle();
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tap(tester, find.text('我的零钱'));
  }

  testWidgets(
    'Money withdrawal opens its form directly and preserves frozen assets',
    (tester) async {
      await mount(tester);
      await tap(tester, find.byKey(const Key('request-withdrawal')));
      await tester.enterText(find.byKey(const Key('book-field-0')), '20');
      await tester.enterText(find.byKey(const Key('book-field-1')), '购买文具');
      await tap(tester, find.byKey(const Key('book-continue')));
      expect(c.account.wallet, 8000);
      expect(c.account.pendingCash, 2000);
      expect(c.account.assets, 10000);
      expect(find.byKey(const Key('wallet-amount')), findsOneWidget);
      expect(find.text('待领取'), findsOneWidget);
      final stored = await tester.runAsync(() => db.load('real', 'first'));
      expect(stored!.pendingCash, 2000);
    },
  );

  testWidgets(
    'All five products remain grouped and a corrected deposit needs one amount confirmation',
    (tester) async {
      await mount(tester);
      await tap(tester, find.byKey(const Key('arrange-money')));
      expect(find.text('固定约定'), findsOneWidget);
      expect(find.text('会涨会跌'), findsOneWidget);
      for (final id in ['sprout', 'annual', 'dividend', 'lowVol', 'growth']) {
        expect(find.byKey(Key('deposit-$id')), findsOneWidget);
      }
      await tap(tester, find.byKey(const Key('deposit-sprout')));
      await tester.enterText(find.byKey(const Key('deposit-amount')), '1000');
      await tap(tester, find.byKey(const Key('confirm-deposit')));
      expect(find.byKey(const Key('deposit-error')), findsOneWidget);
      expect(c.account.active, isEmpty);
      await tester.enterText(find.byKey(const Key('deposit-amount')), '25');
      await tester.pumpAndSettle();
      expect(find.textContaining('本期预计收益 ¥0.62'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tap(tester, find.byKey(const Key('confirm-deposit')));
      expect(c.account.active.single.principal, 2500);
      expect(c.account.active.single.expected, 62);
      expect(c.account.wallet, 7500);
      expect(c.account.reserved, 62);
      expect(find.byKey(const Key('deposit-amount')), findsNothing);
    },
  );

  testWidgets(
    'Existing variable holdings remain directly redeemable after consent is revoked',
    (tester) async {
      await tester.runAsync(() async {
        await c.perform('marketPermission', [true]);
        await c.perform('buy', ['growth', 1000, 'cash']);
        await c.perform('marketPermission', [false]);
      });
      final id = c.account.active.single.id;
      await mount(tester);
      await tap(tester, find.byKey(Key('holding-$id')));
      await tap(tester, find.text('提前取回'));
      await tap(tester, find.byKey(const Key('confirm-action')));
      expect(c.account.active, isEmpty);
      expect(c.account.wallet, 10000);
      expect(c.account.reserved, 0);
      final other = await tester.runAsync(() => db.load('real', 'second'));
      expect(other!.assets, 0);
    },
  );
}
