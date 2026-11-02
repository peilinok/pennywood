import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pennywood/data/backup.dart';
import 'package:pennywood/features/wish_home.dart';
import 'package:pennywood/features/panels.dart';
import 'family_release_support.dart';
import 'experience_acceptance.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'Family release: real tasks, gift receipt, encrypted-file restore, and parent lock',
    (tester) async {
      final service = await startFamilyRelease(reset: true);
      Future<void> until(bool Function() condition) async {
        for (var i = 0; i < 200; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (condition()) return;
        }
        fail('Timed out waiting for family-release acceptance step');
      }

      Future<void> tap(Finder finder) async {
        await until(() => finder.evaluate().isNotEmpty);
        await tester.ensureVisible(finder);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(finder);
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> key(String name) => tap(find.byKey(Key(name)));
      Future<void> input(String name, String value) async {
        final finder = find.byKey(Key(name));
        await until(() => finder.evaluate().isNotEmpty);
        await tester.ensureVisible(finder);
        await tester.enterText(finder, value);
      }

      Future<void> hideKeyboard() async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 400));
      }

      final view = binding.platformDispatcher.views.first;
      final kind = view.physicalSize.shortestSide / view.devicePixelRatio > 600
          ? 'ipad'
          : 'iphone';
      Future<void> shot(String name) async {
        await tester.pump(const Duration(milliseconds: 500));
        await binding.takeScreenshot('$kind-wish-finance-$name');
      }

      await key('create-real');
      await input('first-name', '验收小栗');
      await input('second-name', '验收小桃');
      await input('setup-pin', '719385');
      await input('setup-pin-again', '719385');
      await hideKeyboard();
      await key('finish-setup');
      await until(() => find.byType(WishHome).evaluate().isNotEmpty);
      final c = tester.widget<WishHome>(find.byType(WishHome)).controller;
      expect(c.account.wallet, 0);
      await key('new-wish');
      await input('action-field-0', '望远镜');
      await input('action-field-1', '80');
      await hideKeyboard();
      await key('action-save');
      await until(() => c.account.mainWish != null);
      final wish = c.account.mainWish!.id;
      await key('parent-entry');
      await input('parent-pin', '719385');
      await hideKeyboard();
      await key('unlock-parent');
      await until(() => c.parent != null);
      await tap(find.text('家庭约定'));
      await key('configure-dishes');
      await input('action-field-0', '现实中洗净餐具并擦干水槽');
      await input('action-field-1', '32');
      await hideKeyboard();
      await key('action-save');
      await until(() => c.account.quickTasks.first.enabled);
      await key('parent-entry');
      await key('quick-dishes');
      await until(() => c.account.tasks.isNotEmpty);
      final task = c.account.tasks.single.id;
      expect(c.account.wallet, 0);
      await key('parent-entry');
      await input('parent-pin', '719385');
      await hideKeyboard();
      await key('unlock-parent');
      await until(() => c.parent != null);
      await key('review-$task');
      await key('approve-$task');
      await until(() => c.account.tasks.single.status == 'confirmed');
      expect(c.account.wallet, 0);
      await key('payment-delivered');
      await key('pay-$task');
      await until(() => c.account.wallet == 3200);
      await tap(find.text('返回'));
      await key('parent-entry');
      await shot('01-paid-accumulation');

      await tap(find.text('我的零钱'));
      await tap(find.text('预支与主动还款'));
      await tap(find.text('写一份预支提议'));
      for (final entry in ['望远镜', '48', '3', '2026-12-01'].asMap().entries) {
        await input('book-field-${entry.key}', entry.value);
      }
      await hideKeyboard();
      await key('payment-wish-$wish');
      await shot('02-advance-wish-association');
      await key('book-continue');
      await until(() => c.account.loans.length == 1);
      expect(c.account.loans.single.wishId, wish);
      await key('close-panel');
      await c.unlock('719385');
      final loan = c.account.loans.single.id;
      await c.perform('offerLoan', [loan, 3, '2026-12-01', 600]);
      await c.perform('acceptLoan', [loan]);
      await c.perform('fundLoan', [loan]);
      c.lock();
      for (final amount in ['20', '12']) {
        final beforeCount = c.account.requests.length;
        await tap(find.text('申请实际领取'));
        await tap(
          find.descendant(
            of: find.byType(TownPanel),
            matching: find.text('申请实际领取'),
          ),
        );
        await input('book-field-0', amount);
        await input('book-field-1', '望远镜自付 $amount 元');
        await hideKeyboard();
        await key('payment-wish-$wish');
        await key('book-continue');
        await until(() => c.account.requests.length == beforeCount + 1);
        expect(c.account.requests.last.wishId, wish);
        await key('close-panel');
        await c.unlock('719385');
        await c.perform('payRequest', [c.account.requests.last.id]);
        c.lock();
      }
      expect(c.account.wallet, 0);
      expect(c.account.debt, 4848);
      await tap(find.text('我的心愿'));
      expect(find.text('再攒 128.48 元，就更近一步。'), findsOneWidget);
      await shot('02b-debt-and-remaining-amount');
      await key('parent-entry');
      await input('parent-pin', '719385');
      await hideKeyboard();
      await key('unlock-parent');
      await until(() => c.parent != null);
      await tap(find.text('孩子与心愿'));
      await key('manage-main-wish');
      await key('receive-gift-$wish');
      for (final r in c.account.requests) {
        await key('gift-withdrawal-${r.id}');
      }
      await key('gift-loan-$loan');
      await key('gift-handed-over');
      await shot('03-combined-payments');
      await key('action-save');
      await until(() => c.account.wishes.single.receivedOn != null);
      expect(c.account.wishes.single.receivedCost, 8000);
      expect(c.account.withdrawn, 3200);
      expect(c.account.laborTotal, 3200);
      expect(c.account.debt, 4848);
      expect(
        c.account.requests.every((r) => r.wishId == wish && r.usedForGift),
        isTrue,
      );
      await shot('04-receipt-and-debt');
      await tap(find.text('返回'));

      final directory = await getApplicationSupportDirectory();
      final backups = FamilyBackup(service.db, service.auth);
      final archive = await backups.export(
        c.parent!,
        'Pennywood-verification-backup-2026',
      );
      final file = File(
        '${directory.path}/family-release-verification.pennywood',
      );
      await file.writeAsBytes(archive, flush: true);
      final verified = await backups.read(
        await file.readAsBytes(),
        'Pennywood-verification-backup-2026',
      );
      await c.perform('addWish', ['saving', '恢复前临时心愿', 10000]);
      await backups.restore(
        verified,
        access: c.parent,
        preserveBefore: (bytes) async {
          final before = File(
            '${directory.path}/family-release-before-verification.pennywood',
          );
          await before.writeAsBytes(bytes, flush: true);
          return before.path;
        },
      );
      c.lock();
      await c.load();
      expect(c.account.wishes.length, 1);
      expect(c.account.wallet, 0);
      expect(c.account.debt, 4848);
      expect((await service.db.load('real', 'second')).assets, 0);
      expect(await service.db.rows('PRAGMA foreign_key_check'), isEmpty);
      final p = await service.auth.unlock('real', 'first', '719385');
      final recovery = await service.auth.issueRecovery(p);
      await service.auth.changePin(p, '719385', '935172');
      await service.auth.recover('real', recovery, '719385');
      c.lock();
      await tester.pump(const Duration(milliseconds: 500));
      await input('parent-pin', '719385');
      await hideKeyboard();
      await key('unlock-parent');
      await until(() => c.parent != null);
      await tap(find.text('家庭约定'));
      await key('family-data');
      await shot('05-backup-and-parent-lock');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Schema5 upgrade, shared terms, real-money market loss, lessons, and encrypted restore',
    verifyExperience,
  );
}
