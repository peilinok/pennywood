import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/backup.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/market.dart';
import 'package:pennywood/domain/money.dart';
import 'database_service_test.dart' show MemoryCredentials;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  late PennyDatabase db;
  late TownService service;
  late FixedClock clock;
  late Access child, parent;
  var sequence = 0;
  Future<String?> run(
    String action,
    List<Object?> args, {
    bool adult = false,
    String? op,
  }) => service.execute(
    adult ? parent : child,
    op ?? 'investment-${++sequence}',
    action,
    args,
  );
  Future<void> fund() async {
    final task = await run('addTask', ['现实劳动', 20000, '事先约好'], adult: true);
    for (final action in ['accept', 'submit', 'approve', 'pay']) {
      await run(action, [task], adult: ['approve', 'pay'].contains(action));
    }
    await run('settings', [10000, '小满'], adult: true);
  }

  setUp(() async {
    db = PennyDatabase(NativeDatabase.memory());
    clock = FixedClock('2026-11-01');
    service = TownService(db, Auth(MemoryCredentials()), clock);
    await service.createFamily('real', '719385', ['小满', '小禾']);
    child = service.auth.child('real', 'first');
    parent = await service.auth.unlock('real', 'first', '719385');
  });
  tearDown(() => db.close());

  test(
    'Product rates are shared, independently versioned, and preserve original promises',
    () async {
      await fund();
      await run('familyRates', [100, 500, 300], adult: true);
      await run('buy', ['sprout', 10000, 'cash']);
      await run('buy', ['annual', 5000, 'cash']);
      await run('buy', ['dividend', 1000, 'cash']);
      var s = await service.account(child);
      expect(s.positions.map((p) => p.expected), [25, 250, 2]);
      final dividendVersion = s.versionFor('dividend');
      await run('familyRates', [200, 600, 300], adult: true);
      s = await service.account(child);
      expect(s.positions.map((p) => p.rateBps), [100, 500, 300]);
      expect(s.versionFor('dividend'), dividendVersion);
      final other = await service.account(service.auth.child('real', 'second'));
      expect(other.rateFor('annual'), 600);
      expect(other.budget, 0);
      expect(other.positions, isEmpty);
      clock.advance(30);
      await service.restore('real');
      s = await service.account(child);
      expect(s.active.where((p) => p.product == 'dividend').length, 1);
      await run('familyRates', [200, 600, 400], adult: true);
      await run('familyRates', [200, 600, 300], adult: true);
      clock.advance(30);
      await service.restore('real');
      s = await service.account(child);
      expect(s.active.where((p) => p.product == 'dividend'), isEmpty);
    },
  );

  test(
    'Family template and rate updates reject child authority and roll back on save failure',
    () async {
      for (final command in [
        ('familyRates', <Object?>[100, 300, 200]),
        ('marketPermission', <Object?>[true]),
      ]) {
        await expectLater(
          run(command.$1, command.$2),
          throwsA(isA<RuleViolation>()),
        );
      }
      await db.customStatement(
        "CREATE TRIGGER fail_family BEFORE INSERT ON operations WHEN NEW.id='family-retry' BEGIN SELECT RAISE(ABORT,'injected'); END",
      );
      await expectLater(
        run(
          'configureQuick',
          ['dishes', 300, '洗净并归位'],
          adult: true,
          op: 'family-retry',
        ),
        throwsA(anything),
      );
      for (final id in ['first', 'second']) {
        expect((await db.load('real', id)).quickTasks.first.amount, 0);
      }
      await db.customStatement('DROP TRIGGER fail_family');
      await run(
        'configureQuick',
        ['dishes', 300, '洗净并归位'],
        adult: true,
        op: 'family-retry',
      );
      await run(
        'configureQuick',
        ['dishes', 300, '洗净并归位'],
        adult: true,
        op: 'family-retry',
      );
      await run('setQuickEnabled', ['dishes', false], adult: true);
      expect(
        (await db.load('real', 'second')).quickTasks.first.enabled,
        isFalse,
      );
      await expectLater(
        run('familyRates', [200, 1001, 300], adult: true),
        throwsA(isA<RuleViolation>()),
      );
      expect((await db.load('real', 'second')).rateFor('sprout'), 0);
    },
  );

  test(
    'Real-money market consent, reserves, losses, and redemptions reconcile exactly once',
    () async {
      await fund();
      await expectLater(
        run('buy', ['growth', 10000, 'cash']),
        throwsA(isA<RuleViolation>()),
      );
      await run('marketPermission', [true], adult: true);
      final id = await run('buy', ['growth', 10000, 'cash']);
      var s = await service.account(child);
      expect(s.assets, 20000);
      expect(s.reserved, 2000);
      expect(s.freeBudget, 8000);
      await run('marketPermission', [false], adult: true);
      clock.advance(1);
      await run('redeem', [id], op: 'redeem-retry');
      await run('redeem', [id], op: 'redeem-retry');
      s = await service.account(child);
      // Calendar-v1 movement for November 2 is -48 bps: 100.00 becomes 99.52.
      expect(s.wallet, 19952);
      expect(s.marketReturn, -48);
      expect(s.marketSpent, 0);
      expect(s.reserved, 0);
      expect(s.freeBudget, 10000);
      expect(s.ledger.where((l) => l.kind == 'market-return').length, 1);
      expect((await db.load('real', 'second')).assets, 0);
      s.check();
      await expectLater(
        run('buy', ['lowVol', 1000, 'cash']),
        throwsA(isA<RuleViolation>()),
      );
      await expectLater(run('redeem', [id]), throwsA(isA<RuleViolation>()));
    },
  );

  test(
    'Maturity funds gains within reserved budget and failure/retry never double-settles',
    () async {
      await fund();
      await run('marketPermission', [true], adult: true);
      await run('buy', ['growth', 10000, 'cash']);
      clock.advance(30);
      await db.customStatement(
        "CREATE TRIGGER fail_market BEFORE INSERT ON ledger WHEN NEW.kind='market-return' BEGIN SELECT RAISE(ABORT,'injected'); END",
      );
      await expectLater(service.restore('real'), throwsA(anything));
      expect((await db.load('real', 'first')).wallet, 10000);
      expect(
        (await db.load('real', 'first')).positions.single.status,
        'active',
      );
      await db.customStatement('DROP TRIGGER fail_market');
      await service.restore('real');
      await service.restore('real');
      final s = await service.account(child);
      expect(s.wallet, 20971);
      expect(s.marketReturn, 971);
      expect(s.marketSpent, 971);
      expect(s.freeBudget, 9029);
      expect(s.reserved, 0);
      expect(
        s.ledger.where((l) => l.kind == 'market-return').single.amount,
        971,
      );
      await expectLater(
        run('settings', [970, '小满'], adult: true),
        throwsA(isA<RuleViolation>()),
      );
      s.check();
    },
  );

  test('Concurrent purchases cannot consume reserved money twice', () async {
    await fund();
    await run('settings', [2000, '小满'], adult: true);
    await run('marketPermission', [true], adult: true);
    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        run('buy', [
          'growth',
          10000,
          'cash',
        ]).then((_) => true, onError: (_) => false),
    ]);
    expect(results.where((ok) => ok).length, 1);
    final s = await service.account(child);
    expect(s.reserved, 2000);
    expect(s.wallet, 10000);
    s.check();
  });

  test(
    'Calendar market has reproducible pullbacks, bounded stakes, and distinct volatility',
    () {
      final low = TeachingMarket.curve('lowVol', '2026-11-01', 30);
      final high = TeachingMarket.curve('growth', '2026-11-01', 30);
      expect(low[1], 9983);
      expect(high[1], 9952);
      expect(low.last, 10214);
      expect(high.last, 10971);
      expect(high, TeachingMarket.curve('growth', '2026-11-01', 30));
      for (var scenario = 0; scenario < 100; scenario++) {
        final l = TeachingMarket.curve(
          'lowVol',
          '2026-01-01',
          365,
          scenario: scenario,
        );
        final h = TeachingMarket.curve(
          'growth',
          '2026-01-01',
          365,
          scenario: scenario,
        );
        expect(l.every((v) => v >= 9000 && v <= 10500), isTrue);
        expect(h.every((v) => v >= 5000 && v <= 12000), isTrue);
        expect(
          h.asMap().entries.any((e) => e.key > 0 && e.value < h[e.key - 1]),
          isTrue,
        );
      }
    },
  );

  test(
    'Market losses, shared agreements, rates, and permission survive file restart and encrypted restore',
    () async {
      final dir = await Directory.systemTemp.createTemp('pennywood-market-');
      final file = File('${dir.path}/isolated.sqlite');
      final disk = PennyDatabase.file(file);
      final credentials = MemoryCredentials();
      final svc = TownService(disk, Auth(credentials), clock);
      try {
        await svc.createFamily('real', '719385', ['小满', '小禾']);
        final a = await svc.auth.unlock('real', 'first', '719385');
        final task = await svc.execute(a, 'task', 'addTask', [
          '现实劳动',
          20000,
          '先约好',
        ]);
        for (final action in ['accept', 'submit', 'approve', 'pay']) {
          await svc.execute(a, action, action, [task]);
        }
        await svc.execute(a, 'budget', 'settings', [10000, '小满']);
        await svc.execute(a, 'permission', 'marketPermission', [true]);
        await svc.execute(a, 'rates', 'familyRates', [100, 500, 300]);
        final id = await svc.execute(a, 'buy', 'buy', [
          'growth',
          10000,
          'cash',
        ]);
        clock.advance(1);
        await svc.execute(a, 'redeem', 'redeem', [id]);
        final backup = FamilyBackup(disk, svc.auth);
        final bytes = await backup.export(a, 'synthetic-market-backup');
        final verified = await backup.read(bytes, 'synthetic-market-backup');
        final fresh = PennyDatabase(NativeDatabase.memory());
        try {
          await FamilyBackup(
            fresh,
            Auth(MemoryCredentials()),
          ).restore(verified, newPin: '843721');
          final restored = await fresh.load('real', 'first');
          expect(restored.marketReturn, -48);
          expect(restored.marketEnabled, isTrue);
          expect((await fresh.load('real', 'second')).rateFor('annual'), 500);
          expect(await fresh.rows('PRAGMA foreign_key_check'), isEmpty);
        } finally {
          await fresh.close();
        }
      } finally {
        await disk.close();
      }
      final reopened = PennyDatabase.file(file);
      try {
        final svc = TownService(reopened, Auth(credentials), clock);
        final a = await svc.auth.unlock('real', 'first', '719385');
        await svc.execute(a, 'redeem', 'redeem', [
          (await reopened.load('real', 'first')).positions.single.id,
        ]);
        final s = await reopened.load('real', 'first');
        expect(s.wallet, 19952);
        expect(s.marketReturn, -48);
        s.check();
      } finally {
        await reopened.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
