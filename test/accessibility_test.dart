import 'dart:ui' show SemanticsAction;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/app/controller.dart';
import 'package:pennywood/app/paper_theme.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/money.dart';
import 'package:pennywood/features/wish_home.dart';
import 'database_service_test.dart' show MemoryCredentials;

void main() {
  late PennyDatabase db;
  late TownController c;
  setUp(() async {
    db = PennyDatabase(NativeDatabase.memory());
    final service = TownService(
      db,
      Auth(MemoryCredentials()),
      FixedClock('2026-11-01'),
    );
    await service.createFamily('real', '719385', ['小满', '小禾']);
    c = TownController(service, 'real', 'first');
    await c.load();
    await c.unlock('719385');
    await c.perform('configureQuick', ['dishes', 200, '洗净餐具']);
    c.lock();
    await c.perform('addWish', ['gift', '望远镜', 8000]);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<void> check(
    WidgetTester tester,
    Size size,
    Future<void> Function() body,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(theme: paperTheme(Brightness.light), home: WishHome(c)),
      );
      await tester.pumpAndSettle();
      await body();
    } finally {
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    }
  }

  Future<void> activate(WidgetTester tester, Finder finder) async {
    final node = tester.getSemantics(finder);
    expect(node, containsSemantics(hasTapAction: true));
    await tester.runAsync(() async {
      tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Sidebar semantics expose button and selection state following activation',
    (tester) async {
      await check(tester, const Size(1194, 834), () async {
        expect(
          tester.getSemantics(find.text('我的心愿')),
          containsSemantics(
            isButton: true,
            hasSelectedState: true,
            isSelected: true,
          ),
        );
        expect(
          tester.getSemantics(find.text('我的零钱')),
          containsSemantics(
            isButton: true,
            hasSelectedState: true,
            isSelected: false,
          ),
        );
        await activate(tester, find.text('我的零钱'));
        expect(find.text('我的每一分，都有来处'), findsOneWidget);
        expect(
          tester.getSemantics(find.text('我的零钱')),
          containsSemantics(isButton: true, isSelected: true),
        );
        expect(
          tester.getSemantics(find.text('我的心愿')),
          containsSemantics(isSelected: false),
        );
        expect(c.account.wallet, 0);
      });
    },
  );

  testWidgets(
    'Quick-task semantics submit or show status without crediting income',
    (tester) async {
      await check(tester, const Size(402, 874), () async {
        await activate(tester, find.text('我的任务'));
        final task = find.byKey(const Key('quick-dishes'));
        await tester.ensureVisible(task);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(task),
          containsSemantics(isButton: true, isEnabled: true),
        );
        expect(tester.getSemantics(task).label, contains('洗碗'));
        expect(tester.getSemantics(task).label, contains('2.00'));
        await activate(tester, task);
        expect(c.account.tasks.single.status, 'submitted');
        expect(c.account.wallet, 0);
        expect(tester.getSemantics(task).label, contains('待家长检查'));
        await activate(tester, task);
        expect(find.text('撤回这次提交'), findsOneWidget);
        await activate(tester, find.text('撤回这次提交'));
        expect(c.account.tasks.single.status, 'available');
        expect(c.account.wallet, 0);
      });
    },
  );

  testWidgets(
    'Savings-path entries expose button roles and open through semantic activation',
    (tester) async {
      await check(tester, const Size(1194, 834), () async {
        await activate(tester, find.text('我的零钱'));
        final entry = find.byKey(const Key('arrange-money'));
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        expect(tester.getSemantics(entry), containsSemantics(isButton: true));
        await activate(tester, entry);
        expect(find.textContaining('安排零钱 · 小满'), findsOneWidget);
        expect(c.account.wallet, 0);
      });
    },
  );

  testWidgets(
    'Wide-window child switching explains the action and preserves account isolation',
    (tester) async {
      await check(tester, const Size(1194, 834), () async {
        final profiles = find.byKey(const Key('profiles'));
        expect(tester.getSemantics(profiles).label, contains('切换孩子'));
        await activate(tester, profiles);
        expect(
          tester.getSemantics(find.byKey(const Key('switch-first'))),
          containsSemantics(isButton: true, isSelected: true),
        );
        final second = find.byKey(const Key('switch-second'));
        expect(tester.getSemantics(second), containsSemantics(isButton: true));
        await activate(tester, second);
        expect(c.child, 'second');
        expect(c.parent, isNull);
        expect(c.account.wallet, 0);
        expect(c.account.wishes, isEmpty);
      });
    },
  );

  testWidgets(
    'Wish semantics read amount, target, and progress while keeping management independent',
    (tester) async {
      await check(tester, const Size(1194, 834), () async {
        final amount = find.byKey(const Key('wish-progress-amount'));
        final ledger = c.account.ledger
            .map((l) => (l.id, l.kind, l.amount, l.operationId))
            .toList();
        final summary = tester.getSemantics(amount);
        expect(summary.label, '已确认积累 0.00 元，目标 80.00 元，进度 0%');
        expect(summary, containsSemantics(hasTapAction: false));
        final manage = find.byKey(const Key('manage-main-wish'));
        expect(tester.getSemantics(manage).id, isNot(summary.id));
        await activate(tester, manage);
        expect(find.text('编辑心愿'), findsOneWidget);
        expect(c.account.wallet, 0);
        expect(
          c.account.ledger.map((l) => (l.id, l.kind, l.amount, l.operationId)),
          ledger,
        );
      });
    },
  );

  testWidgets(
    'Cash statistics read purpose and amount separately with navigable headings',
    (tester) async {
      await check(tester, const Size(402, 874), () async {
        final ledger = c.account.ledger
            .map((l) => (l.id, l.kind, l.amount, l.operationId))
            .toList();
        await activate(tester, find.text('我的零钱'));
        expect(
          tester.getSemantics(find.text('我的每一分，都有来处')),
          containsSemantics(isHeader: true),
        );
        await activate(tester, find.text('账户明细'));
        for (final label in ['可用零钱', '持有本金', '待领取', '计划待还']) {
          final node = tester.getSemantics(find.text(label));
          expect(node.label, '$label 0.00 元');
          expect(node, containsSemantics(hasTapAction: false));
        }
        expect(c.account.wallet, 0);
        expect(
          c.account.ledger.map((l) => (l.id, l.kind, l.amount, l.operationId)),
          ledger,
        );
      });
    },
  );

  testWidgets(
    'Named page scrolling preserves independent navigation and task actions',
    (tester) async {
      await check(tester, const Size(402, 874), () async {
        SemanticsNode scrollNode() {
          final nodes = <SemanticsNode>[];
          void collect(SemanticsNode node) {
            if (node.getSemanticsData().scrollPosition != null) nodes.add(node);
            node.visitChildren((child) {
              collect(child);
              return true;
            });
          }

          collect(
            tester
                .binding
                .renderViews
                .single
                .owner!
                .semanticsOwner!
                .rootSemanticsNode!,
          );
          return nodes.first;
        }

        expect(scrollNode().label, '我的心愿内容');
        await activate(tester, find.text('我的任务'));
        final task = find.byKey(const Key('quick-dishes'));
        await tester.ensureVisible(task);
        await tester.pumpAndSettle();
        expect(tester.getSemantics(task).id, isNot(scrollNode().id));
        await activate(tester, task);
        expect(c.account.tasks.single.status, 'submitted');
        expect(c.account.wallet, 0);
        await activate(tester, find.text('我的任务'));
        expect(scrollNode().label, '我的任务内容');
        await activate(tester, find.text('我的零钱'));
        expect(scrollNode().label, '我的零钱内容');
        await activate(tester, find.byKey(const Key('parent-entry')));
        expect(scrollNode().label, '家长空间解锁');
        expect(c.parent, isNull);
      });
    },
  );
}
