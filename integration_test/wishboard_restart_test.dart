import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pennywood/features/wish_home.dart';
import 'wishboard_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Wish journal recovers after an independent process restart', (
    tester,
  ) async {
    final service = await startWishboard();
    Future<void> until(bool Function() f) async {
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (f()) return;
      }
      fail('Timed out waiting for recovery');
    }

    await until(() => find.text('回到我们的家庭').evaluate().isNotEmpty);
    await tester.tap(find.text('回到我们的家庭'));
    await until(() => find.byType(WishHome).evaluate().isNotEmpty);
    final c = tester.widget<WishHome>(find.byType(WishHome)).controller;
    expect(c.account.wallet, 200);
    expect(c.account.mainWish!.name, '我的第一台望远镜');
    expect(c.account.wishes.length, 2);
    expect(c.account.tasks.single.status, 'paid');
    expect(c.account.tasks.single.feedback, '水槽边再擦干一点就好啦');
    expect(c.account.ledger.where((l) => l.kind == 'income').length, 1);
    expect(c.parent, isNull);
    await service.restore('real');
    await c.refresh();
    expect(c.account.wallet, 200);
    final other = await service.db.load('real', 'second');
    expect(other.assets, 0);
    expect(other.wishes, isEmpty);
    final kind =
        binding.platformDispatcher.views.first.physicalSize.shortestSide /
                binding.platformDispatcher.views.first.devicePixelRatio >
            600
        ? 'ipad'
        : 'iphone';
    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.pump();
    await binding.takeScreenshot('$kind-wishboard-10-restarted');
    expect(tester.takeException(), isNull);
  });
}
