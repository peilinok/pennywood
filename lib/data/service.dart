import 'dart:convert';
import 'dart:math';
import '../domain/engine.dart';
import '../domain/model.dart';
import '../domain/money.dart';
import 'auth.dart';
import 'database.dart';

class TownService {
  TownService(this.db, this.auth, this.clock);
  final PennyDatabase db;
  final Auth auth;
  final Clock clock;

  Future<void> createFamily(
    String family,
    String pin,
    List<String> names, {
    bool demo = false,
  }) async {
    require(
      names.length == 2 &&
          names.every((n) => n.trim().isNotEmpty && n.trim().length <= 8),
      '请填写两个孩子的称呼，各 1–8 个字',
    );
    require(
      (await db.rows('SELECT id FROM families WHERE id=?', [family])).isEmpty,
      '该家庭已经建档',
    );
    final existing = await auth.credentials.read('pennywood.$family');
    if (existing == null) {
      await auth.create(family, pin);
    } else {
      await auth.unlock(family, 'first', pin);
    }
    await db.transaction(() async {
      await db.upsert(
        'families',
        {
          'id': family,
          'demo': demo ? 1 : 0,
          'active_child': 'first',
          'created': clock.today,
          'global_id': List.generate(
            16,
            (_) => Random.secure().nextInt(256),
          ).map((n) => n.toRadixString(16).padLeft(2, '0')).join(),
        },
        ['id'],
      );
      for (var i = 0; i < 2; i++) {
        final s = ChildAccount(
          id: i == 0 ? 'first' : 'second',
          name: names[i].trim(),
          date: clock.today,
          goal: 0,
          goalName: '',
        );
        // Record the synthetic principal source explicitly; never reuse it for real-family setup.
        if (demo) {
          s.wallet = i == 0 ? 20000 : 10000;
          s.laborTotal = s.wallet;
          s.budget = 5000;
          s.rateBps = 300;
          s.log('income', '示例本金来源，仅用于独立体验', s.wallet, 'demo-seed');
        }
        for (final id in QuickTask.names.keys) {
          s.quickTasks.add(
            QuickTask(
              id: id,
              detail: QuickTask.standards[id]!,
              enabled: demo,
              amount: demo
                  ? {
                      'dishes': 200,
                      'mop': 300,
                      'toys': 200,
                      'vegetables': 100,
                      'study': 500,
                    }[id]!
                  : 0,
            ),
          );
        }
        if (demo) {
          s.wishes.addAll([
            Wish(id: 'telescope', name: '我的第一台望远镜', target: 8000, isMain: true),
            Wish(
              id: 'first-saving',
              name: '攒到我的第一个 200 元',
              target: 20000,
              kind: 'saving',
            ),
          ]);
        }
        if (demo) {
          s.goalName = s.mainWish!.name;
          s.goal = s.mainWish!.target;
        }
        if (demo) {
          s.tasks.addAll([
            LaborTask(id: 'books', name: '给书架来次大整理', amount: 800),
            LaborTask(
              id: 'plant',
              name: '照顾阳台的小花园',
              amount: 500,
              detail: '浇水、整理枯叶，记得节约用水',
            ),
            LaborTask(
              id: 'breakfast',
              name: '当一次早餐小帮手',
              amount: 1200,
              detail: '和家长一起准备，避开热锅与刀具',
            ),
            LaborTask(
              id: 'recycle',
              name: '把可回收物分好类',
              amount: 600,
              detail: '纸箱和塑料瓶各归各位',
            ),
          ]);
        }
        for (final l in s.ledger) {
          l.operationId = 'create-family';
          l.actorRole = 'parent';
        }
        await db.save(family, s);
        await db.saveScene(family, s.id, SceneState());
      }
      await db.seedFamilyTerms();
    });
  }

  Future<ChildAccount> account(Access a) async {
    auth.check(a);
    return db.load(a.family, a.child);
  }

  Future<void> selectChild(String family, String child) async {
    require(
      (await db.rows('SELECT id FROM children WHERE family_id=? AND id=?', [
        family,
        child,
      ])).isNotEmpty,
      '孩子档案不存在',
    );
    await db.customStatement('UPDATE families SET active_child=? WHERE id=?', [
      child,
      family,
    ]);
  }

  Future<String?> execute(
    Access a,
    String operationId,
    String action,
    List<Object?> args,
  ) async {
    auth.check(a, parent: Engine.parentActions.contains(action));
    require(operationId.isNotEmpty && operationId.length <= 160, '操作标识无效');
    // Only the command fingerprint is JSON; accounting state uses rows.
    final fingerprint = jsonEncode([action, args]);
    return db.transaction(() async {
      auth.check(a, parent: Engine.parentActions.contains(action));
      final previous = await db.rows(
        'SELECT fingerprint,result_id FROM operations WHERE family_id=? AND child_id=? AND id=?',
        [a.family, a.child, operationId],
      );
      if (previous.isNotEmpty) {
        require(previous.single['fingerprint'] == fingerprint, '操作标识已用于其他请求');
        return previous.single['result_id'] as String?;
      }
      final s = await db.load(a.family, a.child);
      final beforeSystem = s.ledger.length;
      Engine.catchUp(s, clock.today);
      await recordSystem(a.family, s, beforeSystem);
      final beforeAction = s.ledger.length;
      final result = Engine.execute(s, action, args);
      if (action == 'configureQuick' || action == 'setQuickEnabled') {
        await db.saveFamilyAgreements(a.family, s);
      }
      if (action == 'familyRates' ||
          (action == 'settings' && args.length > 2)) {
        await db.saveProductRates(a.family, s);
      }
      for (final l in s.ledger.skip(beforeAction)) {
        l.operationId = operationId;
        l.actorRole = a.parent ? 'parent' : 'child';
      }
      await db.save(a.family, s);
      await db.upsert(
        'operations',
        {
          'family_id': a.family,
          'child_id': a.child,
          'id': operationId,
          'fingerprint': fingerprint,
          'result_id': result,
          'date': clock.today,
        },
        ['family_id', 'child_id', 'id'],
      );
      return result;
    });
  }

  Future<void> restore(String family) => db.transaction(() async {
    final children = await db.rows(
      'SELECT id FROM children WHERE family_id=?',
      [family],
    );
    for (final row in children) {
      final s = await db.load(family, row['id'] as String);
      final before = s.ledger.length;
      Engine.catchUp(s, clock.today);
      await recordSystem(family, s, before);
      await db.save(family, s);
    }
  });
  Future<void> recordSystem(String family, ChildAccount s, int before) async {
    for (final l in s.ledger.skip(before)) {
      l.operationId = 'system:${l.reference}:${l.date}';
      l.actorRole = 'system';
      await db.upsert(
        'operations',
        {
          'family_id': family,
          'child_id': s.id,
          'id': l.operationId,
          'fingerprint': jsonEncode(['settlement', l.reference, l.date]),
          'result_id': l.reference,
          'date': l.date,
        },
        ['family_id', 'child_id', 'id'],
      );
    }
  }

  Future<void> scene(Access a, SceneState scene) async {
    auth.check(a);
    require(
      scene.x.isFinite &&
          scene.y.isFinite &&
          scene.zoom.isFinite &&
          scene.panX.isFinite &&
          scene.panY.isFinite,
      '场景坐标无效',
    );
    await db.saveScene(a.family, a.child, scene);
  }
}
