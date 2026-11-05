import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/app/paper_theme.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/money.dart';
import 'package:pennywood/features/wish_home.dart';
import 'package:pennywood/main.dart';
import 'database_service_test.dart' show MemoryCredentials;

void main() {
  late PennyDatabase db;
  late TownService svc;
  setUp(() {
    db = PennyDatabase(NativeDatabase.memory());
    svc = TownService(db, Auth(MemoryCredentials()), FixedClock('2026-11-03'));
  });
  tearDown(() async {
    paperThemeMode.value = ThemeMode.system;
    await db.close();
  });
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Returning real families enter their selected child once and explicit home return stays at entry',
    (tester) async {
      await tester.runAsync(() async {
        await svc.createFamily('real', '719385', ['小满', '小禾']);
        await svc.createFamily('demo', '935172', ['示例栗', '示例果'], demo: true);
        await svc.selectChild('real', 'second');
      });
      await tester.pumpWidget(PennywoodApp(svc));
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await settle(tester);
      final c = tester.widget<WishHome>(find.byType(WishHome)).controller;
      expect(c.family, 'real');
      expect(c.child, 'second');
      expect(c.parent, isNull);
      expect(c.account.assets, 0);
      expect(find.byKey(const Key('theme-toggle')), findsNothing);
      expect(find.text('家长'), findsOneWidget);
      await tester.tap(find.byTooltip('更多'));
      await settle(tester);
      expect(find.text('去小镇散步'), findsNothing);
      expect(find.text('外观'), findsOneWidget);
      await tester.tap(find.text('返回家庭入口'));
      await settle(tester);
      expect(find.byType(WishHome), findsNothing);
      expect(find.text('回到我们的家庭'), findsOneWidget);
      await settle(tester);
      expect(find.byType(WishHome), findsNothing);
    },
  );
  testWidgets(
    'Demo stays explicit and appearance follows system with separate light and dark choices',
    (tester) async {
      await tester.runAsync(
        () => svc.createFamily('demo', '935172', ['示例栗', '示例果'], demo: true),
      );
      await tester.pumpWidget(PennywoodApp(svc));
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await settle(tester);
      expect(find.byType(WishHome), findsNothing);
      await tester.tap(find.text('进入独立示例家庭'));
      await settle(tester);
      final c = tester.widget<WishHome>(find.byType(WishHome)).controller;
      expect(c.demo, isTrue);
      final wallet = c.account.wallet;
      expect(paperThemeMode.value, ThemeMode.system);
      await tester.tap(find.byTooltip('更多'));
      await settle(tester);
      await tester.tap(find.text('外观'));
      await settle(tester);
      for (final choice in [
        ('深色', ThemeMode.dark),
        ('浅色', ThemeMode.light),
        ('跟随系统', ThemeMode.system),
      ]) {
        await tester.tap(find.text(choice.$1));
        await settle(tester);
        expect(paperThemeMode.value, choice.$2);
        expect(c.account.wallet, wallet);
        expect(c.parent, isNull);
      }
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.byType(WishHome), findsOneWidget);
    },
  );
}
