import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pennywood/features/wish_home.dart';
import 'wishboard_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Native iPhone / iPad labor payment and child isolation', (
    tester,
  ) async {
    await startWishboard(reset: true, scenario: 'legacy-flow');
    Future<void> waitFor(Finder finder, {int attempts = 100}) async {
      for (var i = 0; i < attempts; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (finder.evaluate().isNotEmpty) return;
      }
      fail('Timed out waiting for UI: $finder');
    }

    Future<void> tapKey(String key) async {
      final f = find.byKey(Key(key));
      await waitFor(f);
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> input(String key, String text) async {
      final f = find.byKey(Key(key));
      await tester.ensureVisible(f);
      await tester.enterText(f, text);
      await tester.pump(const Duration(milliseconds: 150));
    }

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

    await waitFor(find.byKey(const Key('create-real')));
    await tapKey('create-real');
    await input('first-name', '小满');
    await input('second-name', '小禾');
    await input('setup-pin', '719385');
    await input('setup-pin-again', '719385');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 400));
    await tapKey('finish-setup');
    await waitFor(find.byType(WishHome));
    final c = tester.widget<WishHome>(find.byType(WishHome)).controller;
    expect(c.account.wallet, 0);
    await screenshot('01-zero-journal');
    await tapKey('parent-entry');
    await input('parent-pin', '719385');
    await tapKey('unlock-parent');
    await waitFor(find.text('孩子'));
    await tester.tap(find.text('孩子'));
    await tester.pump(const Duration(milliseconds: 400));
    await tapKey('add-task');
    await input('action-field-0', '整理图书');
    await input('action-field-1', '图书分类摆好，和家长一起检查');
    await input('action-field-2', '8');
    FocusManager.instance.primaryFocus?.unfocus();
    await tapKey('action-save');
    await waitFor(find.byKey(const Key('add-task')));
    final task = c.account.tasks.single.id;
    await tapKey('parent-entry');
    await tester.tap(find.text('我的任务'));
    await tester.pump(const Duration(milliseconds: 400));
    await screenshot('02-tasks');
    await tapKey('accept-$task');
    await tapKey('submit-$task');
    expect(c.account.wallet, 0);
    await tapKey('parent-entry');
    await input('parent-pin', '719385');
    await tapKey('unlock-parent');
    await tapKey('review-$task');
    await tapKey('approve-$task');
    await screenshot('03-parent-reviewed');
    expect(c.account.wallet, 0);
    await tapKey('payment-delivered');
    await tapKey('pay-$task');
    await waitFor(find.text('已经兑现并保存，孩子的心愿进度已更新。'));
    await tester.tap(find.text('返回'));
    await tester.pump(const Duration(milliseconds: 400));
    await tapKey('parent-entry');
    expect(c.account.wallet, 800);
    await screenshot('04-paid-journal');
    await tapKey('profiles');
    await tapKey('switch-second');
    await waitFor(find.text('小禾的心愿手账'));
    expect(c.account.wallet, 0);
    await screenshot('05-second-child');
    await tapKey('profiles');
    await tapKey('switch-first');
    await waitFor(find.text('小满的心愿手账'));
    expect(c.account.wallet, 800);
    await tester.tap(find.text('我的零钱'));
    await waitFor(find.byKey(const Key('wallet-amount')));
    expect(find.text('¥8.00'), findsOneWidget);
    await screenshot('06-ledger');
    expect(tester.takeException(), isNull);
  });
}
