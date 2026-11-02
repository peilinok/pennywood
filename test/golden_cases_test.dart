import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/domain/engine.dart';
import 'package:pennywood/domain/model.dart';
import 'package:pennywood/domain/money.dart';

ChildAccount fromFixture(Map<String, dynamic> r) {
  final s = ChildAccount(
    id: r['profileId'],
    name: r['child'],
    date: r['now'],
    wallet: r['wallet'],
    laborTotal: r['laborTotal'],
    bonusEarned: r['bonusEarned'],
    withdrawn: r['withdrawn'],
    repaidTotal: r['repaidTotal'],
    budget: r['budget'],
    rateBps: r['rateBps'],
    sequence: r['sequence'],
    distribution: r['distribution'],
    goal: r['goal'],
    goalName: r['goalName'] ?? '愿望',
    weeklyPlan: r['weeklyPlan'],
  );
  s.tasks.addAll([
    for (final t in r['tasks'])
      LaborTask(
        id: t['id'],
        name: t['name'],
        amount: t['amount'],
        detail: t['detail'],
        status: t['status'],
      ),
  ]);
  s.positions.addAll([
    for (final p in r['positions'])
      Position(
        id: p['id'],
        product: p['product'],
        principal: p['principal'],
        rateBps: p['rateBps'],
        days: p['days'],
        start: p['start'],
        end: p['end'],
        expected: p['expected'],
        distribution: p['distribution'] ?? 'cash',
        status: p['status'],
      ),
  ]);
  return s;
}

Map<String, Object?> summary(ChildAccount s) => {
  'date': s.date,
  'profileId': s.id,
  'walletCents': s.wallet,
  'holdingCents': s.holding,
  'pendingCashCents': s.pendingCash,
  'assetsCents': s.assets,
  'laborIncomeCents': s.laborTotal,
  'settledYieldCents': s.bonusEarned,
  'withdrawnCents': s.withdrawn,
  'repaidCents': s.repaidTotal,
  'plannedDebtCents': s.debt,
  'availableBudgetCents': s.freeBudget,
  'rateBps': s.rateBps,
  'distribution': s.distribution,
  'activePositions': [
    for (final p in s.active.toList().reversed)
      {
        'id': p.id,
        'product': p.product,
        'principal': p.principal,
        'rateBps': p.rateBps,
        'days': p.days,
        'start': p.start,
        'end': p.end,
        'expected': p.expected,
        'status': p.status,
        'distribution': p.distribution,
      },
  ],
  'tasks': [
    for (final t in s.tasks) {'id': t.id, 'status': t.status},
  ],
  'requests': [
    for (final r in s.requests.reversed)
      {
        'id': r.id,
        'amount': r.amount,
        'purpose': r.purpose,
        'date': r.date,
        'status': r.status,
      },
  ],
  'loans': [
    for (final l in s.loans.reversed)
      {
        'id': l.id,
        'item': l.item,
        'amount': l.amount,
        'months': l.months,
        'first': l.first,
        'rateBps': l.rateBps,
        'status': l.status,
        'requested': l.requested,
        'funded': l.funded,
        'schedule': [
          for (final p in l.schedule)
            {
              'due': p.due,
              'principal': p.principal,
              'interest': p.interest,
              'paidPrincipal': p.paidPrincipal,
              'paidInterest': p.paidInterest,
              'waivedInterest': p.waivedInterest,
            },
        ],
        'payments': [
          for (final p in l.payments)
            {
              'date': p.date,
              'amount': p.amount,
              'waived': p.waived,
              'mode': p.mode,
            },
        ],
      },
  ],
};
// Business IDs may be mapped; assert all amounts, states, dates, ownership, schedules, and payments.
void compare(Object? actual, Object? expected, {String path = ''}) {
  if (expected is Map) {
    expect(actual, isA<Map>(), reason: path);
    for (final k in expected.keys) {
      if (k == 'id') continue;
      compare((actual as Map)[k], expected[k], path: '$path.$k');
    }
  } else if (expected is List) {
    expect(actual, isA<List>(), reason: path);
    expect((actual as List).length, expected.length, reason: path);
    for (var i = 0; i < expected.length; i++) {
      compare(actual[i], expected[i], path: '$path[$i]');
    }
  } else {
    expect(actual, expected, reason: path);
  }
}

String? action(
  ChildAccount s,
  Map<String, dynamic> step,
  Map<String, String> bindings,
) {
  final args = [
    for (final a in (step['args'] as List? ?? []))
      if (a is String && a.startsWith(r'$')) bindings[a.substring(1)]! else a,
  ];
  if (step['method'] == 'advance') {
    Engine.catchUp(s, Day.add(s.date, args[0] as int));
    return null;
  }
  if (step['method'] == 'task') {
    return Engine.execute(s, args[1] as String, [args[0]]);
  }
  return Engine.execute(s, step['method'] as String, args);
}

void main() {
  final data =
      jsonDecode(File('reference/finance-golden-cases.json').readAsStringSync())
          as Map;
  for (final c in data['cases']) {
    test('Reference case ${c['id']} · ${c['title']}', () {
      if (c['scope'] == 'calendar') {
        for (final step in c['steps']) {
          final args = step['args'] as List;
          expect(
            step['method'] == 'valid'
                ? Day.valid(args[0])
                : Day.month(args[0], args[1]),
            step['expected'],
          );
        }
        return;
      }
      if (c['scope'] == 'family') {
        final children = [
          for (final r in c['initialState']['children'])
            fromFixture(Map<String, dynamic>.from(r)),
        ];
        for (final step in c['steps']) {
          if (step['method'] == 'advance') {
            for (final s in children) {
              Engine.catchUp(s, Day.add(s.date, step['args'][0]));
            }
          } else {
            final s = children.singleWhere((s) => s.id == step['childId']);
            for (final a in step['actions']) {
              action(s, Map<String, dynamic>.from(a), {});
            }
          }
          compare(children.map(summary).toList(), step['expected']['children']);
        }
        return;
      }
      final s = fromFixture(Map<String, dynamic>.from(c['initialState']));
      final bindings = <String, String>{};
      for (final raw in c['steps']) {
        final step = Map<String, dynamic>.from(raw),
            expected = step['expected'] as Map;
        String? result;
        var ok = true;
        try {
          result = action(s, step, bindings);
        } on RuleViolation {
          ok = false;
        }
        expect(
          ok,
          expected['ok'],
          reason: '${c['id']} ${step['method']} ${step['args']}',
        );
        if (step['saveResultIdAs'] != null && result != null) {
          bindings[step['saveResultIdAs']] = result;
        }
        compare(summary(s), expected['stateSummary']);
        s.check();
      }
    });
  }
  test(
    'Money rejects floating-point drift and invalid input and rounds half cents up',
    () {
      expect(Money.parse('20.30'), 2030);
      expect(Money.interest(10000, 300, 365), 300);
      expect(Money.monthly(100, 600), 1);
      for (final invalid in [
        '1.001',
        '-1',
        'NaN',
        '1e3',
        '999999999999999999999',
      ]) {
        expect(() => Money.parse(invalid), throwsA(isA<RuleViolation>()));
      }
    },
  );
  test(
    'Principal remainder goes to the final installment and dates retain the original day',
    () {
      final schedule = Engine.schedule(10000, 3, '2028-01-31', 600);
      expect(schedule.map((p) => p.principal), [3333, 3333, 3334]);
      expect(schedule.map((p) => p.due), [
        '2028-01-31',
        '2028-02-29',
        '2028-03-31',
      ]);
    },
  );
}
