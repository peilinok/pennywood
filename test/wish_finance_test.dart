import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show MigrationStrategy, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/backup.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/money.dart';
import 'database_service_test.dart' show MemoryCredentials;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  late PennyDatabase db;
  late TownService svc;
  late Access child, parent;
  var sequence = 0;
  Future<String> run(
    String action,
    List<Object?> args, {
    bool adult = false,
  }) async =>
      await svc.execute(
        adult ? parent : child,
        'wf-${++sequence}',
        action,
        args,
      ) ??
      '';
  Future<void> earn(int amount) async {
    final id = await run('addTask', ['现实劳动', amount, '先约定再完成'], adult: true);
    for (final action in ['accept', 'submit', 'approve', 'pay']) {
      await run(action, [id], adult: ['approve', 'pay'].contains(action));
    }
  }

  Future<String> paid(int amount, [String? wish]) async {
    final id = await run('request', [amount, '自付', wish]);
    await run('payRequest', [id], adult: true);
    return id;
  }

  Future<String> funded(int amount, [String? wish]) async {
    final id = await run('loanRequest', [
      '礼物垫付',
      amount,
      3,
      '2026-12-01',
      wish,
    ]);
    await run('offerLoan', [id, 3, '2026-12-01', 600], adult: true);
    await run('acceptLoan', [id]);
    await run('fundLoan', [id], adult: true);
    return id;
  }

  setUp(() async {
    db = PennyDatabase(NativeDatabase.memory());
    svc = TownService(db, Auth(MemoryCredentials()), FixedClock('2026-11-01'));
    await svc.createFamily('real', '719385', ['小满', '小禾']);
    child = svc.auth.child('real', 'first');
    parent = await svc.auth.unlock('real', 'first', '719385');
  });
  tearDown(() => db.close());

  test(
    'Gift-linked requests preserve actual delivery and prevent deletion or type changes',
    () async {
      final wish = await run('addWish', ['gift', '望远镜', 8000]);
      await earn(2000);
      final request = await run('request', [2000, '自付', wish]);
      await expectLater(
        run('deleteWish', [wish]),
        throwsA(isA<RuleViolation>()),
      );
      await expectLater(
        run('editWish', [wish, 'saving', '改类型', 8000]),
        throwsA(isA<RuleViolation>()),
      );
      await run('archiveWish', [wish]);
      await run('payRequest', [request], adult: true);
      final rows = await db.rows('SELECT * FROM wish_withdrawals');
      expect(rows.single['wish_id'], wish);
      expect(rows.single['withdrawal_id'], request);
      expect(rows.single['received'], 0);
      expect((await svc.account(child)).withdrawn, 2000);
    },
  );

  test(
    'Invalid savings, archived, or cross-child wish links leave cash and requests unchanged',
    () async {
      final saving = await run('addWish', ['saving', '攒钱', 5000]);
      final archived = await run('addWish', ['gift', '旧礼物', 5000]);
      await run('archiveWish', [archived]);
      final other = svc.auth.child('real', 'second');
      // The other child local identifier does not exist in the selected child scope.
      await db.customStatement(
        "UPDATE children SET sequence=100 WHERE id='second'",
      );
      final foreign = await svc.execute(other, 'other-wish', 'addWish', [
        'gift',
        '另一孩',
        5000,
      ]);
      await earn(2000);
      final before = await svc.account(child);
      for (final id in [saving, archived, foreign]) {
        await expectLater(
          run('request', [1000, '错误关联', id]),
          throwsA(isA<RuleViolation>()),
        );
        await expectLater(
          run('loanRequest', ['错误关联', 1000, 3, '2026-12-01', id]),
          throwsA(isA<RuleViolation>()),
        );
      }
      final after = await svc.account(child);
      expect(after.wallet, before.wallet);
      expect(after.ledger.length, before.ledger.length);
      expect(after.requests, isEmpty);
      expect(after.loans, isEmpty);
    },
  );

  test(
    'Two withdrawals and an advance form an idempotent gift receipt without erasing debt',
    () async {
      final wish = await run('addWish', ['gift', '望远镜', 8000]);
      await earn(3200);
      final a = await paid(2000, wish), b = await paid(1200, wish);
      final loan = await funded(4800, wish);
      final before = await svc.account(child);
      final args = [
        wish,
        [a, b],
        [loan],
        8000,
      ];
      await svc.execute(parent, 'receipt', 'receiveGift', args);
      await svc.execute(parent, 'receipt', 'receiveGift', args);
      await expectLater(
        run('receiveGift', args, adult: true),
        throwsA(isA<RuleViolation>()),
      );
      final s = await svc.account(child);
      expect(s.wallet, before.wallet);
      expect(s.withdrawn, 3200);
      expect(s.laborTotal, 3200);
      expect(s.debt, 4848);
      expect(s.wishes.single.receivedCost, 8000);
      expect(s.wishes.single.achievedOn, isNull);
      expect(s.ledger.where((l) => l.kind == 'wish-received').length, 1);
      expect(
        (await db.rows(
          'SELECT * FROM wish_withdrawals WHERE received=1',
        )).length,
        2,
      );
      expect(
        (await db.rows('SELECT * FROM wish_loans WHERE received=1')).length,
        1,
      );
      expect(await db.rows('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'Duplicate, undelivered, mismatched, or cross-child payments fail without consuming records',
    () async {
      final wish = await run('addWish', ['gift', '望远镜', 8000]);
      final otherWish = await run('addWish', ['gift', '画具', 2000]);
      await earn(4000);
      final a = await paid(1000), b = await paid(1000, otherWish);
      final pending = await run('request', [1000, '未交付', wish]);
      final loan = await run('loanRequest', [
        '未垫付',
        1000,
        3,
        '2026-12-01',
        wish,
      ]);
      final other = svc.auth.child('real', 'second');
      final otherParent = await svc.auth.unlock('real', 'second', '719385');
      await svc.execute(otherParent, 'foreign-task', 'addTask', [
        '另一孩劳动',
        1000,
        '先约定',
      ]);
      final task = (await svc.account(other)).tasks.single.id;
      for (final action in ['accept', 'submit', 'approve', 'pay']) {
        await svc.execute(
          ['approve', 'pay'].contains(action) ? otherParent : other,
          'foreign-$action',
          action,
          [task],
        );
      }
      final foreign = await svc.execute(other, 'foreign-request', 'request', [
        1000,
        '另一孩自付',
      ]);
      await svc.execute(otherParent, 'foreign-paid', 'payRequest', [foreign]);
      final before = await svc.account(child);
      for (final args in <List<Object?>>[
        [
          wish,
          [a, a],
          [],
          2000,
        ],
        [
          wish,
          [a, pending],
          [],
          2000,
        ],
        [
          wish,
          [a, b],
          [],
          2000,
        ],
        [
          wish,
          [a],
          [],
          900,
        ],
        [
          wish,
          [a],
          [loan],
          2000,
        ],
        [
          wish,
          [a, foreign],
          [],
          2000,
        ],
      ]) {
        await expectLater(
          run('receiveGift', args, adult: true),
          throwsA(isA<RuleViolation>()),
        );
      }
      final after = await svc.account(child);
      expect(after.wallet, before.wallet);
      expect(after.ledger.length, before.ledger.length);
      expect(
        await db.rows('SELECT * FROM wish_withdrawals WHERE received=1'),
        isEmpty,
      );
      // After failure, a parent can still explicitly associate unbound historical payments with the gift.
      await run('receiveGift', [
        wish,
        [a],
        [],
        1000,
      ], adult: true);
      await expectLater(
        run('receiveGift', [
          otherWish,
          [a],
          [],
          1000,
        ], adult: true),
        throwsA(isA<RuleViolation>()),
      );
    },
  );

  test(
    'Historical and new advances may combine while receipt and debt remain separate',
    () async {
      final wish = await run('addWish', ['gift', '画具套装', 3000]);
      await earn(1000);
      final old = await funded(1000, wish);
      await expectLater(
        run('loanRequest', ['并发预支', 1000, 3, '2026-12-01', wish]),
        throwsA(isA<RuleViolation>()),
      );
      await run('repayment', [old, 'settle']);
      final next = await funded(2000, wish);
      await run('receiveGift', [
        wish,
        [],
        [old, next],
        3000,
      ], adult: true);
      final s = await svc.account(child);
      expect(s.wallet, 0);
      expect(s.repaidTotal, 1000);
      expect(s.debt, 2020);
      expect(s.wishes.single.receivedCost, 3000);
      await run('archiveWish', [wish]);
      expect((await svc.account(child)).debt, 2020);
    },
  );

  test(
    'Schema4 encrypted restore preserves multi-payment links, debt, and operations on re-export',
    () async {
      const password = 'schema4-fixture-password';
      final backup = FamilyBackup(db, svc.auth);
      final bytes = await File(
        'test/fixtures/backup-schema4.json',
      ).readAsBytes();
      expect(
        jsonDecode(utf8.decode(bytes))['format'],
        'Pennywood-encrypted-backup:1:schema4',
      );
      final old = await backup.read(bytes, password);
      final fresh = PennyDatabase(NativeDatabase.memory());
      final auth = Auth(MemoryCredentials());
      try {
        final target = FamilyBackup(fresh, auth);
        await target.restore(old, newPin: '843721');
        final s = await fresh.load('real', 'first');
        expect(s.wishes.single.receivedCost, 8000);
        expect(s.debt, 4848);
        expect(
          (await fresh.rows(
            'SELECT * FROM wish_withdrawals',
          )).single['received'],
          1,
        );
        expect(
          (await fresh.rows('SELECT * FROM wish_loans')).single['received'],
          1,
        );
        final access = await auth.unlock('real', 'first', '843721');
        final newBytes = await target.export(access, password);
        expect(
          jsonDecode(utf8.decode(newBytes))['format'],
          'Pennywood-encrypted-backup:1:schema6',
        );
        final upgraded = await target.read(newBytes, password);
        await target.restore(
          upgraded,
          access: access,
          preserveBefore: (_) async => '独立验收副本',
        );
        expect((await fresh.load('real', 'first')).debt, 4848);
        expect(await fresh.rows('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        await fresh.close();
      }
    },
  );

  test(
    'Composite foreign keys reject cross-child/orphan links and unique keys prevent reuse',
    () async {
      final wish = await run('addWish', ['gift', '画具', 1000]);
      final second = await run('addWish', ['gift', '另一个', 1000]);
      await earn(1000);
      final request = await paid(1000, wish);
      for (final values in [
        ['real', 'first', second, request, 0],
        ['real', 'second', wish, request, 0],
        ['real', 'first', wish, 'missing', 0],
      ]) {
        await expectLater(
          db.customStatement(
            'INSERT INTO wish_withdrawals VALUES(?,?,?,?,?)',
            values,
          ),
          throwsException,
        );
      }
      expect((await db.rows('SELECT * FROM wish_withdrawals')).length, 1);
    },
  );

  test(
    'Multi-payment backup round trips reject mismatched amounts and forged receipts',
    () async {
      final wish = await run('addWish', ['gift', '画具', 3000]);
      await earn(3000);
      final a = await paid(1000, wish), b = await paid(2000);
      final backup = FamilyBackup(db, svc.auth);
      const password = 'wish-payment-backup-password';
      final pending = await backup.read(
        await backup.export(parent, password),
        password,
      );
      expect(pending.entries, (await svc.account(child)).ledger.length);
      await run('receiveGift', [
        wish,
        [a, b],
        [],
        3000,
      ], adult: true);
      final verified = await backup.read(
        await backup.export(parent, password),
        password,
      );
      final fresh = PennyDatabase(NativeDatabase.memory());
      try {
        await FamilyBackup(
          fresh,
          Auth(MemoryCredentials()),
        ).restore(verified, newPin: '843721');
        final s = await fresh.load('real', 'first');
        expect(s.requests.length, 2);
        expect(
          s.requests.every((r) => r.wishId == wish && r.usedForGift),
          isTrue,
        );
        expect(s.wishes.single.receivedCost, 3000);
        expect(s.withdrawn, 3000);
      } finally {
        await fresh.close();
      }
      // Reject business-inconsistent archives even when cryptographic integrity is valid.
      await db.customStatement('UPDATE wishes SET received_cost=2999');
      await expectLater(
        backup.read(await backup.export(parent, password), password),
        throwsA(isA<RuleViolation>()),
      );
      await db.customStatement(
        'UPDATE wishes SET received_cost=0,received_on=NULL',
      );
      await expectLater(
        backup.read(await backup.export(parent, password), password),
        throwsA(isA<RuleViolation>()),
      );
    },
  );

  test(
    'Schema4 file migration converts legacy payment links and retains snapshots on reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('pennywood-wish-v4-');
      final file = File('${dir.path}/save.sqlite');
      final old = _VersionFourDatabase(NativeDatabase(file));
      await old.customStatement(
        "INSERT INTO families(id,demo,active_child,created,global_id) VALUES('real',0,'first','2026-11-01','0123456789abcdef0123456789abcdef')",
      );
      await old.customStatement(
        "INSERT INTO children VALUES('real','first','小满','2026-11-01',0,2000,0,2000,0,0,0,1,4,'cash',0,'',0)",
      );
      await old.customStatement(
        "INSERT INTO withdrawals VALUES('real','first','paid-1',2000,'自付','2026-11-01','paid')",
      );
      await old.customStatement(
        "INSERT INTO wishes(family_id,child_id,id,name,kind,target,is_main,received_on,withdrawal_id,received_cost) VALUES('real','first','old-wish','画具','gift',2000,0,'2026-11-01','paid-1',2000)",
      );
      await old.customStatement(
        "INSERT INTO ledger VALUES('real','first','history-1','2026-11-01','withdraw','旧交付',2000,'paid-1','old-op','parent')",
      );
      await old.close();
      final upgraded = PennyDatabase.file(file);
      try {
        expect(
          (await upgraded.rows('PRAGMA user_version')).single.values.single,
          6,
        );
        expect(
          (await upgraded.rows(
            'SELECT * FROM wish_withdrawals',
          )).single['received'],
          1,
        );
        final s = await upgraded.load('real', 'first');
        s.check();
        expect(s.wallet, 0);
        expect(s.ledger.single.operationId, 'old-op');
      } finally {
        await upgraded.close();
      }
      final reopened = PennyDatabase.file(file);
      try {
        expect(
          (await reopened.rows(
            'SELECT * FROM wish_withdrawals',
          )).single['wish_id'],
          'old-wish',
        );
        expect(await reopened.rows('PRAGMA foreign_key_check'), isEmpty);
        expect(File('${file.path}.before-v4.sqlite').existsSync(), isTrue);
      } finally {
        await reopened.close();
        await dir.delete(recursive: true);
      }
    },
  );
}

class _VersionFourDatabase extends PennyDatabase {
  _VersionFourDatabase(super.executor);
  @override
  int get schemaVersion => 4;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final sql in [
        ...PennyDatabase.schema,
        ...PennyDatabase.wishboardSchema,
        ...PennyDatabase.familySchema,
      ]) {
        await customStatement(sql);
      }
    },
  );
}
