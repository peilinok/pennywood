import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/app/controller.dart';
import 'package:pennywood/app/paper_theme.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/money.dart';
import 'package:pennywood/features/panels.dart';
import 'database_service_test.dart' show MemoryCredentials;

void main() {
  late PennyDatabase db;
  late TownController c;
  setUp(() async {
    db = PennyDatabase(NativeDatabase.memory());
    final service = TownService(
      db,
      Auth(MemoryCredentials()),
      FixedClock('2026-11-01'),
    );
    await service.createFamily('real', '719385', ['小满', '小禾']);
    c = TownController(service, 'real', 'first');
    await c.load();
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Widget app({
    Brightness brightness = Brightness.light,
    double scale = 1,
    bool reduced = false,
  }) => MaterialApp(
    theme: paperTheme(brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: reduced,
      ),
      child: child!,
    ),
    home: Scaffold(body: TownPanel(c, 'lesson')),
  );

  testWidgets(
    'Interactive market, compounding, and dividend lessons preserve real accounts',
    (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('收益曲线，第 60 月')), findsOneWidget);
      final before = tester
          .widget<Text>(find.byKey(const Key('lesson-market-value')))
          .data;
      await tap(tester, find.byKey(const Key('lesson-new-path')));
      expect(
        tester.widget<Text>(find.byKey(const Key('lesson-market-value'))).data,
        isNot(before),
      );
      await tap(tester, find.byTooltip('向前看一月'));
      expect(find.text('59 月'), findsOneWidget);
      await tap(tester, find.byKey(const Key('lesson-compound')));
      expect(find.textContaining('第 20 年 · 再投入'), findsOneWidget);
      await tap(tester, find.byTooltip('向前看一年'));
      expect(find.textContaining('第 19 年 · 再投入'), findsOneWidget);
      await tap(tester, find.byKey(const Key('lesson-dividend')));
      await tap(tester, find.byKey(const Key('lesson-distribute')));
      expect(find.text('树上 100 元 ＋ 口袋 3 元'), findsOneWidget);
      await tap(tester, find.text('果实种回去'));
      expect(find.text('种回去：103 份 × 1 元'), findsOneWidget);
      expect(find.text('总额一直是 103 元'), findsOneWidget);
      expect(c.account.wallet, 0);
      expect(c.account.ledger, isEmpty);
      expect(c.account.date, '2026-11-01');
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Journey playback pauses, retains progress, and supports live iOS reduced motion',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final play = find.byKey(const Key('lesson-play'));
      await tester.ensureVisible(play);
      await tester.pumpAndSettle();
      await tester.tap(play);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('15 月'), findsOneWidget);
      await tester.tap(play);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('15 月'), findsOneWidget);
      await tester.tap(play);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('23 月'), findsOneWidget);
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpAndSettle();
      expect(find.text('看完整旅程'), findsOneWidget);
      await tester.tap(play);
      await tester.pumpAndSettle();
      expect(find.text('60 月'), findsOneWidget);
      expect(c.account.assets, 0);
      expect(c.account.ledger, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'Lessons retain choices across window reflow, large text, and reduced motion-$brightness',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(375, 812);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(brightness: brightness, scale: 2, reduced: true),
        );
        await tester.pumpAndSettle();
        for (final topic in ['compound', 'dividend', 'market']) {
          await tap(tester, find.byKey(Key('lesson-$topic')));
          if (topic == 'dividend') {
            await tap(tester, find.text('果实种回去'));
            await tap(tester, find.byKey(const Key('lesson-distribute')));
          }
          for (final size in [
            const Size(812, 375),
            const Size(1194, 834),
            const Size(400, 700),
            const Size(375, 812),
          ]) {
            tester.view.physicalSize = size;
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$topic $size');
            expect(
              tester
                  .widget<ChoiceChip>(find.byKey(Key('lesson-$topic')))
                  .selected,
              isTrue,
            );
            if (topic == 'dividend') {
              expect(find.text('种回去：103 份 × 1 元'), findsOneWidget);
            }
          }
        }
        expect(c.account.assets, 0);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
