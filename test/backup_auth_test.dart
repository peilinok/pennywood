import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/drift.dart' show driftRuntimeOptions;
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
  late FamilyBackup backup;
  late Access parent, child;
  var sequence = 0;
  const password = '单独保管的备份密码-2026';
  setUp(() async {
    db = PennyDatabase(NativeDatabase.memory());
    svc = TownService(db, Auth(MemoryCredentials()), FixedClock('2026-11-01'));
    await svc.createFamily('real', '719385', ['小满', '小禾']);
    parent = await svc.auth.unlock('real', 'first', '719385');
    child = svc.auth.child('real', 'first');
    backup = FamilyBackup(db, svc.auth);
  });
  tearDown(() => db.close());
  Future<void> earn() async {
    final id = 'test-${++sequence}';
    final task = await svc.execute(parent, '$id-add', 'addTask', [
      '洗碗',
      200,
      '现实中完成',
    ]);
    await svc.execute(child, '$id-accept', 'accept', [task]);
    await svc.execute(child, '$id-submit', 'submit', [task]);
    await svc.execute(parent, '$id-approve', 'approve', [task]);
    await svc.execute(parent, '$id-pay', 'pay', [task]);
  }

  test(
    'Backup requires parent authority and rejects wrong passwords or tampering',
    () async {
      await earn();
      await expectLater(
        backup.export(child, password),
        throwsA(isA<RuleViolation>()),
      );
      final bytes = await backup.export(parent, password);
      final content = utf8.decode(bytes);
      for (final secret in ['小满', '719385', '洗碗', 'recovery', 'fingerprint']) {
        expect(content.contains(secret), isFalse);
      }
      await expectLater(
        backup.read(bytes, '错误备份密码'),
        throwsA(isA<RuleViolation>()),
      );
      final envelope = jsonDecode(content) as Map<String, dynamic>;
      final cipher = base64Decode(envelope['ciphertext']);
      cipher[0] ^= 1;
      envelope['ciphertext'] = base64Encode(cipher);
      await expectLater(
        backup.read(
          Uint8List.fromList(utf8.encode(jsonEncode(envelope))),
          password,
        ),
        throwsA(isA<RuleViolation>()),
      );
      final verified = await backup.read(bytes, password);
      expect(verified.children, ['小满', '小禾']);
      expect(verified.entries, 5);
      expect((await db.load('real', 'first')).wallet, 200);
    },
  );

  test(
    'Replacement restore saves an encrypted copy and prevents duplicate payment after retry',
    () async {
      await earn();
      final old = await backup.read(
        await backup.export(parent, password),
        password,
      );
      await earn();
      await svc.createFamily('demo', '843721', ['示例甲', '示例乙'], demo: true);
      final demoWallet = (await db.load('demo', 'first')).wallet;
      final latestTask = (await db.load('real', 'first')).tasks.last.id;
      Uint8List? safety;
      await expectLater(
        backup.restore(old, access: child, preserveBefore: (_) async => '错误'),
        throwsA(isA<RuleViolation>()),
      );
      await expectLater(
        backup.restore(
          old,
          access: parent,
          preserveBefore: (_) async => throw StateError('磁盘写入失败'),
        ),
        throwsStateError,
      );
      expect((await db.load('real', 'first')).wallet, 400);
      final path = await backup.restore(
        old,
        access: parent,
        preserveBefore: (bytes) async {
          safety = bytes;
          return '恢复前副本.pennywood';
        },
      );
      expect(path, '恢复前副本.pennywood');
      expect((await db.load('real', 'first')).wallet, 200);
      expect((await db.load('demo', 'first')).wallet, demoWallet);
      expect(
        (await db.load('real', 'first')).tasks.any((t) => t.id == latestTask),
        isFalse,
      );
      final previous = await backup.read(safety!, password);
      expect(previous.entries, 10);
      await expectLater(
        svc.execute(parent, 'stale', 'settings', [0, 0, '小满']),
        throwsA(isA<RuleViolation>()),
      );
      final renewed = await svc.auth.unlock('real', 'first', '719385');
      final task = (await db.load('real', 'first')).tasks.single.id;
      // Restore operation records too; task state prevents repeated payment under a new request ID.
      await expectLater(
        svc.execute(renewed, 'pay-again', 'pay', [task]),
        throwsA(isA<RuleViolation>()),
      );
      expect((await db.load('real', 'first')).wallet, 200);
      expect(await db.rows('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'Another family cannot overwrite local data or clone source credentials',
    () async {
      await earn();
      final verified = await backup.read(
        await backup.export(parent, password),
        password,
      );
      final other = PennyDatabase(NativeDatabase.memory());
      final otherSvc = TownService(
        other,
        Auth(MemoryCredentials()),
        FixedClock('2026-11-01'),
      );
      final otherBackup = FamilyBackup(other, otherSvc.auth);
      try {
        await otherSvc.createFamily('real', '843721', ['别人甲', '别人乙']);
        final p = await otherSvc.auth.unlock('real', 'first', '843721');
        await expectLater(
          otherBackup.restore(
            verified,
            access: p,
            preserveBefore: (_) async => '副本',
          ),
          throwsA(isA<RuleViolation>()),
        );
        expect((await other.load('real', 'first')).wallet, 0);
      } finally {
        await other.close();
      }
      final fresh = PennyDatabase(NativeDatabase.memory());
      final auth = Auth(MemoryCredentials());
      try {
        await FamilyBackup(fresh, auth).restore(verified, newPin: '935172');
        expect((await fresh.load('real', 'first')).wallet, 200);
        await expectLater(
          auth.unlock('real', 'first', '719385'),
          throwsA(isA<RuleViolation>()),
        );
        final newParent = await auth.unlock('real', 'first', '935172');
        auth.check(newParent, parent: true);
        expect(await auth.credentials.read('pennywood.recovery.real'), isNull);
      } finally {
        await fresh.close();
      }
    },
  );

  test(
    'Passcode changes require verification; invalid recovery codes preserve credentials',
    () async {
      await expectLater(
        svc.auth.issueRecovery(child),
        throwsA(isA<RuleViolation>()),
      );
      await expectLater(
        svc.auth.changePin(parent, '000000', '935172'),
        throwsA(isA<RuleViolation>()),
      );
      final code = await svc.auth.issueRecovery(parent);
      expect(code.replaceAll('-', '').length, 32);
      expect(
        await svc.auth.credentials.read('pennywood.recovery.real'),
        isNot(contains(code.replaceAll('-', ''))),
      );
      await svc.auth.changePin(parent, '719385', '935172');
      await expectLater(
        svc.auth.unlock('real', 'first', '719385'),
        throwsA(isA<RuleViolation>()),
      );
      await svc.auth.unlock('real', 'first', '935172');
      await expectLater(
        svc.auth.recover('real', '不正确的恢复码', '182736'),
        throwsA(isA<RuleViolation>()),
      );
      await svc.auth.unlock('real', 'first', '935172');
      await svc.auth.recover('real', code.toLowerCase(), '182736');
      final recovered = await svc.auth.unlock('real', 'first', '182736');
      svc.auth.check(recovered, parent: true);
      expect((await db.load('real', 'first')).assets, 0);
    },
  );

  test(
    'Late unlock results cannot restore parent access after exit or backgrounding',
    () async {
      final pending = svc.auth.unlock('real', 'first', '719385');
      svc.auth.lock();
      await expectLater(pending, throwsA(isA<RuleViolation>()));
    },
  );
}
