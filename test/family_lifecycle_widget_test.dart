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
    final svc = TownService(
      db,
      Auth(MemoryCredentials()),
      FixedClock('2026-11-01'),
    );
    await svc.createFamily('real', '719385', ['小满', '小禾']);
    c = TownController(svc, 'real', 'first');
    await c.load();
    await c.perform('addWish', ['gift', '望远镜', 3200]);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  Future<void> settleAction(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
  }

  test(
    'Parent wish edits through the shared entry record the correct ledger role',
    () async {
      final wish = c.account.wishes.single.id;
      expect(c.account.ledger.last.actorRole, 'child');
      await c.unlock('719385');
      await c.perform('editWish', [wish, 'gift', '和家长商量后的望远镜', 4000]);
      expect(c.account.ledger.last.actorRole, 'parent');
    },
  );

  testWidgets('Wish gap includes debt that exceeds current assets', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final wish = c.account.wishes.single.id;
      await c.perform('editWish', [wish, 'gift', '望远镜', 8000]);
      await c.perform('loanRequest', ['望远镜', 4800, 3, '2026-12-01', wish]);
      final loan = c.account.loans.single.id;
      await c.unlock('719385');
      await c.perform('offerLoan', [loan, 3, '2026-12-01', 600]);
      await c.perform('acceptLoan', [loan]);
      await c.perform('fundLoan', [loan]);
    });
    expect(c.account.conservative, -4848);
    await tester.pumpWidget(
      MaterialApp(theme: paperTheme(Brightness.light), home: WishHome(c)),
    );
    expect(find.text('再攒 128.48 元，就更近一步。'), findsOneWidget);
    expect(c.account.debt, 4848);
    expect(c.account.wallet, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Inactive tasks appear in history without being mislabeled as paid',
    (tester) async {
      await tester.runAsync(() async {
        final p = await c.service.auth.unlock('real', 'first', '719385');
        final id = await c.service.execute(p, 'unused', 'addTask', [
          '暂停的任务',
          200,
          '尚未接下',
        ]);
        await c.service.execute(p, 'cancel', 'cancelTask', [id]);
        await c.refresh();
      });
      await tester.pumpWidget(
        MaterialApp(theme: paperTheme(Brightness.light), home: WishHome(c)),
      );
      await tester.tap(find.text('我的任务'));
      await tester.pumpAndSettle();
      final history = find.widgetWithText(ChoiceChip, '历史记录');
      expect(history, findsOneWidget);
      await tester.ensureVisible(history);
      await tester.tap(history);
      await tester.pumpAndSettle();
      expect(find.text('已停用'), findsOneWidget);
      expect(c.account.wallet, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Wish management edits and archives retain cash and completed history in narrow layouts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: paperTheme(Brightness.light), home: WishHome(c)),
      );
      await tester.tap(find.byKey(const Key('manage-main-wish')));
      await tester.pumpAndSettle();
      final id = c.account.mainWish!.id;
      await tester.tap(find.byKey(Key('edit-wish-$id')));
      await tester.pumpAndSettle();
      expect(find.text('望远镜'), findsWidgets);
      await tester.enterText(
        find.byKey(const Key('action-field-0')),
        '看月亮的望远镜',
      );
      await tester.enterText(find.byKey(const Key('action-field-1')), '40');
      tester.view.physicalSize = const Size(812, 375);
      await tester.pumpAndSettle();
      await settleAction(tester, find.byKey(const Key('action-save')));
      expect(c.account.mainWish!.name, '看月亮的望远镜');
      expect(c.account.goal, 4000);
      await tester.ensureVisible(find.byKey(const Key('manage-main-wish')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('manage-main-wish')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('manage-main-wish')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('归档'));
      await tester.tap(find.text('归档'));
      await tester.pumpAndSettle();
      await settleAction(tester, find.byKey(const Key('confirm-archiveWish')));
      expect(c.account.mainWish, isNull);
      expect(c.account.wishes.single.status, 'archived');
      expect(c.account.wallet, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'Withdrawal errors retain wish association and input through reflow and large text-$brightness',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(375, 812);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          await c.unlock('719385');
          final id = await c.service.execute(c.parent!, 'earn', 'addTask', [
            '劳动',
            2000,
            '约好完成',
          ]);
          for (final a in ['accept', 'submit', 'approve', 'pay']) {
            await c.perform(a, [id]);
          }
          c.lock();
          await c.refresh();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: paperTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => TownPanel(c, 'journal'),
                  ),
                  child: const Text('打开零钱'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开零钱'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('申请实际领取'));
        await tester.tap(find.text('申请实际领取'));
        await tester.pumpAndSettle();
        final wish = c.account.wishes.single.id;
        await tester.enterText(find.byKey(const Key('book-field-0')), '30');
        await tester.ensureVisible(find.byKey(Key('payment-wish-$wish')));
        await tester.tap(find.byKey(Key('payment-wish-$wish')));
        await tester.pumpAndSettle();
        await settleAction(tester, find.byKey(const Key('book-continue')));
        expect(find.byKey(const Key('book-error')), findsOneWidget);
        expect(c.account.requests, isEmpty);
        tester.view.physicalSize = const Size(812, 375);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
              .groupValue,
          wish,
        );
        final amount = find.byKey(const Key('book-field-0'));
        await tester.ensureVisible(amount);
        expect(tester.widget<TextFormField>(amount).controller!.text, '30');
        await tester.enterText(amount, '20');
        await settleAction(tester, find.byKey(const Key('book-continue')));
        expect(c.account.requests.single.wishId, wish);
        expect(c.account.requests.single.amount, 2000);
        expect(c.account.wallet, 0);
        expect(c.account.pendingCash, 2000);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Gift receipt requires actual delivery and retains payment selection through reflow',
    (tester) async {
      await tester.runAsync(() async {
        await c.unlock('719385');
        final task = await c.service.execute(c.parent!, 'task', 'addTask', [
          '劳动',
          3200,
          '约定完成',
        ]);
        await c.service.execute(c.access, 'accept', 'accept', [task]);
        await c.service.execute(c.access, 'submit', 'submit', [task]);
        await c.service.execute(c.parent!, 'approve', 'approve', [task]);
        await c.service.execute(c.parent!, 'pay', 'pay', [task]);
        final request = await c.service.execute(
          c.access,
          'request',
          'request',
          [3200, '望远镜自付'],
        );
        await c.service.execute(c.parent!, 'handover', 'payRequest', [request]);
        await c.refresh();
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: paperTheme(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => GiftReceipt(c, c.account.wishes.single),
                ),
                child: const Text('登记'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('登记'));
      await tester.pumpAndSettle();
      await settleAction(tester, find.byKey(const Key('action-save')));
      expect(find.byKey(const Key('form-error')), findsOneWidget);
      final receipt = find.byKey(
        Key('gift-withdrawal-${c.account.requests.single.id}'),
      );
      await tester.ensureVisible(receipt);
      await tester.tap(receipt);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(812, 375);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('gift-handed-over')));
      await tester.tap(find.byKey(const Key('gift-handed-over')));
      await tester.pumpAndSettle();
      await settleAction(tester, find.byKey(const Key('action-save')));
      expect(c.account.wishes.single.receivedCost, 3200);
      expect(c.account.wishes.single.receivedOn, '2026-11-01');
      expect(c.account.wallet, 0);
      expect(c.account.withdrawn, 3200);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
