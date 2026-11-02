import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pennywood/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Native iPhone / iPad labor payment and child isolation', (
    tester,
  ) async {
    await app.main();
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
    await waitFor(find.byKey(const Key('tasks-entry')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('零钱 ¥0.00'), findsOneWidget);
    await screenshot('01-zero-town');
    await tapKey('tasks-entry');
    await waitFor(find.byKey(const Key('accept-books')));
    await tester.pump(const Duration(milliseconds: 700));
    await screenshot('02-tasks');
    await tapKey('accept-books');
    await waitFor(find.byKey(const Key('submit-books')));
    await tapKey('submit-books');
    await tapKey('confirm-action');
    await tapKey('close-panel');
    await tapKey('parent-entry');
    await input('parent-pin', '719385');
    await tapKey('unlock-parent');
    await waitFor(find.byKey(const Key('approve-books')));
    await tapKey('approve-books');
    await waitFor(find.byKey(const Key('pay-books')));
    await tester.pump(const Duration(milliseconds: 700));
    await screenshot('03-parent-reviewed');
    await tapKey('pay-books');
    await tapKey('confirm-action');
    await tester.pump(const Duration(seconds: 1));
    await tapKey('close-panel');
    await waitFor(find.text('零钱 ¥8.00'));
    await tester.pump(const Duration(seconds: 3));
    await screenshot('04-paid-town');
    await tapKey('profiles');
    await tapKey('switch-second');
    await waitFor(find.text('小禾的小镇  ›'));
    expect(find.text('零钱 ¥0.00'), findsOneWidget);
    await screenshot('05-second-child');
    await tapKey('profiles');
    await tapKey('switch-first');
    await waitFor(find.text('零钱 ¥8.00'));
    await tapKey('wallet');
    await waitFor(find.text('可以安排的零钱 ¥8.00'));
    await screenshot('06-ledger');
    await tapKey('close-panel');
    expect(tester.takeException(), isNull);
  });
}
