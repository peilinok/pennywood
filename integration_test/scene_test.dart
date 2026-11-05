import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pennywood/app/screens.dart';
import 'package:pennywood/game/town_game.dart';
import 'package:pennywood/app/controller.dart';
import 'package:pennywood/features/wish_home.dart';
import 'wishboard_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'Camera, atmosphere, custom tasks, and business forms survive window changes',
    (tester) async {
      final service = await startWishboard(scenario: 'legacy-flow');
      Future<void> until(bool Function() condition) async {
        for (var i = 0; i < 100; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (condition()) return;
        }
        fail('Timed out waiting for scene or form');
      }

      Future<void> tap(Finder f) async {
        await until(() => f.evaluate().isNotEmpty);
        await tester.ensureVisible(f);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.tap(f);
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> input(String name, String value) async {
        final f = find.byKey(Key(name));
        await until(() => f.evaluate().isNotEmpty);
        await tester.ensureVisible(f);
        await tester.enterText(f, value);
        await tester.pump();
      }

      await until(() => find.byType(WishHome).evaluate().isNotEmpty);
      final c = TownController(service, 'real', 'first');
      await c.load();
      // Exercise the preserved scene directly, outside the production navigation.
      await tester.pumpWidget(MaterialApp(home: TownHome(c)));
      final finder = find.byWidgetPredicate((w) => w is GameWidget);
      final game = tester.widget<GameWidget>(finder).game as TownGame;
      await until(() => game.assetsReady);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(c.account.wallet, 800);
      final location = (c.scene.x, c.scene.y);
      final ledgerSize = c.account.ledger.length;

      await tester.drag(finder, const Offset(35, -15));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.scene.panX.abs() + c.scene.panY.abs(), greaterThan(0));
      await tap(find.byTooltip('镜头复位'));
      final center = tester.getCenter(finder);
      final left = await tester.startGesture(
        center - const Offset(40, 0),
        pointer: 1,
      );
      final right = await tester.startGesture(
        center + const Offset(40, 0),
        pointer: 2,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await left.moveBy(const Offset(-20, 0));
      await right.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await left.up();
      await right.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.scene.zoom, greaterThan(1));
      await tap(find.byTooltip('镜头复位'));
      expect((c.scene.zoom, c.scene.panX, c.scene.panY), (1, 0, 0));
      await tap(find.byTooltip('放大'));
      expect(c.scene.zoom, closeTo(1.15, .001));
      await tap(find.byTooltip('缩小'));
      expect(c.scene.zoom, closeTo(1, .001));
      await tap(find.text('☀ 午后'));
      await tap(find.byTooltip('开启音效'));
      final saved = await c.service.db.loadScene(c.family, c.child);
      expect(saved.evening, true);
      expect(saved.sound, true);
      expect(
        c.account.wallet,
        800,
        reason: 'Exploration and atmosphere changes do not pay money',
      );
      expect(c.account.ledger.length, ledgerSize);
      final kind =
          binding.platformDispatcher.views.first.physicalSize.shortestSide /
                  binding.platformDispatcher.views.first.devicePixelRatio >
              600
          ? 'ipad'
          : 'iphone';
      await Future<void>.delayed(const Duration(seconds: 1));
      await binding.takeScreenshot('$kind-13-evening');
      await tap(find.text('☾ 黄昏'));
      await tap(find.byTooltip('关闭音效'));

      await tap(find.byKey(const Key('parent-entry')));
      await input('parent-pin', '719385');
      await tap(find.byKey(const Key('unlock-parent')));
      await until(() => c.parent != null);
      await tap(find.text('孩子'));
      await tap(find.byKey(const Key('add-task')));
      await input('action-field-0', '把抽屉整理好');
      await input('action-field-2', '6');
      await input('action-field-1', '铅笔和橡皮分类收好，请家长检查');
      FocusManager.instance.primaryFocus?.unfocus();
      await binding.setSurfaceSize(const Size(844, 390));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('把抽屉整理好'), findsOneWidget);
      expect((c.scene.x, c.scene.y), location);
      expect(c.account.ledger.length, ledgerSize);
      await binding.setSurfaceSize(null);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('铅笔和橡皮分类收好，请家长检查'), findsOneWidget);
      await tap(find.byKey(const Key('action-save')));
      await until(() => c.account.tasks.any((t) => t.name == '把抽屉整理好'));
      final task = c.account.tasks.singleWhere((t) => t.name == '把抽屉整理好');
      expect(task.amount, 600);
      expect(task.status, 'available');
      expect(c.account.wallet, 800);
      await tap(find.byTooltip('更多'));
      await tap(find.text('返回家庭入口'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.parent, isNull);
      expect(identical(tester.widget<GameWidget>(finder).game, game), true);
      expect(tester.takeException(), isNull);
    },
  );
}
