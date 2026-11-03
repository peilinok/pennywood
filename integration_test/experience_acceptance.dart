import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pennywood/app/controller.dart';
import 'package:pennywood/app/paper_theme.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/backup.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/money.dart';
import 'package:pennywood/features/wish_home.dart';
import '../test/support/schema5_database.dart';

class ExperienceCredentials implements CredentialStore {
  final store = KeychainCredentials();
  static const prefix = 'family-experience-verification.';
  @override
  Future<String?> read(String key) => store.read('$prefix$key');
  @override
  Future<void> write(String key, String value) =>
      store.write('$prefix$key', value);
}

Future<File> experienceFile() async => File(
  '${(await getApplicationSupportDirectory()).path}/pennywood-experience-verification.sqlite',
);

Future<void> verifyExperience(WidgetTester tester) async {
  final file = await experienceFile();
  if (await file.exists()) await file.delete();
  final before = File('${file.path}.before-v5.sqlite');
  if (await before.exists()) await before.delete();
  final credentials = ExperienceCredentials();
  for (final key in ['pennywood.real', 'pennywood.recovery.real']) {
    await credentials.store.storage.delete(
      key: '${ExperienceCredentials.prefix}$key',
    );
  }
  await createSchema5Fixture(file);
  final clock = FixedClock('2026-11-01');
  final svc = TownService(PennyDatabase.file(file), Auth(credentials), clock);
  await svc.auth.create('real', '843721');
  final c = TownController(svc, 'real', 'second');
  await c.load();
  expect(await before.exists(), isTrue);
  expect(c.account.assets, 20000);
  expect(c.account.positions.single.expected, 37);
  expect((await svc.db.load('real', 'first')).debt, 4848);
  await tester.pumpWidget(
    MaterialApp(theme: paperTheme(Brightness.light), home: WishHome(c)),
  );
  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (condition()) return;
    }
    fail('Timed out waiting for investment experience acceptance');
  }

  Future<void> tap(Finder f) async {
    await until(() => f.evaluate().length == 1);
    await tester.ensureVisible(f);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> key(String value) => tap(find.byKey(Key(value)));
  Future<void> input(String key, String value) async {
    final f = find.byKey(Key(key));
    await tester.ensureVisible(f);
    await tester.enterText(f, value);
  }

  Future<void> hideKeyboard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> shot(String name) async {
    await tester.pump(const Duration(milliseconds: 300));
    await IntegrationTestWidgetsFlutterBinding.instance.takeScreenshot(
      'experience-$name',
    );
  }

  await key('parent-entry');
  await input('parent-pin', '843721');
  await hideKeyboard();
  await key('unlock-parent');
  await until(() => c.parent != null);
  await tap(find.text('家庭约定'));
  await key('configure-dishes');
  await input('action-field-0', '洗净餐具并归位');
  await input('action-field-1', '2');
  await hideKeyboard();
  await key('action-save');
  await until(() => c.account.quickTasks.first.amount == 200);
  expect((await svc.db.load('real', 'first')).quickTasks.first.amount, 200);
  await tap(find.text('管理收益预算、领取和预支'));
  await key('edit-child-budget');
  await input('book-field-0', '100');
  await hideKeyboard();
  await key('book-continue');
  await until(() => c.account.budget == 10000);
  await key('edit-product-rates');
  for (final entry in ['1', '5', '3'].asMap().entries) {
    await input('book-field-${entry.key}', entry.value);
  }
  await hideKeyboard();
  await key('book-continue');
  await until(() => c.account.rateFor('annual') == 500);
  await key('market-permission');
  await key('confirm-action');
  await until(() => c.account.marketEnabled);
  await shot('parent-terms');
  await key('close-panel');
  expect(c.parent, isNotNull);
  for (final label in ['待确认', '孩子与心愿', '家庭约定']) {
    await tap(find.text(label));
    expect(find.byKey(const Key('unlock-parent')), findsNothing);
  }
  await key('parent-entry');
  await tap(find.text('我的零钱'));
  await key('arrange-money');
  await key('deposit-growth');
  await input('deposit-amount', '100');
  await hideKeyboard();
  await key('confirm-deposit');
  await until(() => c.account.positions.length == 2);
  expect(c.account.wallet, 5000);
  expect(c.account.reserved, 2037);
  await until(
    () => find.byKey(const Key('confirm-deposit')).evaluate().isEmpty,
  );
  await tap(find.byType(BackButton));
  await tester.pump(const Duration(milliseconds: 400));
  await key('open-lesson');
  await key('lesson-play');
  await tester.pump(const Duration(seconds: 2));
  await key('lesson-play');
  await shot('market-journey');
  await key('lesson-compound');
  await shot('compound');
  await key('lesson-dividend');
  await key('lesson-distribute');
  await shot('dividend');
  expect(c.account.wallet, 5000);
  expect(c.account.marketReturn, 0);
  await tap(find.byType(BackButton));
  await tester.pump(const Duration(milliseconds: 400));
  clock.advance(1);
  await c.resume();
  await c.perform('redeem', [
    c.account.positions.last.id,
  ], operationId: 'native-market-redeem');
  expect(c.account.wallet, 14952);
  expect(c.account.marketReturn, -48);
  expect(c.account.marketSpent, 0);
  await c.unlock('843721');
  final backup = FamilyBackup(svc.db, svc.auth);
  final bytes = await backup.export(c.parent!, 'synthetic-experience-backup');
  final directory = await getApplicationSupportDirectory();
  final archive = File('${directory.path}/experience-verification.pennywood');
  await archive.writeAsBytes(bytes, flush: true);
  final verified = await backup.read(
    await archive.readAsBytes(),
    'synthetic-experience-backup',
  );
  await c.perform('addWish', ['saving', '恢复前测试心愿', 1000]);
  await backup.restore(
    verified,
    access: c.parent,
    preserveBefore: (bytes) async {
      final safety = File(
        '${directory.path}/experience-before-verification.pennywood',
      );
      await safety.writeAsBytes(bytes, flush: true);
      return safety.path;
    },
  );
  c.lock();
  await c.load();
  expect(c.account.wishes, isEmpty);
  expect(c.account.marketReturn, -48);
  expect(c.account.positions.first.rateBps, 300);
  expect((await svc.db.load('real', 'first')).debt, 4848);
  expect(await svc.db.rows('PRAGMA foreign_key_check'), isEmpty);
  await tester.pumpWidget(const SizedBox());
  c.dispose();
  await svc.db.close();
}

Future<void> verifyExperienceRestart(WidgetTester tester) async {
  final svc = TownService(
    PennyDatabase.file(await experienceFile()),
    Auth(ExperienceCredentials()),
    FixedClock('2026-11-02'),
  );
  try {
    final s = await svc.db.load('real', 'second');
    expect(s.wallet, 14952);
    expect(s.marketReturn, -48);
    expect(s.marketSpent, 0);
    expect(s.marketEnabled, isTrue);
    expect(s.rateFor('sprout'), 100);
    expect(s.rateFor('annual'), 500);
    expect(s.positions.first.rateBps, 300);
    expect(s.reserved, 37);
    expect(s.quickTasks.first.amount, 200);
    expect(s.wishes, isEmpty);
    expect((await svc.db.load('real', 'first')).quickTasks.first.amount, 200);
    expect((await svc.db.load('real', 'first')).debt, 4848);
    final a = await svc.auth.unlock('real', 'second', '843721');
    await svc.execute(a, 'native-market-redeem', 'redeem', [
      s.positions.last.id,
    ]);
    await svc.restore('real');
    final again = await svc.db.load('real', 'second');
    expect(again.wallet, 14952);
    expect(again.ledger.length, s.ledger.length);
    again.check();
    expect(await svc.db.rows('PRAGMA foreign_key_check'), isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
  } finally {
    await svc.db.close();
  }
}
