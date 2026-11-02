import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/app/controller.dart';
import 'package:pennywood/app/paper_theme.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/backup.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/money.dart';
import 'package:pennywood/features/family_settings.dart';
import 'database_service_test.dart' show MemoryCredentials;

void main() {
  late PennyDatabase db;
  late TownController c;
  setUp(() async {
    db = PennyDatabase(NativeDatabase.memory());
    final svc = TownService(
      db,
      Auth(MemoryCredentials()),
      FixedClock('2026-11-01'),
    );
    await svc.createFamily('real', '719385', ['小满', '小禾']);
    c = TownController(svc, 'real', 'first');
    await c.load();
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('pennywood/files'), null);
    c.dispose();
    await db.close();
  });
  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: paperTheme(Brightness.light),
        home: Scaffold(body: FamilySettings(c)),
      ),
    );
  }

  Future<void> waitFor(WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 200 && !condition(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(condition(), isTrue);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Export uses a separate password and native save picker, then relocks parent access',
    (tester) async {
      Uint8List? exported;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('pennywood/files'),
        (call) async {
          expect(call.method, 'exportBackup');
          exported = (call.arguments as Map)['bytes'] as Uint8List;
          return true;
        },
      );
      await mount(tester);
      await tester.tap(find.byKey(const Key('export-backup')));
      await tester.pumpAndSettle();
      for (final (index, value) in [
        (0, '719385'),
        (1, '独立备份密码-2026'),
        (2, '独立备份密码-2026'),
      ]) {
        final field = find.byKey(Key('action-field-$index'));
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
        expect(
          tester
              .widget<TextField>(
                find.descendant(of: field, matching: find.byType(TextField)),
              )
              .obscureText,
          isTrue,
        );
      }
      await tester.runAsync(
        () => tester.tap(find.byKey(const Key('action-save'))),
      );
      await waitFor(tester, () => exported != null);
      final verified = await tester.runAsync(
        () => FamilyBackup(db, c.service.auth).read(exported!, '独立备份密码-2026'),
      );
      expect(verified!.children, ['小满', '小禾']);
      expect(c.parent, isNull);
      expect(find.textContaining('已保存到所选位置'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Restore previews children, time, and ledger; cancelling preserves current accounts',
    (tester) async {
      late Uint8List bytes;
      await tester.runAsync(() async {
        await c.unlock('719385');
        bytes = await FamilyBackup(
          db,
          c.service.auth,
        ).export(c.parent!, '独立备份密码-2026');
        await c.perform('addWish', ['saving', '恢复后仍应保留的新心愿', 10000]);
      });
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('pennywood/files'),
        (_) async => bytes,
      );
      await mount(tester);
      await tester.tap(find.byKey(const Key('restore-backup')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('action-field-0')),
        '独立备份密码-2026',
      );
      await tester.enterText(find.byKey(const Key('action-field-1')), '719385');
      await tester.runAsync(
        () => tester.tap(find.byKey(const Key('action-save'))),
      );
      await waitFor(
        tester,
        () => find
            .byKey(const Key('confirm-backup-restore'))
            .evaluate()
            .isNotEmpty,
      );
      expect(find.textContaining('孩子：小满、小禾'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await waitFor(
        tester,
        () => find.byKey(const Key('form-error')).evaluate().isNotEmpty,
      );
      expect(c.account.wishes.single.name, '恢复后仍应保留的新心愿');
      expect((await db.load('real', 'first')).wishes.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
