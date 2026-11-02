import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import '../domain/model.dart';

// Use Drift transactions, migrations, and parameterized SQL; persist normalized rows rather than replacing JSON.
class PennyDatabase extends GeneratedDatabase {
  PennyDatabase(super.executor);
  factory PennyDatabase.file(File file) => PennyDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (database) {
        final previous =
            database.select('PRAGMA user_version').single.values.single as int;
        if (previous > 0 && previous < version) {
          final backup = File('${file.path}.before-v$previous.sqlite');
          if (!backup.existsSync()) {
            database.execute('VACUUM INTO ?', [backup.path]);
          }
        }
      },
    ),
  );
  static const version = 5;
  @override
  int get schemaVersion => version;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => transaction(() async {
      for (final sql in creationStatements) {
        await customStatement(sql);
      }
      await customStatement('PRAGMA user_version = $schemaVersion');
    }),
    onUpgrade: (m, from, to) => transaction(() async {
      if (from < 1 || from > 4 || to != 5) {
        throw StateError('不支持从版本 $from 升级到 $to；原始存档保留');
      }
      if (from == 1) {
        await customStatement(
          "ALTER TABLE ledger ADD COLUMN operation_id TEXT NOT NULL DEFAULT 'legacy'",
        );
        await customStatement(
          "ALTER TABLE ledger ADD COLUMN actor_role TEXT NOT NULL DEFAULT 'legacy'",
        );
      }
      if (from < 3) {
        for (final sql in wishboardSchema) {
          await customStatement(sql);
        }
        await customStatement(
          "INSERT INTO wishes(family_id,child_id,id,name,kind,target,is_main) SELECT family_id,id,'legacy-goal',goal_name,'gift',goal,1 FROM children WHERE goal>0",
        );
      }
      for (final sql in from < 4 ? familySchema : <String>[]) {
        await customStatement(sql);
      }
      for (final sql in wishFinanceSchema) {
        await customStatement(sql);
      }
      for (final (table, column) in [
        ('wish_withdrawals', 'withdrawal_id'),
        ('wish_loans', 'loan_id'),
      ]) {
        await customStatement(
          'INSERT INTO $table(family_id,child_id,wish_id,$column,received) SELECT family_id,child_id,id,$column,1 FROM wishes WHERE $column IS NOT NULL',
        );
      }
      await customStatement('PRAGMA user_version = $schemaVersion');
    }),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA busy_timeout = 5000');
    },
  );

  Future<List<Map<String, dynamic>>> rows(
    String sql, [
    List<Object?> args = const [],
  ]) async => (await customSelect(
    sql,
    variables: [
      for (final a in args)
        if (a is int)
          Variable<int>(a)
        else if (a is double)
          Variable<double>(a)
        else
          Variable<String>(a as String?),
    ],
  ).get()).map((r) => r.data).toList();
  Future<void> upsert(
    String table,
    Map<String, Object?> row,
    List<String> keys,
  ) async {
    final columns = row.keys.toList();
    final updates = columns.where((c) => !keys.contains(c));
    await customStatement(
      'INSERT INTO $table (${columns.join(',')}) VALUES (${columns.map((_) => '?').join(',')}) ON CONFLICT (${keys.join(',')}) DO ${updates.isEmpty ? 'NOTHING' : 'UPDATE SET ${updates.map((c) => '$c=excluded.$c').join(',')}'}',
      row.values.toList(),
    );
  }

  Future<ChildAccount> load(String family, String child) async {
    final a = (await rows('SELECT * FROM children WHERE family_id=? AND id=?', [
      family,
      child,
    ])).single;
    Future<List<Map<String, dynamic>>> list(String table) => rows(
      'SELECT * FROM $table WHERE family_id=? AND child_id=? ORDER BY rowid',
      [family, child],
    );
    final tasks = await list('tasks'),
        positions = await list('positions'),
        requests = await list('withdrawals'),
        loans = await list('loans'),
        ledger = await list('ledger'),
        wishes = await list('wishes'),
        quickTasks = await list('quick_tasks'),
        wishWithdrawals = {
          for (final r in await list('wish_withdrawals'))
            r['withdrawal_id'] as String: r,
        },
        wishLoans = {
          for (final r in await list('wish_loans')) r['loan_id'] as String: r,
        };
    final result = ChildAccount(
      id: child,
      name: a['name'],
      date: a['date'],
      wallet: a['wallet'],
      laborTotal: a['labor_total'],
      bonusEarned: a['bonus_earned'],
      withdrawn: a['withdrawn'],
      repaidTotal: a['repaid_total'],
      budget: a['budget'],
      rateBps: a['rate_bps'],
      termsVersion: a['terms_version'],
      sequence: a['sequence'],
      distribution: a['distribution'],
      goal: a['goal'],
      goalName: a['goal_name'],
      weeklyPlan: a['weekly_plan'],
    );
    result.tasks.addAll(
      tasks.map(
        (r) => LaborTask(
          id: r['id'],
          name: r['name'],
          amount: r['amount'],
          detail: r['detail'],
          status: r['status'],
          templateId: r['template_id'],
          businessDay: r['business_day'],
          feedback: r['feedback'],
        ),
      ),
    );
    result.wishes.addAll(
      wishes.map(
        (r) => Wish(
          id: r['id'],
          name: r['name'],
          target: r['target'],
          kind: r['kind'],
          isMain: r['is_main'] == 1,
          status: r['status'],
          achievedOn: r['achieved_on'],
          achievedAmount: r['achieved_amount'],
          receivedOn: r['received_on'],
          receivedCost: r['received_cost'],
        ),
      ),
    );
    result.quickTasks.addAll(
      quickTasks.map(
        (r) => QuickTask(
          id: r['id'],
          detail: r['detail'],
          amount: r['amount'],
          enabled: r['enabled'] == 1,
        ),
      ),
    );
    result.positions.addAll(
      positions.map(
        (r) => Position(
          id: r['id'],
          product: r['product'],
          principal: r['principal'],
          rateBps: r['rate_bps'],
          days: r['days'],
          start: r['start'],
          end: r['end'],
          expected: r['expected'],
          distribution: r['distribution'],
          status: r['status'],
          termsVersion: r['terms_version'],
        ),
      ),
    );
    result.requests.addAll(
      requests.map(
        (r) => Withdrawal(
          id: r['id'],
          amount: r['amount'],
          purpose: r['purpose'],
          date: r['date'],
          status: r['status'],
          wishId: wishWithdrawals[r['id']]?['wish_id'],
          usedForGift: wishWithdrawals[r['id']]?['received'] == 1,
        ),
      ),
    );
    for (final r in loans) {
      final l = Loan(
        id: r['id'],
        item: r['item'],
        amount: r['amount'],
        months: r['months'],
        first: r['first_due'],
        requested: r['requested'],
        rateBps: r['rate_bps'],
        status: r['status'],
        funded: r['funded'],
        wishId: wishLoans[r['id']]?['wish_id'],
        usedForGift: wishLoans[r['id']]?['received'] == 1,
      );
      final installments = await rows(
        'SELECT * FROM installments WHERE family_id=? AND child_id=? AND loan_id=? ORDER BY period',
        [family, child, l.id],
      );
      l.schedule.addAll(
        installments.map(
          (p) => Installment(
            due: p['due'],
            principal: p['principal'],
            interest: p['interest'],
            paidPrincipal: p['paid_principal'],
            paidInterest: p['paid_interest'],
            waivedInterest: p['waived_interest'],
          ),
        ),
      );
      final payments = await rows(
        'SELECT * FROM repayments WHERE family_id=? AND child_id=? AND loan_id=? ORDER BY period',
        [family, child, l.id],
      );
      l.payments.addAll(
        payments.map(
          (p) => LoanPayment(p['date'], p['amount'], p['waived'], p['mode']),
        ),
      );
      result.loans.add(l);
    }
    result.ledger.addAll(
      ledger.map(
        (r) => LedgerEntry(
          r['id'],
          r['date'],
          r['kind'],
          r['title'],
          r['amount'],
          r['reference_id'],
          operationId: r['operation_id'],
          actorRole: r['actor_role'],
        ),
      ),
    );
    return result;
  }

  Future<void> save(String family, ChildAccount s) async {
    s.check();
    await upsert(
      'children',
      {
        'family_id': family,
        'id': s.id,
        'name': s.name,
        'date': s.date,
        'wallet': s.wallet,
        'labor_total': s.laborTotal,
        'bonus_earned': s.bonusEarned,
        'withdrawn': s.withdrawn,
        'repaid_total': s.repaidTotal,
        'budget': s.budget,
        'rate_bps': s.rateBps,
        'terms_version': s.termsVersion,
        'sequence': s.sequence,
        'distribution': s.distribution,
        'goal': s.goal,
        'goal_name': s.goalName,
        'weekly_plan': s.weeklyPlan,
      },
      ['family_id', 'id'],
    );
    Map<String, Object?> base(String id) => {
      'family_id': family,
      'child_id': s.id,
      'id': id,
    };
    const keys = ['family_id', 'child_id', 'id'];
    for (final t in s.tasks) {
      await upsert('tasks', {
        ...base(t.id),
        'name': t.name,
        'detail': t.detail,
        'amount': t.amount,
        'status': t.status,
        'template_id': t.templateId,
        'business_day': t.businessDay,
        'feedback': t.feedback,
      }, keys);
    }
    await customStatement(
      'UPDATE wishes SET is_main=0 WHERE family_id=? AND child_id=?',
      [family, s.id],
    );
    for (final w in s.wishes) {
      await upsert('wishes', {
        ...base(w.id),
        'name': w.name,
        'kind': w.kind,
        'target': w.target,
        'is_main': w.isMain ? 1 : 0,
        'status': w.status,
        'achieved_on': w.achievedOn,
        'achieved_amount': w.achievedAmount,
        'received_on': w.receivedOn,
        'received_cost': w.receivedCost,
      }, keys);
    }
    for (final q in s.quickTasks) {
      await upsert('quick_tasks', {
        ...base(q.id),
        'detail': q.detail,
        'amount': q.amount,
        'enabled': q.enabled ? 1 : 0,
      }, keys);
    }
    for (final p in s.positions) {
      await upsert('positions', {
        ...base(p.id),
        'product': p.product,
        'principal': p.principal,
        'rate_bps': p.rateBps,
        'days': p.days,
        'start': p.start,
        'end': p.end,
        'expected': p.expected,
        'distribution': p.distribution,
        'status': p.status,
        'terms_version': p.termsVersion,
      }, keys);
    }
    for (final r in s.requests) {
      await upsert('withdrawals', {
        ...base(r.id),
        'amount': r.amount,
        'purpose': r.purpose,
        'date': r.date,
        'status': r.status,
      }, keys);
    }
    for (final l in s.loans) {
      await upsert('loans', {
        ...base(l.id),
        'item': l.item,
        'amount': l.amount,
        'months': l.months,
        'first_due': l.first,
        'requested': l.requested,
        'rate_bps': l.rateBps,
        'status': l.status,
        'funded': l.funded,
      }, keys);
      for (var i = 0; i < l.payments.length; i++) {
        final p = l.payments[i];
        await upsert(
          'repayments',
          {
            'family_id': family,
            'child_id': s.id,
            'loan_id': l.id,
            'period': i,
            'date': p.date,
            'amount': p.amount,
            'waived': p.waived,
            'mode': p.mode,
          },
          ['family_id', 'child_id', 'loan_id', 'period'],
        );
      }
      for (var i = 0; i < l.schedule.length; i++) {
        final p = l.schedule[i];
        await upsert(
          'installments',
          {
            'family_id': family,
            'child_id': s.id,
            'loan_id': l.id,
            'period': i,
            'due': p.due,
            'principal': p.principal,
            'interest': p.interest,
            'paid_principal': p.paidPrincipal,
            'paid_interest': p.paidInterest,
            'waived_interest': p.waivedInterest,
          },
          ['family_id', 'child_id', 'loan_id', 'period'],
        );
      }
    }
    // Ledger entries are append-only; unique keys prevent snapshot saves from overwriting history.
    // Relation rows are the sole wish-payment source; legacy single-payment columns are migration-only.
    for (final r in s.requests.where((r) => r.wishId != null)) {
      await upsert(
        'wish_withdrawals',
        {
          'family_id': family,
          'child_id': s.id,
          'wish_id': r.wishId,
          'withdrawal_id': r.id,
          'received': r.usedForGift ? 1 : 0,
        },
        ['family_id', 'child_id', 'withdrawal_id'],
      );
    }
    for (final l in s.loans.where((l) => l.wishId != null)) {
      await upsert(
        'wish_loans',
        {
          'family_id': family,
          'child_id': s.id,
          'wish_id': l.wishId,
          'loan_id': l.id,
          'received': l.usedForGift ? 1 : 0,
        },
        ['family_id', 'child_id', 'loan_id'],
      );
    }
    for (final l in s.ledger) {
      await customStatement(
        'INSERT INTO ledger(family_id,child_id,id,date,kind,title,amount,reference_id,operation_id,actor_role) VALUES(?,?,?,?,?,?,?,?,?,?) ON CONFLICT(family_id,child_id,id) DO NOTHING',
        [
          family,
          s.id,
          l.id,
          l.date,
          l.kind,
          l.title,
          l.amount,
          l.reference,
          l.operationId,
          l.actorRole,
        ],
      );
    }
  }

  Future<SceneState> loadScene(String family, String child) async {
    final r = await rows(
      'SELECT * FROM scenes WHERE family_id=? AND child_id=?',
      [family, child],
    );
    if (r.isEmpty) return SceneState();
    final v = r.single;
    final visits = await rows(
      'SELECT place FROM visits WHERE family_id=? AND child_id=?',
      [family, child],
    );
    return SceneState(
      x: (v['x'] as num).toDouble(),
      y: (v['y'] as num).toDouble(),
      zoom: (v['zoom'] as num).toDouble(),
      panX: (v['pan_x'] as num).toDouble(),
      panY: (v['pan_y'] as num).toDouble(),
      evening: v['evening'] == 1,
      sound: v['sound'] == 1,
      visited: visits.map((r) => r['place'] as String).toSet(),
    );
  }

  Future<void> saveScene(String family, String child, SceneState s) =>
      transaction(() async {
        await upsert(
          'scenes',
          {
            'family_id': family,
            'child_id': child,
            'x': s.x,
            'y': s.y,
            'zoom': s.zoom,
            'pan_x': s.panX,
            'pan_y': s.panY,
            'evening': s.evening ? 1 : 0,
            'sound': s.sound ? 1 : 0,
          },
          ['family_id', 'child_id'],
        );
        for (final place in s.visited) {
          await upsert(
            'visits',
            {'family_id': family, 'child_id': child, 'place': place},
            ['family_id', 'child_id', 'place'],
          );
        }
      });

  List<String> get creationStatements => [
    ...schema,
    ...wishboardSchema,
    ...familySchema,
    ...wishFinanceSchema,
  ];

  static const wishFinanceSchema = [
    'CREATE TABLE wish_withdrawals($scope, wish_id TEXT NOT NULL, withdrawal_id TEXT NOT NULL, received INTEGER NOT NULL CHECK(received IN (0,1)), PRIMARY KEY(family_id,child_id,withdrawal_id), FOREIGN KEY(family_id,child_id,wish_id) REFERENCES wishes(family_id,child_id,id), FOREIGN KEY(family_id,child_id,withdrawal_id) REFERENCES withdrawals(family_id,child_id,id))',
    'CREATE TABLE wish_loans($scope, wish_id TEXT NOT NULL, loan_id TEXT NOT NULL, received INTEGER NOT NULL CHECK(received IN (0,1)), PRIMARY KEY(family_id,child_id,loan_id), FOREIGN KEY(family_id,child_id,wish_id) REFERENCES wishes(family_id,child_id,id), FOREIGN KEY(family_id,child_id,loan_id) REFERENCES loans(family_id,child_id,id))',
  ];

  static const familySchema = [
    "ALTER TABLE families ADD COLUMN global_id TEXT NOT NULL DEFAULT ''",
    "UPDATE families SET global_id=lower(hex(randomblob(16))) WHERE global_id=''",
    "CREATE UNIQUE INDEX unique_family_identity ON families(global_id) WHERE global_id<>''",
    "ALTER TABLE wishes ADD COLUMN status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','archived','deleted'))",
    'ALTER TABLE wishes ADD COLUMN achieved_on TEXT',
    'ALTER TABLE wishes ADD COLUMN achieved_amount INTEGER NOT NULL DEFAULT 0 CHECK(achieved_amount>=0)',
    'ALTER TABLE wishes ADD COLUMN received_on TEXT',
    'ALTER TABLE wishes ADD COLUMN withdrawal_id TEXT',
    'ALTER TABLE wishes ADD COLUMN loan_id TEXT',
    'ALTER TABLE wishes ADD COLUMN received_cost INTEGER NOT NULL DEFAULT 0 CHECK(received_cost>=0)',
    'CREATE UNIQUE INDEX one_gift_per_withdrawal ON wishes(family_id,child_id,withdrawal_id) WHERE withdrawal_id IS NOT NULL',
    'CREATE UNIQUE INDEX one_gift_per_loan ON wishes(family_id,child_id,loan_id) WHERE loan_id IS NOT NULL',
  ];

  static const wishboardSchema = [
    'ALTER TABLE tasks ADD COLUMN template_id TEXT',
    'ALTER TABLE tasks ADD COLUMN business_day TEXT',
    "ALTER TABLE tasks ADD COLUMN feedback TEXT NOT NULL DEFAULT ''",
    'CREATE UNIQUE INDEX one_quick_task_per_day ON tasks(family_id,child_id,template_id,business_day) WHERE template_id IS NOT NULL',
    "CREATE TABLE wishes($scope, id TEXT NOT NULL, name TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('gift','saving')), target INTEGER NOT NULL CHECK(target>0), is_main INTEGER NOT NULL CHECK(is_main IN (0,1)), PRIMARY KEY(family_id,child_id,id), $childFk)",
    'CREATE UNIQUE INDEX one_main_wish ON wishes(family_id,child_id) WHERE is_main=1',
    'CREATE TABLE quick_tasks($scope, id TEXT NOT NULL, detail TEXT NOT NULL, amount INTEGER NOT NULL CHECK(amount>=0), enabled INTEGER NOT NULL, PRIMARY KEY(family_id,child_id,id), $childFk)',
  ];

  static const scope = 'family_id TEXT NOT NULL, child_id TEXT NOT NULL';
  static const childFk =
      'FOREIGN KEY(family_id,child_id) REFERENCES children(family_id,id)';
  static const schema = [
    'CREATE TABLE families(id TEXT PRIMARY KEY, demo INTEGER NOT NULL, active_child TEXT NOT NULL, created TEXT NOT NULL)',
    '''CREATE TABLE children(family_id TEXT NOT NULL REFERENCES families(id), id TEXT NOT NULL, name TEXT NOT NULL, date TEXT NOT NULL, wallet INTEGER NOT NULL CHECK(wallet>=0), labor_total INTEGER NOT NULL, bonus_earned INTEGER NOT NULL, withdrawn INTEGER NOT NULL, repaid_total INTEGER NOT NULL, budget INTEGER NOT NULL CHECK(budget>=0), rate_bps INTEGER NOT NULL CHECK(rate_bps BETWEEN 0 AND 1000), terms_version INTEGER NOT NULL, sequence INTEGER NOT NULL, distribution TEXT NOT NULL CHECK(distribution IN ('cash','reinvest')), goal INTEGER NOT NULL, goal_name TEXT NOT NULL, weekly_plan INTEGER NOT NULL, PRIMARY KEY(family_id,id))''',
    'CREATE TABLE tasks($scope, id TEXT NOT NULL, name TEXT NOT NULL, detail TEXT NOT NULL, amount INTEGER NOT NULL CHECK(amount>0), status TEXT NOT NULL, PRIMARY KEY(family_id,child_id,id), $childFk)',
    'CREATE TABLE positions($scope, id TEXT NOT NULL, product TEXT NOT NULL, principal INTEGER NOT NULL CHECK(principal>0), rate_bps INTEGER NOT NULL, days INTEGER NOT NULL, start TEXT NOT NULL, end TEXT NOT NULL, expected INTEGER NOT NULL CHECK(expected>=0), distribution TEXT NOT NULL, status TEXT NOT NULL, terms_version INTEGER NOT NULL, PRIMARY KEY(family_id,child_id,id), $childFk)',
    'CREATE TABLE withdrawals($scope, id TEXT NOT NULL, amount INTEGER NOT NULL CHECK(amount>0), purpose TEXT NOT NULL, date TEXT NOT NULL, status TEXT NOT NULL, PRIMARY KEY(family_id,child_id,id), $childFk)',
    'CREATE TABLE loans($scope, id TEXT NOT NULL, item TEXT NOT NULL, amount INTEGER NOT NULL CHECK(amount>0), months INTEGER NOT NULL, first_due TEXT NOT NULL, requested TEXT NOT NULL, rate_bps INTEGER NOT NULL, status TEXT NOT NULL, funded TEXT, PRIMARY KEY(family_id,child_id,id), $childFk)',
    'CREATE TABLE installments($scope, loan_id TEXT NOT NULL, period INTEGER NOT NULL, due TEXT NOT NULL, principal INTEGER NOT NULL, interest INTEGER NOT NULL, paid_principal INTEGER NOT NULL, paid_interest INTEGER NOT NULL, waived_interest INTEGER NOT NULL, PRIMARY KEY(family_id,child_id,loan_id,period), FOREIGN KEY(family_id,child_id,loan_id) REFERENCES loans(family_id,child_id,id))',
    'CREATE TABLE repayments($scope, loan_id TEXT NOT NULL, period INTEGER NOT NULL, date TEXT NOT NULL, amount INTEGER NOT NULL, waived INTEGER NOT NULL, mode TEXT NOT NULL, PRIMARY KEY(family_id,child_id,loan_id,period), FOREIGN KEY(family_id,child_id,loan_id) REFERENCES loans(family_id,child_id,id))',
    'CREATE TABLE ledger($scope, id TEXT NOT NULL, date TEXT NOT NULL, kind TEXT NOT NULL, title TEXT NOT NULL, amount INTEGER NOT NULL, reference_id TEXT NOT NULL, operation_id TEXT NOT NULL DEFAULT \'legacy\', actor_role TEXT NOT NULL DEFAULT \'legacy\', PRIMARY KEY(family_id,child_id,id), $childFk)',
    'CREATE UNIQUE INDEX one_settlement_per_position ON ledger(family_id,child_id,reference_id) WHERE kind=\'yield\'',
    'CREATE UNIQUE INDEX one_labor_payment ON ledger(family_id,child_id,reference_id) WHERE kind=\'income\'',
    'CREATE TABLE operations($scope, id TEXT NOT NULL, fingerprint TEXT NOT NULL, result_id TEXT, date TEXT NOT NULL, PRIMARY KEY(family_id,child_id,id), $childFk)',
    'CREATE TABLE scenes($scope, x REAL NOT NULL, y REAL NOT NULL, zoom REAL NOT NULL, pan_x REAL NOT NULL, pan_y REAL NOT NULL, evening INTEGER NOT NULL, sound INTEGER NOT NULL, PRIMARY KEY(family_id,child_id), $childFk)',
    'CREATE TABLE visits($scope, place TEXT NOT NULL, PRIMARY KEY(family_id,child_id,place), $childFk)',
  ];
}
