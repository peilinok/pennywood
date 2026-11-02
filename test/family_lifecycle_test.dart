import 'dart:io';
import 'package:drift/drift.dart' show MigrationStrategy, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/money.dart';
import 'database_service_test.dart' show MemoryCredentials;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  late PennyDatabase db;
  late TownService service;
  late Access child, parent;
  var sequence = 0;
  final credentials = MemoryCredentials();
  Future<String> run(
    String action,
    List<Object?> args, {
    bool adult = false,
  }) async =>
      await service.execute(
        adult ? parent : child,
        'test-${++sequence}',
        action,
        args,
      ) ??
      '';
  Future<void> earn(int amount) async {
    final id = await run('addTask', ['现实劳动', amount, '按约定完成'], adult: true);
    await run('accept', [id]);
    await run('submit', [id]);
    await run('approve', [id], adult: true);
    await run('pay', [id], adult: true);
  }

  setUp(() async {
    db = PennyDatabase(NativeDatabase.memory());
    service = TownService(
      db,
      Auth(MemoryCredentials()),
      FixedClock('2026-11-01'),
    );
    await service.createFamily('real', '719385', ['小满', '小禾']);
    child = service.auth.child('real', 'first');
    parent = await service.auth.unlock('real', 'first', '719385');
  });
  tearDown(() => db.close());

  test(
    'Pausing quick tasks blocks new instances while preserving old commitments',
    () async {
      await run('configureQuick', ['dishes', 200, '洗净餐具'], adult: true);
      final id = await run('quickSubmit', ['dishes']);
      await expectLater(
        run('setQuickEnabled', ['dishes', false]),
        throwsA(isA<RuleViolation>()),
      );
      await run('setQuickEnabled', ['dishes', false], adult: true);
      await run('requestChanges', [id, '擦干水槽'], adult: true);
      await run('quickSubmit', ['dishes']);
      await run('withdrawTask', [id]);
      await run('quickSubmit', ['dishes']);
      await run('approve', [id], adult: true);
      await run('pay', [id], adult: true);
      (service.clock as FixedClock).advance(1);
      await expectLater(
        run('quickSubmit', ['dishes']),
        throwsA(isA<RuleViolation>()),
      );
      final s = await service.account(child);
      expect(s.wallet, 200);
      expect(s.tasks.single.detail, '洗净餐具');
      expect(s.quickTasks.first.enabled, isFalse);
      expect(s.tasks.single.feedback, '擦干水槽');
    },
  );

  test(
    'Temporary tasks are editable before acceptance and retain accepted terms',
    () async {
      final id = await run('addTask', ['阅读', 500, '读一本书'], adult: true);
      await run('editTask', [id, '阅读与分享', 600, '读完并分享发现'], adult: true);
      await run('accept', [id]);
      await expectLater(
        run('editTask', [id, '降价', 100, '新标准'], adult: true),
        throwsA(isA<RuleViolation>()),
      );
      await expectLater(
        run('cancelTask', [id], adult: true),
        throwsA(isA<RuleViolation>()),
      );
      final unused = await run('addTask', ['额外小任务', 100, '先约好'], adult: true);
      await run('cancelTask', [unused], adult: true);
      await expectLater(run('accept', [unused]), throwsA(isA<RuleViolation>()));
      final s = await service.account(child);
      expect(s.tasks.first.amount, 600);
      expect(s.tasks.first.detail, '读完并分享发现');
      expect(s.tasks.last.status, 'cancelled');
      expect(s.ledger.where((l) => l.reference == unused).length, 2);
    },
  );

  test(
    'Wish edits, deletion, and archive retain history and require explicit next selection',
    () async {
      final a = await run('addWish', ['gift', '望远镜', 8000]);
      final b = await run('addWish', ['saving', '我的200元', 20000]);
      await run('editWish', [a, 'gift', '小望远镜', 9000]);
      expect((await service.account(child)).goalName, '小望远镜');
      await run('deleteWish', [b]);
      await expectLater(run('selectWish', [b]), throwsA(isA<RuleViolation>()));
      await run('archiveWish', [a]);
      expect((await service.account(child)).mainWish, isNull);
      final c = await run('addWish', ['saving', '新目标', 10000]);
      expect((await service.account(child)).mainWish!.id, c);
      final old = await db.rows(
        'SELECT status FROM wishes WHERE family_id=? AND child_id=? AND id=?',
        ['real', 'first', b],
      );
      expect(old.single['status'], 'deleted');
      expect((await db.load('real', 'second')).wishes, isEmpty);
    },
  );

  test(
    'A primary savings milestone preserves money and cannot be deleted or rewritten',
    () async {
      final id = await run('addWish', ['saving', '我的第一笔积累', 2000]);
      await expectLater(run('markSaved', [id]), throwsA(isA<RuleViolation>()));
      await earn(2000);
      final before = await service.account(child);
      await run('markSaved', [id]);
      final s = await service.account(child);
      expect(s.wallet, before.wallet);
      expect(s.withdrawn, 0);
      expect(s.mainWish, isNull);
      await expectLater(run('markSaved', [id]), throwsA(isA<RuleViolation>()));
      await expectLater(run('deleteWish', [id]), throwsA(isA<RuleViolation>()));
      await expectLater(
        run('editWish', [id, 'gift', '改写历史', 100]),
        throwsA(isA<RuleViolation>()),
      );
      final row = (await db.rows(
        'SELECT * FROM wishes WHERE family_id=? AND child_id=? AND id=?',
        ['real', 'first', id],
      )).single;
      expect(row['achieved_on'], '2026-11-01');
      expect(row['achieved_amount'], 2000);
      expect(s.ledger.where((l) => l.kind == 'wish-saved').length, 1);
    },
  );

  test(
    'Gift receipt links actual payments without duplicate debits or counting debt as savings',
    () async {
      final wish = await run('addWish', ['gift', '望远镜', 8000]);
      await earn(3200);
      final loan = await run('loanRequest', ['望远镜', 4800, 3, '2026-12-01']);
      await run('offerLoan', [loan, 3, '2026-12-01', 600], adult: true);
      await run('acceptLoan', [loan]);
      final withdrawal = await run('request', [3200, '望远镜自付']);
      await expectLater(
        run('receiveGift', [wish, withdrawal, loan, 8000], adult: true),
        throwsA(isA<RuleViolation>()),
      );
      await run('fundLoan', [loan], adult: true);
      await run('payRequest', [withdrawal], adult: true);
      await expectLater(
        run('receiveGift', [wish, withdrawal, loan, 8000]),
        throwsA(isA<RuleViolation>()),
      );
      await expectLater(
        run('markSaved', [wish]),
        throwsA(isA<RuleViolation>()),
      );
      await expectLater(
        run('receiveGift', [wish, withdrawal, loan, 7900], adult: true),
        throwsA(isA<RuleViolation>()),
      );
      await run('receiveGift', [wish, withdrawal, loan, 8000], adult: true);
      final s = await service.account(child);
      expect(s.wallet, 0);
      expect(s.withdrawn, 3200);
      expect(s.debt, 4848);
      expect(s.laborTotal, 3200);
      expect(s.mainWish, isNull);
      expect(s.ledger.where((l) => l.kind == 'withdraw').length, 1);
      expect(s.ledger.where((l) => l.kind == 'loan-funded').length, 1);
      final second = await run('addWish', ['gift', '另一个礼物', 8000]);
      await expectLater(
        run('receiveGift', [second, withdrawal, loan, 8000], adult: true),
        throwsA(isA<RuleViolation>()),
      );
      await expectLater(
        run('deleteWish', [wish]),
        throwsA(isA<RuleViolation>()),
      );
      await run('archiveWish', [wish]);
      expect((await service.account(child)).debt, 4848);
      expect(
        (await db.rows(
          'SELECT * FROM wishes WHERE id=? AND family_id=? AND child_id=?',
          [wish, 'real', 'first'],
        )).single['received_on'],
        '2026-11-01',
      );
    },
  );

  test(
    'Schema 3 upgrade retains balances, ledger, wish lifecycle, and task deactivation',
    () async {
      final dir = await Directory.systemTemp.createTemp('pennywood-family-v3-');
      final file = File('${dir.path}/save.sqlite');
      final old = _VersionThreeDatabase(NativeDatabase(file));
      await old.customStatement(
        "INSERT INTO families VALUES('real',0,'first','2026-11-01')",
      );
      await old.customStatement(
        "INSERT INTO children VALUES('real','first','小满','2026-11-01',2000,2000,0,0,0,0,0,1,2,'cash',2000,'我的积累',0)",
      );
      await old.customStatement(
        "INSERT INTO wishes VALUES('real','first','old-wish','我的积累','saving',2000,1)",
      );
      await old.customStatement(
        "INSERT INTO ledger VALUES('real','first','income-1','2026-11-01','income','原有收入',2000,'task-1','original-operation','parent')",
      );
      await old.close();
      final upgraded = PennyDatabase.file(file);
      final auth = Auth(credentials);
      await auth.create('real', '843721');
      final svc = TownService(upgraded, auth, FixedClock('2026-11-01'));
      final access = auth.child('real', 'first');
      await svc.execute(access, 'save', 'markSaved', ['old-wish']);
      await upgraded.close();
      final reopened = PennyDatabase.file(file);
      try {
        final s = await reopened.load('real', 'first');
        expect(s.wallet, 2000);
        expect(s.ledger.first.operationId, 'original-operation');
        expect(s.mainWish, isNull);
        expect(
          (await reopened.rows(
            'SELECT achieved_amount FROM wishes',
          )).single['achieved_amount'],
          2000,
        );
        expect(await reopened.rows('PRAGMA foreign_key_check'), isEmpty);
        expect(
          (await reopened.rows('PRAGMA user_version')).single.values.single,
          PennyDatabase.version,
        );
        final before = _VersionThreeDatabase(
          NativeDatabase(File('${file.path}.before-v3.sqlite')),
        );
        try {
          expect(
            (await before.rows('PRAGMA user_version')).single.values.single,
            3,
          );
          expect(
            (await before.rows('SELECT wallet FROM children')).single['wallet'],
            2000,
          );
          expect(
            (await before.rows(
              'SELECT COUNT(*) AS count FROM ledger',
            )).single['count'],
            1,
          );
        } finally {
          await before.close();
        }
      } finally {
        await reopened.close();
        await dir.delete(recursive: true);
      }
    },
  );
}

class _VersionThreeDatabase extends PennyDatabase {
  _VersionThreeDatabase(super.executor);
  @override
  int get schemaVersion => 3;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final sql in [
        ...PennyDatabase.schema,
        ...PennyDatabase.wishboardSchema,
      ]) {
        await customStatement(sql);
      }
    },
  );
}
