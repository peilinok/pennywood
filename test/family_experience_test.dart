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
import 'package:pennywood/features/panels.dart';
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

  testWidgets(
    'Closing nested finance preserves parent session and all parent destinations',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: paperTheme(Brightness.light), home: WishHome(c)),
      );
      await tester.tap(find.byKey(const Key('parent-entry')));
      await tester.runAsync(() => c.unlock('719385'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('家庭约定'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('管理收益预算、领取和预支'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('管理收益预算、领取和预支'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('close-panel')));
      await tester.pumpAndSettle();
      expect(c.parent, isNotNull);
      for (final label in ['待确认', '孩子与心愿', '家庭约定']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('unlock-parent')), findsNothing);
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(c.parent, isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'One family agreement serves both children without changing pending promises',
    () async {
      await c.unlock('719385');
      await c.perform('configureQuick', ['dishes', 200, '洗净餐具']);
      await c.perform('quickSubmit', ['dishes']);
      final original = c.account.tasks.single;
      await c.perform('configureQuick', ['dishes', 300, '洗净餐具并归位']);
      final other = await c.service.account(
        c.service.auth.child('real', 'second'),
      );
      expect(other.quickTasks.firstWhere((q) => q.id == 'dishes').amount, 300);
      expect(c.account.tasks.single.amount, original.amount);
      expect(c.account.tasks.single.detail, original.detail);
      expect(other.wallet, 0);
      expect(other.tasks, isEmpty);
    },
  );
  testWidgets(
    'Invalid product rates retain the form and values until a persisted correction',
    (tester) async {
      await tester.runAsync(() => c.unlock('719385'));
      await tester.pumpWidget(
        MaterialApp(
          theme: paperTheme(Brightness.light),
          home: Scaffold(body: TownPanel(c, 'parent')),
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('edit-product-rates')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-product-rates')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('book-field-0')), '11');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('book-continue')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('book-error')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('book-field-0')))
            .controller!
            .text,
        '11',
      );
      expect(c.account.rateFor('sprout'), 0);
      await tester.enterText(find.byKey(const Key('book-field-0')), '1');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('book-continue')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byType(BookForm), findsNothing);
      expect(c.account.rateFor('sprout'), 100);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Unapproved real-money market entry explains consent without opening a deposit form',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: paperTheme(Brightness.light),
          home: Scaffold(body: TownPanel(c, 'savings')),
        ),
      );
      final button = find.byKey(const Key('deposit-growth'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.text('请先和家长一起开启'), findsNWidgets(2));
      expect(c.account.wallet, 0);
      expect(c.account.positions, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
