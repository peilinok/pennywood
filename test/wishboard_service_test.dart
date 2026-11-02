import 'dart:io';
import 'package:drift/drift.dart';
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
  late FixedClock clock;
  late Access child, parent;
  setUp(() async {
    db = PennyDatabase(NativeDatabase.memory());
    clock = FixedClock('2026-11-01');
    service = TownService(db, Auth(MemoryCredentials()), clock);
    await service.createFamily('real', '719385', ['小满', '小禾']);
    child = service.auth.child('real', 'first');
    parent = await service.auth.unlock('real', 'first', '719385');
  });
  tearDown(() => db.close());
  Future<String> execute(
    String op,
    String action,
    List<Object?> args, {
    bool asParent = false,
  }) async =>
      await service.execute(asParent ? parent : child, op, action, args) ?? '';
  Future<void> configure() => execute('config', 'configureQuick', [
    'dishes',
    200,
    '洗净餐具，擦干水槽',
  ], asParent: true);

  test(
    'Real families have no demo wishes, pay, or principal; parents save agreements',
    () async {
      final s = await service.account(child);
      expect(s.assets, 0);
      expect(s.wishes, isEmpty);
      expect(s.tasks, isEmpty);
      expect(s.quickTasks.every((q) => !q.enabled && q.amount == 0), isTrue);
      await expectLater(
        execute('unconfigured', 'quickSubmit', ['dishes']),
        throwsA(isA<RuleViolation>()),
      );
      await expectLater(
        execute('forged', 'configureQuick', ['dishes', 200, '洗净']),
        throwsA(isA<RuleViolation>()),
      );
      await configure();
      expect((await service.account(child)).quickTasks.first.enabled, isTrue);
    },
  );

  test(
    'Quick submissions, retries, withdrawal, rework, and two-step payment never double-credit',
    () async {
      await configure();
      final id = await execute('submit', 'quickSubmit', ['dishes']);
      expect((await service.account(child)).wallet, 0);
      await execute('submit', 'quickSubmit', [
        'dishes',
      ]); // Idempotent for the same operation ID
      await expectLater(
        execute('double-tap', 'quickSubmit', ['dishes']),
        throwsA(isA<RuleViolation>()),
      );
      await execute('withdraw', 'withdrawTask', [id]);
      await execute('resubmit', 'quickSubmit', ['dishes']);
      await execute('feedback', 'requestChanges', [
        id,
        '水槽边再擦一下',
      ], asParent: true);
      expect((await service.account(child)).tasks.single.feedback, '水槽边再擦一下');
      await execute('improved', 'quickSubmit', ['dishes']);
      await execute('checked', 'approve', [id], asParent: true);
      expect((await service.account(child)).wallet, 0);
      await expectLater(
        execute('too-late', 'withdrawTask', [id]),
        throwsA(isA<RuleViolation>()),
      );
      await expectLater(
        execute('child-pay', 'pay', [id]),
        throwsA(isA<RuleViolation>()),
      );
      await execute('paid', 'pay', [id], asParent: true);
      await execute('paid', 'pay', [id], asParent: true);
      final s = await service.account(child);
      expect(s.wallet, 200);
      expect(s.tasks.length, 1);
      expect(s.ledger.where((l) => l.kind == 'income').length, 1);
      expect(s.ledger.last.actorRole, 'parent');
      await expectLater(
        execute('same-day', 'quickSubmit', ['dishes']),
        throwsA(isA<RuleViolation>()),
      );
      expect((await db.load('real', 'second')).wallet, 0);
    },
  );

  test(
    'Pending prior-day tasks survive; agreement changes affect only new instances',
    () async {
      await configure();
      final id = await execute('submit', 'quickSubmit', ['dishes']);
      clock.advance(1);
      await execute('changed', 'configureQuick', [
        'dishes',
        300,
        '新标准',
      ], asParent: true);
      await expectLater(
        execute('overnight', 'quickSubmit', ['dishes']),
        throwsA(isA<RuleViolation>()),
      );
      final old = (await service.account(child)).tasks.single;
      expect(old.amount, 200);
      expect(old.detail, '洗净餐具，擦干水槽');
      await execute('check', 'approve', [id], asParent: true);
      await execute('pay', 'pay', [id], asParent: true);
      final next = await execute('next', 'quickSubmit', ['dishes']);
      expect(next, isNot(id));
      final s = await service.account(child);
      expect(s.tasks.last.amount, 300);
      expect(s.tasks.last.businessDay, '2026-11-02');
      expect(s.wallet, 200);
    },
  );

  test(
    'Failed task saves roll back the transaction and retries retain one instance',
    () async {
      await configure();
      await db.customStatement(
        "CREATE TRIGGER fail_quick BEFORE INSERT ON operations WHEN NEW.id='retry' BEGIN SELECT RAISE(ABORT,'模拟失败'); END",
      );
      await expectLater(
        execute('retry', 'quickSubmit', ['dishes']),
        throwsA(anything),
      );
      expect((await service.account(child)).tasks, isEmpty);
      await db.customStatement('DROP TRIGGER fail_quick');
      await execute('retry', 'quickSubmit', ['dishes']);
      expect((await service.account(child)).tasks.length, 1);
    },
  );

  test(
    'One primary wish per child; switching never duplicates balances or affects siblings',
    () async {
      final a = await execute('wish1', 'addWish', ['gift', '望远镜', 8000]);
      final b = await execute('wish2', 'addWish', ['saving', '我的200元', 20000]);
      var s = await service.account(child);
      expect(s.mainWish!.id, a);
      expect(s.wishes.where((w) => w.isMain).length, 1);
      await execute('main', 'selectWish', [b]);
      s = await service.account(child);
      expect(s.mainWish!.id, b);
      expect(s.goalName, '我的200元');
      expect(s.goal, 20000);
      expect(s.assets, 0);
      expect((await db.load('real', 'second')).wishes, isEmpty);
      await expectLater(
        service.execute(
          service.auth.child('real', 'second'),
          'cross',
          'selectWish',
          [a],
        ),
        throwsA(isA<RuleViolation>()),
      );
      await expectLater(
        execute('zero', 'addWish', ['gift', '新心愿', 0]),
        throwsA(isA<RuleViolation>()),
      );
      expect((await service.account(child)).wishes.length, 2);
    },
  );

  test(
    'Migration from v2 to v3 and file reopen retain ledger, wishes, tasks, and feedback',
    () async {
      final dir = await Directory.systemTemp.createTemp('pennywood-v2-');
      final file = File('${dir.path}/save.sqlite');
      final old = VersionTwoDatabase(NativeDatabase(file));
      await old.customStatement(
        "INSERT INTO families VALUES('legacy',0,'first','2026-11-01')",
      );
      await old.customStatement(
        "INSERT INTO children VALUES('legacy','first','旧档案','2026-11-01',800,800,0,0,0,0,0,1,1,'cash',9000,'旧心愿',0)",
      );
      await old.customStatement(
        "INSERT INTO tasks VALUES('legacy','first','books','整理图书','按约定整理',800,'paid')",
      );
      await old.customStatement(
        "INSERT INTO ledger VALUES('legacy','first','old-income','2026-11-01','income','旧劳动',800,'books','old-pay','parent')",
      );
      await old.close();
      final upgraded = PennyDatabase.file(file);
      final credentials = MemoryCredentials();
      final auth = Auth(credentials);
      await auth.create('legacy', '719385');
      final svc = TownService(upgraded, auth, clock);
      final p = await auth.unlock('legacy', 'first', '719385');
      final a = auth.child('legacy', 'first');
      await svc.execute(p, 'configure', 'configureQuick', [
        'dishes',
        200,
        '洗干净',
      ]);
      final id = await svc.execute(a, 'quick', 'quickSubmit', ['dishes']);
      await svc.execute(p, 'feedback', 'requestChanges', [id, '再擦干水槽']);
      await svc.execute(a, 'new-wish', 'addWish', ['saving', '新心愿', 10000]);
      await upgraded.close();
      final reopened = PennyDatabase.file(file);
      try {
        final s = await reopened.load('legacy', 'first');
        expect(s.wallet, 800);
        expect(s.mainWish!.name, '旧心愿');
        expect(s.wishes.length, 2);
        expect(s.tasks.last.feedback, '再擦干水槽');
        expect(s.tasks.last.status, 'needsWork');
        expect(s.quickTasks.single.amount, 200);
        expect(s.ledger.first.operationId, 'old-pay');
        expect(
          (await reopened.rows('PRAGMA user_version')).single.values.single,
          PennyDatabase.version,
        );
        expect(await reopened.rows('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        await reopened.close();
        await dir.delete(recursive: true);
      }
    },
  );
}

class VersionTwoDatabase extends PennyDatabase {
  VersionTwoDatabase(super.executor);
  @override
  int get schemaVersion => 2;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final sql in PennyDatabase.schema) {
        await customStatement(sql);
      }
    },
  );
}
