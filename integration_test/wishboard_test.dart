import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pennywood/features/wish_home.dart';
import 'wishboard_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'Wish journal: zero setup, agreements, withdrawal, feedback, payment, children, and themes',
    (tester) async {
      await startWishboard(reset: true);
      Future<void> until(bool Function() f) async {
        for (var i = 0; i < 150; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (f()) return;
        }
        fail('Timed out waiting for UI or business state');
      }

      Future<void> tap(Finder f) async {
        await until(() => f.evaluate().isNotEmpty);
        await tester.ensureVisible(f);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.tap(f);
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> key(String k) => tap(find.byKey(Key(k)));
      Future<void> input(String k, String v) async {
        final f = find.byKey(Key(k));
        await until(() => f.evaluate().isNotEmpty);
        await tester.ensureVisible(f);
        await tester.enterText(f, v);
        await tester.pump();
      }

      Future<void> hideKeyboard() async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 400));
      }

      final kind =
          binding.platformDispatcher.views.first.physicalSize.shortestSide /
                  binding.platformDispatcher.views.first.devicePixelRatio >
              600
          ? 'ipad'
          : 'iphone';
      Future<void> shot(String name) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        await tester.pump();
        await binding.takeScreenshot('$kind-wishboard-$name');
      }

      await key('create-real');
      await input('first-name', '小栗');
      await input('second-name', '小桃');
      await input('setup-pin', '719385');
      await input('setup-pin-again', '719385');
      await hideKeyboard();
      await key('finish-setup');
      await until(() => find.byType(WishHome).evaluate().isNotEmpty);
      final c = tester.widget<WishHome>(find.byType(WishHome)).controller;
      expect(c.account.assets, 0);
      expect(c.account.tasks, isEmpty);
      await key('new-wish');
      await input('action-field-0', '我的第一台望远镜');
      await input('action-field-1', '80');
      await hideKeyboard();
      await key('action-save');
      await until(() => c.account.mainWish != null);
      await key('wish-folder');
      await key('new-wish');
      await tap(find.text('攒钱目标'));
      await input('action-field-0', '我的第一个200元');
      await input('action-field-1', '200');
      await hideKeyboard();
      await key('action-save');
      await until(() => c.account.wishes.length == 2);
      await shot('01-zero-wish');
      Future<void> unlock() async {
        await input('parent-pin', '719385');
        await hideKeyboard();
        await key('unlock-parent');
        await until(() => c.parent != null);
      }

      await key('parent-entry');
      await unlock();
      await tap(find.text('家庭约定'));
      await key('configure-dishes');
      await input('action-field-0', '洗净自己的餐具，擦干水槽边的水');
      await input('action-field-1', '2');
      await hideKeyboard();
      await key('action-save');
      await until(() => c.account.quickTasks.first.enabled);
      await shot('02-agreements');
      await key('parent-entry');
      await tap(find.text('我的任务'));
      await key('quick-dishes');
      await until(() => c.account.tasks.isNotEmpty);
      final id = c.account.tasks.single.id;
      expect(c.account.wallet, 0);
      await key('quick-dishes');
      await key('withdraw-$id');
      await until(() => c.account.tasks.single.status == 'available');
      await key('quick-dishes');
      await until(() => c.account.tasks.single.status == 'submitted');
      await key('quick-dishes');
      expect(c.account.tasks.length, 1);
      await tap(find.text('知道了'));
      await shot('03-submitted');
      await key('parent-entry');
      await unlock();
      await key('review-$id');
      await key('feedback-$id');
      await input('action-field-0', '水槽边再擦干一点就好啦');
      await hideKeyboard();
      await key('action-save');
      await until(() => c.account.tasks.single.status == 'needsWork');
      await key('parent-entry');
      await tap(find.text('我的任务'));
      await key('quick-dishes');
      await shot('04-feedback');
      await key('submit-$id');
      await until(() => c.account.tasks.single.status == 'submitted');
      await key('parent-entry');
      await unlock();
      await key('review-$id');
      await key('approve-$id');
      await until(() => c.account.tasks.single.status == 'confirmed');
      expect(c.account.wallet, 0);
      final pay = find.byKey(Key('pay-$id'));
      expect(tester.widget<FilledButton>(pay).onPressed, isNull);
      await shot('05-before-payment');
      await key('payment-delivered');
      await key('pay-$id');
      await until(() => c.account.wallet == 200);
      await tap(find.text('返回'));
      await key('parent-entry');
      expect(c.account.ledger.where((l) => l.kind == 'income').length, 1);
      await shot('06-paid-wish');
      await tap(find.text('我的零钱'));
      await until(
        () => find.byKey(const Key('wallet-amount')).evaluate().isNotEmpty,
      );
      await shot('07-ledger');
      await key('profiles');
      await key('switch-second');
      await until(() => c.child == 'second');
      expect(c.account.assets, 0);
      expect(c.account.wishes, isEmpty);
      expect(c.parent, isNull);
      await tap(find.text('我的心愿'));
      await shot('08-second-child');
      await key('profiles');
      await key('switch-first');
      await until(() => c.child == 'first');
      expect(c.account.wallet, 200);
      expect(c.account.wishes.length, 2);
      await key('theme-toggle');
      await shot('09-dark');
      await key('theme-toggle');
      // Background locking requires a fresh passcode; children cannot reuse parent authority.
      await key('parent-entry');
      await unlock();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await until(() => c.parent == null);
      expect(find.byKey(const Key('parent-pin')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
