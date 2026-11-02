import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/model.dart';
import 'package:pennywood/domain/money.dart';

class MemoryCredentials implements CredentialStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

Future<void> addLegacyTasks(PennyDatabase db, String family) async {
  for (final id in ['first', 'second']) {
    final s = await db.load(family, id);
    s.tasks.add(LaborTask(id: 'books', name: '给书架来次大整理', amount: 800));
    await db.save(family, s);
  }
}

void main() {
  // Concurrent instances use separate in-memory databases or temporary files, never shared connections.
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  late PennyDatabase db;
  late Auth auth;
  late TownService service;
  late FixedClock clock;
  late MemoryCredentials credentials;
  setUp(() async {
    credentials = MemoryCredentials();
    db = PennyDatabase(NativeDatabase.memory());
    auth = Auth(credentials);
    clock = FixedClock('2026-10-31');
    service = TownService(db, auth, clock);
    await service.createFamily('real', '719385', ['小满', '小禾']);
    await addLegacyTasks(db, 'real');
  });
  tearDown(() async => db.close());
  Future<void> submit() async {
    final child = auth.child('real', 'first');
    await service.execute(child, 'accept', 'accept', ['books']);
    await service.execute(child, 'submit', 'submit', ['books']);
  }

  test(
    'Strict iOS-equivalent SQLite string mode creates the complete schema',
    () async {
      final strict = PennyDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.config.doubleQuotedStringLiterals = false;
          },
        ),
      );
      try {
        expect(
          (await strict.rows(
            'SELECT COUNT(*) AS count FROM families',
          )).single['count'],
          0,
        );
      } finally {
        await strict.close();
      }
    },
  );
  test(
    'Reopening after partial initial setup leaves no incomplete schema',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'pennywood-schema-failure-',
      );
      final file = File('${dir.path}/save.sqlite');
      final broken = FailingSchemaDatabase(NativeDatabase(file));
      await expectLater(
        broken.rows('SELECT * FROM families'),
        throwsA(anything),
      );
      await broken.close();
      final reopened = PennyDatabase.file(file);
      try {
        expect(await reopened.rows('SELECT * FROM families'), isEmpty);
      } finally {
        await reopened.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'Zero-balance setup, real-work flow, parent authority, and repeated payment',
    () async {
      final child = auth.child('real', 'first');
      expect((await service.account(child)).assets, 0);
      expect((await service.account(child)).budget, 0);
      await submit();
      expect((await service.account(child)).wallet, 0);
      await expectLater(
        service.execute(child, 'approve', 'approve', ['books']),
        throwsA(isA<RuleViolation>()),
      );
      await expectLater(
        auth.unlock('real', 'first', '000000'),
        throwsA(isA<RuleViolation>()),
      );
      final parent = await auth.unlock('real', 'first', '719385');
      await service.execute(parent, 'approve', 'approve', ['books']);
      expect((await service.account(child)).wallet, 0);
      await service.execute(parent, 'pay', 'pay', ['books']);
      await service.execute(parent, 'pay', 'pay', ['books']);
      final saved = await service.account(child);
      expect(saved.wallet, 800);
      expect(saved.laborTotal, 800);
      expect(saved.ledger.last.operationId, 'pay');
      expect(saved.ledger.last.actorRole, 'parent');
      expect(saved.ledger.where((l) => l.kind == 'income').length, 1);
      await expectLater(
        service.execute(parent, 'pay-again', 'pay', ['books']),
        throwsA(isA<RuleViolation>()),
      );
      await expectLater(
        service.execute(parent, 'pay', 'settings', [0, 0, '小满']),
        throwsA(isA<RuleViolation>()),
      );
      expect((await db.load('real', 'second')).wallet, 0);
      auth.lock();
      await expectLater(
        service.execute(parent, 'settings', 'settings', [5000, 300, '小满']),
        throwsA(isA<RuleViolation>()),
      );
      expect(credentials.values.values.single, isNot(contains('719385')));
    },
  );
  test(
    'Failed database writes roll back wallet, state, ledger, and operations; retry is safe',
    () async {
      await submit();
      final parent = await auth.unlock('real', 'first', '719385');
      await service.execute(parent, 'approve', 'approve', ['books']);
      await db.customStatement(
        "CREATE TRIGGER fail_operation BEFORE INSERT ON operations WHEN NEW.id='storage-failure' BEGIN SELECT RAISE(ABORT,'模拟磁盘写入失败'); END",
      );
      await expectLater(
        service.execute(parent, 'storage-failure', 'pay', ['books']),
        throwsA(anything),
      );
      final s = await db.load('real', 'first');
      expect(s.wallet, 0);
      expect(s.tasks.first.status, 'confirmed');
      expect(s.ledger.where((l) => l.kind == 'income'), isEmpty);
      expect(
        await db.rows('SELECT * FROM operations WHERE id=?', [
          'storage-failure',
        ]),
        isEmpty,
      );
      await db.customStatement('DROP TRIGGER fail_operation');
      await service.execute(parent, 'storage-failure', 'pay', ['books']);
      expect((await db.load('real', 'first')).wallet, 800);
    },
  );
  test(
    'Conflicting ledger IDs for one business event roll back instead of ignoring uniqueness',
    () async {
      final s = await db.load('real', 'first');
      s.wallet = 800;
      s.laborTotal = 800;
      s.ledger.add(
        LedgerEntry('income-1', clock.today, 'income', '首笔兑现', 800, 'books'),
      );
      await db.save('real', s);
      final duplicate = await db.load('real', 'first');
      duplicate.wallet += 800;
      duplicate.laborTotal += 800;
      duplicate.ledger.add(
        LedgerEntry('income-2', clock.today, 'income', '重复兑现', 800, 'books'),
      );
      await expectLater(
        db.transaction(() => db.save('real', duplicate)),
        throwsA(anything),
      );
      expect((await db.load('real', 'first')).wallet, 800);
    },
  );
  test('Concurrent repeated taps pay exactly once', () async {
    await submit();
    final p = await auth.unlock('real', 'first', '719385');
    await service.execute(p, 'approve', 'approve', ['books']);
    final results = await Future.wait([
      for (final id in ['pay-a', 'pay-b'])
        service
            .execute(p, id, 'pay', ['books'])
            .then((_) => true)
            .catchError((Object e) => false),
    ]);
    expect(results.where((r) => r).length, 1);
    expect((await db.load('real', 'first')).wallet, 800);
  });
  test(
    'Children, demo families, scene state, and footprints persist separately',
    () async {
      await service.createFamily('demo', '564819', ['示例甲', '示例乙'], demo: true);
      final a = auth.child('real', 'first'), b = auth.child('real', 'second');
      await service.scene(
        a,
        SceneState(
          x: 340,
          y: 390,
          evening: true,
          zoom: 1.3,
          visited: {'tasks'},
        ),
      );
      expect((await db.loadScene('real', 'first')).visited, {'tasks'});
      expect((await db.loadScene('real', 'second')).visited, isEmpty);
      expect((await service.account(b)).assets, 0);
      expect((await db.load('demo', 'first')).assets, 20000);
      await service.execute(a, 'first-only', 'accept', ['books']);
      expect((await db.load('real', 'second')).tasks.first.status, 'available');
      expect((await db.load('demo', 'first')).tasks.first.status, 'available');
    },
  );
  test(
    'Resume catches up three periods without duplicate settlements or automatic repayment',
    () async {
      await service.createFamily('demo', '564819', ['示例甲', '示例乙'], demo: true);
      final a = auth.child('demo', 'first');
      await service.execute(a, 'deposit', 'buy', [
        'dividend',
        10000,
        'reinvest',
      ]);
      clock.advance(90);
      await service.restore('demo');
      final s = await db.load('demo', 'first');
      expect(s.holding, 10075);
      expect(s.wallet, 10000);
      expect(s.bonusEarned, 75);
      expect(s.active.single.start, '2027-01-29');
      final count = s.ledger.length;
      await service.restore('demo');
      expect((await db.load('demo', 'first')).ledger.length, count);
    },
  );
  test(
    'Reverting a changed rate still requires confirmation before renewal',
    () async {
      await service.createFamily('demo', '564819', ['示例甲', '示例乙'], demo: true);
      final a = auth.child('demo', 'first'),
          p = await auth.unlock('demo', 'first', '564819');
      await service.execute(a, 'deposit', 'buy', ['dividend', 10000, 'cash']);
      await service.execute(p, 'up', 'settings', [5000, 500, '示例甲']);
      await service.execute(p, 'back', 'settings', [5000, 300, '示例甲']);
      clock.advance(30);
      await service.restore('demo');
      final s = await db.load('demo', 'first');
      expect(s.holding, 0);
      expect(s.wallet, 20025);
    },
  );
  test(
    'File reopen retains CNY 8, ledger, scene, and schema version',
    () async {
      final dir = await Directory.systemTemp.createTemp('pennywood-restart-');
      final file = File('${dir.path}/save.sqlite');
      final disk = PennyDatabase.file(file);
      final svc = TownService(disk, Auth(credentials), clock);
      await svc.createFamily('disk', '416973', ['甲', '乙']);
      await addLegacyTasks(disk, 'disk');
      final a = svc.auth.child('disk', 'first');
      final p = await svc.auth.unlock('disk', 'first', '416973');
      for (final action in ['accept', 'submit', 'approve', 'pay']) {
        await svc.execute(
          ['approve', 'pay'].contains(action) ? p : a,
          action,
          action,
          ['books'],
        );
      }
      await svc.scene(
        a,
        SceneState(x: 360, y: 410, visited: {'savings', 'tasks'}),
      );
      await disk.close();
      final reopened = PennyDatabase.file(file);
      final again = TownService(reopened, Auth(credentials), clock);
      await again.restore('disk');
      expect((await reopened.load('disk', 'first')).wallet, 800);
      expect(
        (await reopened.load(
          'disk',
          'first',
        )).ledger.where((l) => l.kind == 'income').length,
        1,
      );
      final scene = await reopened.loadScene('disk', 'first');
      expect(scene.x, 360);
      expect(scene.visited, {'savings', 'tasks'});
      expect(
        (await reopened.rows('PRAGMA user_version')).single.values.single,
        PennyDatabase.version,
      );
      await reopened.close();
      await dir.delete(recursive: true);
    },
  );
  test(
    'Migration from v1 to v3 retains balances, wishes, and ledger ownership',
    () async {
      final dir = await Directory.systemTemp.createTemp('pennywood-migration-');
      final file = File('${dir.path}/v1.sqlite');
      final old = VersionOneDatabase(NativeDatabase(file));
      await old.customStatement(
        "INSERT INTO families VALUES('legacy',0,'first','2026-10-31')",
      );
      await old.customStatement(
        "INSERT INTO children VALUES('legacy','first','旧档案','2026-10-31',800,800,0,0,0,0,0,1,0,'cash',19800,'旧心愿',0)",
      );
      await old.customStatement(
        "INSERT INTO ledger(family_id,child_id,id,date,kind,title,amount,reference_id) VALUES('legacy','first','paid','2026-10-31','income','旧劳动报酬',800,'books')",
      );
      await old.close();
      final upgraded = PennyDatabase.file(file);
      final s = await upgraded.load('legacy', 'first');
      expect(s.wallet, 800);
      expect(s.ledger.single.amount, 800);
      expect(s.ledger.single.operationId, 'legacy');
      expect(
        (await upgraded.rows('PRAGMA user_version')).single.values.single,
        PennyDatabase.version,
      );
      await upgraded.close();
      await dir.delete(recursive: true);
    },
  );
}

class VersionOneDatabase extends PennyDatabase {
  VersionOneDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final sql in PennyDatabase.schema) {
        await customStatement(
          sql.replaceAll(
            ", operation_id TEXT NOT NULL DEFAULT 'legacy', actor_role TEXT NOT NULL DEFAULT 'legacy'",
            '',
          ),
        );
      }
    },
  );
}

class FailingSchemaDatabase extends PennyDatabase {
  FailingSchemaDatabase(super.executor);
  @override
  List<String> get creationStatements => [
    ...PennyDatabase.schema.take(3),
    '刻意注入建表错误',
  ];
}
