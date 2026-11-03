import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pennywood/app/screens.dart';
import 'package:pennywood/domain/money.dart';
import 'package:pennywood/game/town_game.dart';
import 'package:pennywood/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'Isolated demo: deposits, both dividends, advance installments, withdrawals, and growth',
    (tester) async {
      await app.main();
      Future<void> until(bool Function() condition) async {
        for (var i = 0; i < 200; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (condition()) return;
        }
        fail('Timed out waiting for business state or UI');
      }

      Future<void> tap(Finder finder) async {
        await until(() => finder.evaluate().isNotEmpty);
        await tester.ensureVisible(finder);
        await Future<void>.delayed(const Duration(milliseconds: 350));
        await tester.tap(finder);
        await tester.pump();
      }

      Future<void> key(String name) => tap(find.byKey(Key(name)));
      Future<void> text(String label) => tap(find.text(label));
      Future<void> input(String name, String value) async {
        final finder = find.byKey(Key(name));
        await until(() => finder.evaluate().isNotEmpty);
        await tester.ensureVisible(finder);
        await tester.enterText(finder, value);
        await tester.pump();
      }

      Future<void> book(List<String> fields) async {
        for (var i = 0; i < fields.length; i++) {
          await input('book-field-$i', fields[i]);
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await key('book-continue');
      }

      await text('先体验独立示例家庭');
      await input('first-name', '示例栗栗');
      await input('second-name', '示例果果');
      await input('setup-pin', '719385');
      await input('setup-pin-again', '719385');
      FocusManager.instance.primaryFocus?.unfocus();
      await key('finish-setup');
      await until(() => find.byType(TownHome).evaluate().isNotEmpty);
      final c = tester.widget<TownHome>(find.byType(TownHome)).controller;
      await until(() => c.ready);
      expect(c.account.wallet, 20000);
      final kind =
          binding.platformDispatcher.views.first.physicalSize.shortestSide /
                  binding.platformDispatcher.views.first.devicePixelRatio >
              600
          ? 'ipad'
          : 'iphone';
      Future<void> screenshot(String name) async {
        await Future<void>.delayed(const Duration(seconds: 3));
        await tester.pump();
        await binding.takeScreenshot('$kind-$name');
      }

      Future<void> close() => key('close-panel');
      Future<void> visit(String place) async {
        // Wait for save feedback to leave so it cannot intercept the foreground tree tap.
        await Future<void>.delayed(const Duration(milliseconds: 2300));
        final finder = find.byWidgetPredicate((w) => w is GameWidget);
        final game = tester.widget<GameWidget>(finder).game as TownGame;
        await until(() => game.assetsReady);
        game.transform();
        final point = game.labelRect(place).center;
        await Future<void>.delayed(const Duration(milliseconds: 400));
        debugPrint('Entered: $place');
        await tester.tapAt(
          tester.getTopLeft(finder) + game.origin + point * game.scaleFactor,
        );
        await until(
          () => find.byKey(const Key('close-panel')).evaluate().isNotEmpty,
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }

      Future<void> parent() async {
        await key('parent-entry');
        await input('parent-pin', '719385');
        await key('unlock-parent');
        await until(() => c.parent != null);
      }

      Future<void> advance30() async {
        final before = c.account.date;
        await parent();
        await text('示例前进 30 天');
        await until(() => c.account.date == Day.add(before, 30));
        await close();
      }

      await visit('savings');
      for (final (product, amount) in [
        ('annual', '50'),
        ('dividend', '100'),
        ('sprout', '10'),
      ]) {
        await key('deposit-$product');
        await input('deposit-amount', amount);
        FocusManager.instance.primaryFocus?.unfocus();
        await key('confirm-deposit');
        await until(
          () => !c.busy && c.account.active.any((p) => p.product == product),
        );
      }
      expect(c.account.wallet, 4000);
      expect(c.account.assets, 20000);
      await screenshot('08-savings');
      await close();
      await advance30();
      expect(c.account.wallet, 4025);
      expect(c.account.bonusEarned, 25);
      await visit('savings');
      await tap(find.textContaining('下次：现金分红'));
      await key('confirm-action');
      await until(
        () =>
            c.account.active
                .singleWhere((p) => p.product == 'dividend')
                .distribution ==
            'reinvest',
      );
      await close();
      await advance30();
      expect(c.account.wallet, 4025);
      expect(
        c.account.active.singleWhere((p) => p.product == 'dividend').principal,
        10025,
      );
      await advance30();
      expect(c.account.wallet, 5032);
      expect(c.account.active.any((p) => p.product == 'sprout'), false);
      await visit('savings');
      await screenshot('09-dividend');
      await tap(find.text('提前取回').first);
      await key('confirm-action');
      await until(() => !c.account.active.any((p) => p.product == 'annual'));
      expect(c.account.wallet, 10033);
      await text('产品小课堂');
      await until(() => find.text('阿栗的财富实验室').evaluate().isNotEmpty);
      await close();

      await visit('wish');
      await text('编辑愿望');
      await book(['我的天文望远镜', '398', '5']);
      await until(() => c.account.goal == 39800);
      await text('预支与主动还款');
      await text('写一份预支提议');
      await book(['望远镜配件', '60', '3', Day.add(c.account.date, 30)]);
      await until(() => c.account.loans.isNotEmpty);
      await close();
      await parent();
      await text('提出最终条件');
      await book(['3', c.account.loans.single.first, '6']);
      await until(() => c.account.loans.single.status == 'offered');
      expect(c.account.debt, 0);
      await screenshot('10-loan-offer');
      await close();
      await visit('wish');
      await text('预支与主动还款');
      await text('阅读后接受这些条件');
      await key('confirm-action');
      await until(() => c.account.loans.single.status == 'approved');
      expect(c.account.debt, 0);
      await close();
      await parent();
      await text('确认已实际垫付购买');
      await key('confirm-action');
      await until(() => c.account.loans.single.status == 'active');
      expect(c.account.debt, 6060);
      final beforePay = c.account.wallet;
      await close();
      await advance30();
      expect(
        c.account.wallet,
        beforePay,
        reason:
            'Maturity never auto-debits installments; reinvestment does not credit cash',
      );
      await visit('wish');
      await text('预支与主动还款');
      await text('主动还一期');
      await key('confirm-action');
      await until(() => c.account.repaidTotal == 2030);
      expect(c.account.wallet, beforePay - 2030);
      await text('提前结清');
      await key('confirm-action');
      await until(() => c.account.loans.single.status == 'paid');
      expect(c.account.repaidTotal, 6030);
      expect(c.account.loans.single.payments.last.waived, 30);
      await screenshot('11-loan-paid');
      await close();

      await key('wallet');
      await text('申请实际领取');
      await book(['10', '买绘本']);
      await until(() => c.account.pendingCash == 1000);
      final assetsBeforeDelivery = c.account.assets;
      await close();
      await parent();
      await text('确认实际交付');
      await key('confirm-action');
      await until(() => c.account.withdrawn == 1000);
      expect(c.account.assets, assetsBeforeDelivery - 1000);
      await close();
      await visit('growth');
      await tap(find.byType(CheckboxListTile));
      await screenshot('12-growth');
      await close();
      await key('profiles');
      await key('switch-second');
      await until(() => c.child == 'second' && c.account.wallet == 10000);
      expect(c.account.loans, isEmpty);
      final real = await c.service.db.load('real', 'first');
      expect(real.wallet, 800);
      expect(real.bonusEarned, 0);
      expect(real.loans, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
