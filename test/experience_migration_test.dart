import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/backup.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/money.dart';
import 'database_service_test.dart' show MemoryCredentials;
import 'support/schema5_database.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  test(
    'Schema5 upgrade and restart preserve original promises, linked payments, identity, and operation replay',
    () async {
      final dir = await Directory.systemTemp.createTemp('pennywood-schema5-');
      final file = File('${dir.path}/legacy.sqlite');
      await createSchema5Fixture(file);
      final db = PennyDatabase.file(file);
      try {
        final svc = TownService(
          db,
          Auth(MemoryCredentials()),
          FixedClock('2026-11-01'),
        );
        final first = await db.load('real', 'first'),
            second = await db.load('real', 'second');
        expect(first.debt, 4848);
        expect(first.wishes.single.receivedCost, 8000);
        expect(first.requests.single.usedForGift, isTrue);
        expect(first.loans.single.usedForGift, isTrue);
        expect(second.assets, 20000);
        expect(second.wallet, 15000);
        expect(second.reserved, 37);
        expect(second.positions.single.rateBps, 300);
        expect(first.marketEnabled, isFalse);
        expect(first.quickTasks.first.amount, second.quickTasks.first.amount);
        expect(second.rateFor('annual'), first.rateFor('annual'));
        expect(await db.rows('PRAGMA foreign_key_check'), isEmpty);
        await svc.restore('real');
        await svc.auth.create('real', '843721');
        final parent = await svc.auth.unlock('real', 'second', '843721');
        first.check();
        second.check();
        expect(
          await svc.execute(parent, 'legacy-source', 'pay', ['old-task']),
          'old-task',
        );
        expect((await db.load('real', 'second')).wallet, 15000);
        final old = Schema5Database(
          NativeDatabase(File('${file.path}.before-v5.sqlite')),
        );
        try {
          expect(
            (await old.rows('PRAGMA user_version')).single.values.single,
            5,
          );
          expect(
            (await old.rows(
              "SELECT amount FROM quick_tasks WHERE child_id='second' AND id='dishes'",
            )).single['amount'],
            300,
          );
          expect(
            await old.rows('SELECT * FROM ledger'),
            hasLength(first.ledger.length + second.ledger.length),
          );
        } finally {
          await old.close();
        }
      } finally {
        await db.close();
      }
      final reopened = PennyDatabase.file(file);
      try {
        expect(
          (await reopened.load('real', 'second')).positions.single.expected,
          37,
        );
        expect((await reopened.load('real', 'first')).debt, 4848);
      } finally {
        await reopened.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'Failed schema5 migration rolls back added columns and preserves the before-copy for retry',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'pennywood-schema5-fail-',
      );
      final file = File('${dir.path}/legacy.sqlite');
      await createSchema5Fixture(file);
      final old = Schema5Database(NativeDatabase(file));
      await old.customStatement(
        'CREATE TABLE family_agreements(injected TEXT)',
      );
      await old.close();
      final failing = PennyDatabase.file(file);
      try {
        await expectLater(
          failing.rows('SELECT * FROM children'),
          throwsA(anything),
        );
      } finally {
        await failing.close();
      }
      final preserved = Schema5Database(NativeDatabase(file));
      try {
        expect(
          (await preserved.rows('PRAGMA user_version')).single.values.single,
          5,
        );
        expect(
          (await preserved.rows(
            'PRAGMA table_info(children)',
          )).any((r) => r['name'] == 'market_return'),
          isFalse,
        );
        expect(
          (await preserved.rows(
            "SELECT wallet FROM children WHERE id='second'",
          )).single['wallet'],
          15000,
        );
        expect(File('${file.path}.before-v5.sqlite').existsSync(), isTrue);
        await preserved.customStatement('DROP TABLE family_agreements');
      } finally {
        await preserved.close();
      }
      final retry = PennyDatabase.file(file);
      try {
        expect((await retry.load('real', 'second')).reserved, 37);
      } finally {
        await retry.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'Frozen schema5 archive from the baseline writer restores and re-exports as schema6',
    () async {
      final db = PennyDatabase(NativeDatabase.memory());
      final auth = Auth(MemoryCredentials());
      final backup = FamilyBackup(db, auth);
      try {
        final bytes = await File(
          'test/fixtures/backup-schema5.json',
        ).readAsBytes();
        expect(
          jsonDecode(utf8.decode(bytes))['format'],
          'Pennywood-encrypted-backup:1:schema5',
        );
        final old = await backup.read(bytes, 'schema5-fixture-password');
        await backup.restore(old, newPin: '843721');
        final s = await db.load('real', 'first');
        expect(s.debt, 4848);
        expect(s.marketEnabled, isFalse);
        expect(s.wishes.single.receivedCost, 8000);
        final a = await auth.unlock('real', 'first', '843721');
        final updated = await backup.export(a, 'schema5-fixture-password');
        expect(
          jsonDecode(utf8.decode(updated))['format'],
          'Pennywood-encrypted-backup:1:schema6',
        );
        await backup.read(updated, 'schema5-fixture-password');
        expect(await db.rows('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        await db.close();
      }
    },
  );
}
