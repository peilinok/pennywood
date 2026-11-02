import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pennywood/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'A fresh process restores CNY 8, child isolation, and a locked parent area',
    (tester) async {
      await app.main();
      Future<void> waitFor(Finder f) async {
        for (var i = 0; i < 100; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (f.evaluate().isNotEmpty) return;
        }
        fail('Timed out waiting for UI: $f');
      }

      await waitFor(find.text('回到我们的家庭'));
      await tester.tap(find.text('回到我们的家庭'));
      await waitFor(find.text('零钱 ¥8.00'));
      await Future<void>.delayed(const Duration(seconds: 3));
      await tester.pump();
      final kind =
          binding.platformDispatcher.views.first.physicalSize.shortestSide /
                  binding.platformDispatcher.views.first.devicePixelRatio >
              600
          ? 'ipad'
          : 'iphone';
      await binding.takeScreenshot('$kind-07-restarted-town');
      await tester.tap(find.byKey(const Key('parent-entry')));
      await waitFor(find.byKey(const Key('parent-pin')));
      expect(find.byKey(const Key('unlock-parent')), findsOneWidget);
      await tester.tap(find.byKey(const Key('close-panel')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('profiles')));
      await waitFor(find.byKey(const Key('switch-second')));
      await tester.tap(find.byKey(const Key('switch-second')));
      await waitFor(find.text('零钱 ¥0.00'));
      await tester.tap(find.byKey(const Key('profiles')));
      await waitFor(find.byKey(const Key('switch-first')));
      await tester.tap(find.byKey(const Key('switch-first')));
      await waitFor(find.text('零钱 ¥8.00'));
      expect(tester.takeException(), isNull);
    },
  );
}
