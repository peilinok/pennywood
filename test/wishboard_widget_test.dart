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
      FixedClock('2026-11-01'),
    );
    await svc.createFamily('real', '719385', ['小满', '小禾']);
    c = TownController(svc, 'real', 'first');
    await c.load();
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  testWidgets(
    'Wish validation retains input and saves after narrow-window reflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1194, 834);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: paperTheme(Brightness.light), home: WishHome(c)),
      );
      await tester.tap(find.byKey(const Key('new-wish')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('action-field-0')), '我的望远镜');
      await tester.enterText(find.byKey(const Key('action-field-1')), '0');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('action-save')));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('form-error')), findsOneWidget);
      expect(find.text('我的望远镜'), findsOneWidget);
      tester.view.physicalSize = const Size(375, 700);
      await tester.pumpAndSettle();
      expect(find.text('我的望远镜'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byKey(const Key('action-field-1')), '80');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('action-save')));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(c.account.mainWish!.target, 8000);
      expect(c.account.wallet, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Payment is enabled only after actual-delivery confirmation; checking does not post income',
    (tester) async {
      await tester.runAsync(() async {
        final p = await c.service.auth.unlock('real', 'first', '719385');
        await c.service.execute(p, 'config', 'configureQuick', [
          'dishes',
          200,
          '洗净餐具',
        ]);
        final id = await c.service.execute(c.access, 'submit', 'quickSubmit', [
          'dishes',
        ]);
        await c.service.execute(p, 'check', 'approve', [id]);
        await c.refresh();
        c.parent = p;
      });
      final id = c.account.tasks.single.id;
      await tester.pumpWidget(
        MaterialApp(
          theme: paperTheme(Brightness.light),
          home: Scaffold(body: TaskReview(c, id)),
        ),
      );
      await tester.pumpAndSettle();
      FilledButton pay() =>
          tester.widget<FilledButton>(find.byKey(Key('pay-$id')));
      expect(pay().onPressed, isNull);
      expect(c.account.wallet, 0);
      await tester.tap(find.byKey(const Key('payment-delivered')));
      await tester.pumpAndSettle();
      expect(pay().onPressed, isNotNull);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(Key('pay-$id')));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(c.account.wallet, 200);
      expect(find.byKey(Key('pay-$id')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Foreground date refresh allows a new submission after yesterday was paid',
    (tester) async {
      await tester.runAsync(() async {
        final p = await c.service.auth.unlock('real', 'first', '719385');
        await c.service.execute(p, 'config', 'configureQuick', [
          'dishes',
          200,
          '洗净餐具',
        ]);
        final id = await c.service.execute(
          c.access,
          'yesterday',
          'quickSubmit',
          ['dishes'],
        );
        await c.service.execute(p, 'check', 'approve', [id]);
        await c.service.execute(p, 'pay', 'pay', [id]);
        await c.refresh();
        (c.service.clock as FixedClock).advance(1);
      });
      await tester.pumpWidget(
        MaterialApp(theme: paperTheme(Brightness.light), home: WishHome(c)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的任务'));
      await tester.pumpAndSettle();
      final task = find.byKey(const Key('quick-dishes'));
      await tester.ensureVisible(task);
      // Sliver hit coordinates update after layout on the next frame.
      await tester.pumpAndSettle();
      expect(task.hitTestable(), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(task);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(c.account.tasks.length, 2);
      expect(c.account.tasks.last.businessDay, '2026-11-02');
      expect(c.account.tasks.last.status, 'submitted');
      expect(c.account.wallet, 200);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'All six wish pages avoid overflow across windows, themes, and large text',
    (tester) async {
      await tester.runAsync(() async {
        await c.perform('addWish', ['gift', '我的第一台望远镜', 8000]);
      });
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final brightness in Brightness.values) {
        for (final size in [
          const Size(1194, 834),
          const Size(834, 1210),
          const Size(844, 390),
          const Size(375, 812),
          const Size(400, 700),
        ]) {
          for (final scale in [1.0, 2.0]) {
            tester.view.physicalSize = size;
            await tester.pumpWidget(
              MaterialApp(
                theme: paperTheme(brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: WishHome(c),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$size $brightness $scale wish page',
            );
            for (final label in ['我的任务', '我的零钱']) {
              await tester.tap(find.text(label));
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '$size $brightness $scale $label',
              );
            }
            await tester.tap(find.byKey(const Key('parent-entry')));
            await tester.runAsync(() => c.unlock('719385'));
            await tester.pumpAndSettle();
            for (final label in ['待确认', '孩子与心愿', '家庭约定']) {
              await tester.tap(find.text(label));
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '$size $brightness $scale $label',
              );
            }
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    },
  );

  testWidgets(
    'Repeated rotation and resizing retain child, cash page, and unfinished wish',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.runAsync(() async {
        final p = await c.service.auth.unlock('real', 'first', '719385');
        await c.service.execute(p, 'config', 'configureQuick', [
          'dishes',
          200,
          '洗净餐具',
        ]);
        final id = await c.service.execute(c.access, 'submit', 'quickSubmit', [
          'dishes',
        ]);
        await c.service.execute(p, 'check', 'approve', [id]);
        await c.service.execute(p, 'pay', 'pay', [id]);
        await c.refresh();
      });
      await tester.pumpWidget(
        MaterialApp(theme: paperTheme(Brightness.light), home: WishHome(c)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的零钱'));
      await tester.pumpAndSettle();
      for (final size in [
        const Size(874, 402),
        const Size(834, 1194),
        const Size(1194, 834),
        const Size(400, 700),
        const Size(402, 874),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(find.text('我的每一分，都有来处'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('wallet-amount'))).data,
          '¥2.00',
        );
        expect(c.child, 'first');
        expect(c.account.ledger.where((l) => l.kind == 'income').length, 1);
        expect(tester.takeException(), isNull, reason: '$size cash page');
      }
      await tester.tap(find.text('我的心愿'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('new-wish')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('攒钱目标'));
      await tester.enterText(find.byKey(const Key('action-field-0')), '暑假的小目标');
      await tester.enterText(find.byKey(const Key('action-field-1')), '120');
      for (final size in [
        const Size(874, 402),
        const Size(1194, 834),
        const Size(400, 700),
        const Size(402, 874),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(find.text('暑假的小目标'), findsOneWidget);
        expect(find.text('120'), findsOneWidget);
        expect(
          tester
              .widget<SegmentedButton<String>>(
                find.byType(SegmentedButton<String>),
              )
              .selected,
          {'saving'},
        );
        expect(c.account.wishes, isEmpty);
        expect(c.account.wallet, 200);
        expect(tester.takeException(), isNull, reason: '$size unfinished form');
      }
      // A landscape phone keyboard takes most height; save/back must remain tappable.
      tester.view.physicalSize = const Size(874, 402);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'landscape software keyboard',
      );
      expect(
        find.byKey(const Key('action-save')).hitTestable(),
        findsOneWidget,
      );
      tester.view.physicalSize = const Size(402, 874);
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      await tester.pumpAndSettle();
      expect(find.text('暑假的小目标'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'portrait software keyboard',
      );
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();
      expect(c.account.wishes, isEmpty);
      expect(c.account.wallet, 200);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
