import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/app/controller.dart';
import 'package:pennywood/app/paper_theme.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/money.dart';
import 'package:pennywood/features/wish_home.dart';
import 'database_service_test.dart' show MemoryCredentials;

void main() {
  late PennyDatabase db;
  late TownController c;
  setUp(() async {
    db = PennyDatabase(NativeDatabase.memory());
    final service = TownService(
      db,
      Auth(MemoryCredentials()),
      FixedClock('2026-11-03'),
    );
    await service.createFamily('real', '719385', ['小满', '小禾']);
    c = TownController(service, 'real', 'first');
    await c.load();
    await c.perform('addWish', ['gift', '望远镜', 8000]);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: paperTheme(Brightness.light), home: WishHome(c)),
    );
    await tester.pumpAndSettle();
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Wish list detail and editing use sequential pages and retain return context',
    (tester) async {
      await mount(tester);
      final id = c.account.mainWish!.id;
      expect(find.text('管理这份心愿'), findsNothing);
      await tap(tester, find.byKey(const Key('wish-folder')));
      expect(find.byType(AlertDialog), findsNothing);
      await tap(tester, find.text('望远镜'));
      await tap(tester, find.byKey(Key('edit-wish-$id')));
      await tester.enterText(find.byKey(const Key('action-field-0')), '看月亮');
      await tester.enterText(find.byKey(const Key('action-field-1')), '0');
      await tap(tester, find.byKey(const Key('action-save')));
      expect(find.byKey(const Key('form-error')), findsOneWidget);
      tester.view.physicalSize = const Size(874, 402);
      await tester.pumpAndSettle();
      expect(find.text('看月亮'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('action-field-1')), '90');
      await tap(tester, find.byKey(const Key('action-save')));
      expect(find.byKey(Key('edit-wish-$id')), findsOneWidget);
      expect(c.account.mainWish!.name, '看月亮');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('其他心愿'), findsOneWidget);
      expect(c.account.wallet, 0);
    },
  );

  testWidgets(
    'Child receipt is explanatory and a gift advance preserves its explicit association',
    (tester) async {
      await mount(tester);
      final id = c.account.mainWish!.id;
      await tap(tester, find.byKey(const Key('manage-main-wish')));
      expect(find.widgetWithText(OutlinedButton, '礼物到手，请家长登记'), findsNothing);
      expect(find.text('礼物实际到手后，请家长核实付款并登记。'), findsOneWidget);
      await tap(tester, find.byKey(Key('propose-advance-$id')));
      await tester.enterText(find.byKey(const Key('book-field-1')), '20');
      await tap(tester, find.byKey(const Key('book-continue')));
      expect(c.account.loans.single.wishId, id);
      expect(c.account.loans.single.amount, 2000);
      expect(c.account.wallet, 0);
      expect(c.account.debt, 0);
      expect(find.byKey(Key('edit-wish-$id')), findsOneWidget);
    },
  );
}
