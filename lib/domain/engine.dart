import 'dart:math' as math;
import 'model.dart';
import 'money.dart';
import 'market.dart';

// Pure Dart rules; callers read an isolated copy in a transaction and commit once on success.
class Engine {
  static const parentActions = {
    'configureQuick',
    'setQuickEnabled',
    'editTask',
    'cancelTask',
    'receiveGift',
    'requestChanges',
    'approve',
    'pay',
    'addTask',
    'settings',
    'familyRates',
    'marketPermission',
    'payRequest',
    'offerLoan',
    'fundLoan',
    'rejectLoan',
  };
  static String? execute(ChildAccount s, String action, List<Object?> args) {
    String text(int i) => args[i] as String;
    int number(int i) => args[i] as int;
    String? result;
    switch (action) {
      case 'configureQuick':
        require(QuickTask.names.containsKey(text(0)), '常做任务不存在');
        require(number(1) >= 100 && number(1) <= 20000, '约定报酬范围为 1–200 元');
        require(
          text(2).trim().isNotEmpty && text(2).trim().length <= 200,
          '请填写 1–200 字的完成标准',
        );
        var q = s.quickTasks.where((q) => q.id == text(0)).firstOrNull;
        if (q == null) {
          q = QuickTask(id: text(0), detail: text(2).trim());
          s.quickTasks.add(q);
        }
        q.amount = number(1);
        q.detail = text(2).trim();
        q.enabled = true;
        s.log('agreement', '约定${q.name}的标准和报酬，仅影响新实例', q.amount, q.id);
      case 'setQuickEnabled':
        final q = s.quickTasks.where((q) => q.id == text(0)).firstOrNull;
        require(q != null && q.amount > 0, '请先约定标准与报酬');
        q!.enabled = args[1] as bool;
        s.log(
          'agreement',
          '${q.enabled ? '恢复' : '暂停'}${q.name}，已有任务承诺保留',
          0,
          q.id,
        );
      case 'quickSubmit':
        final q = s.quickTasks.where((q) => q.id == text(0)).firstOrNull;
        var t = s.quickInstance(text(0));
        require(q != null && (q.enabled || t != null), '任务未约定或已暂停，请和家长商量');
        require(
          t == null ||
              ['available', 'accepted', 'needsWork'].contains(t.status),
          '这次任务已提交或今天已完成，请查看状态',
        );
        if (t == null) {
          t = LaborTask(
            id: 'quick-${q!.id}-${s.date}',
            name: q.name,
            amount: q.amount,
            detail: q.detail,
            templateId: q.id,
            businessDay: s.date,
          );
          s.tasks.add(t);
        }
        t.status = 'submitted';
        result = t.id;
        s.log('task', '${t.name} · 待家长检查', 0, t.id);
      case 'withdrawTask':
      case 'requestChanges':
        final t = s.tasks.where((t) => t.id == text(0)).firstOrNull;
        require(t != null && t.status == 'submitted', '家长已处理，这次任务不能再撤回或修改');
        if (action == 'requestChanges') {
          require(
            text(1).trim().isNotEmpty && text(1).trim().length <= 200,
            '请留下具体的改进建议，最多 200 字',
          );
          t!.feedback = text(1).trim();
          t.status = 'needsWork';
        } else {
          t!.status = t.templateId == null ? 'accepted' : 'available';
        }
        s.log(
          'task',
          '${t.name} · ${action == 'requestChanges' ? '再试试：${t.feedback}' : '孩子撤回，尚未入账'}',
          0,
          t.id,
        );
      case 'addWish':
        require(['gift', 'saving'].contains(text(0)), '请选择礼物或攒钱心愿');
        require(
          text(1).trim().isNotEmpty && text(1).trim().length <= 30,
          '心愿名称需为 1–30 个字',
        );
        require(number(2) > 0 && number(2) <= Money.maxCents, '请填写大于零的目标金额');
        final w = Wish(
          id: s.nextId('wish'),
          name: text(1).trim(),
          target: number(2),
          kind: text(0),
          isMain: s.mainWish == null,
        );
        s.wishes.add(w);
        if (w.isMain) {
          s.goalName = w.name;
          s.goal = w.target;
        }
        result = w.id;
        s.log('goal', '写下心愿 · ${w.name}', 0, w.id);
      case 'selectWish':
        final w = s.wishes.where((w) => w.id == text(0)).firstOrNull;
        require(w != null && w.available, '请选择尚未完成、未归档的心愿');
        for (final item in s.wishes) {
          item.isMain = item.id == w!.id;
        }
        s.goalName = w!.name;
        s.goal = w.target;
        s.log('goal', '头号心愿 · ${w.name}', 0, w.id);
      case 'editWish':
        final w = wish(s, text(0));
        require(w.available && w.achievedOn == null, '已有完成纪念的心愿保留原目标，可归档后新建');
        require(['gift', 'saving'].contains(text(1)), '请选择礼物或攒钱心愿');
        require(
          w.kind == text(1) || !hasWishPayments(s, w.id),
          '已关联付款的心愿保留原类型，请归档后新建',
        );
        require(
          text(2).trim().isNotEmpty && text(2).trim().length <= 30,
          '心愿名称需为 1–30 个字',
        );
        require(number(3) > 0 && number(3) <= Money.maxCents, '请填写大于零的目标金额');
        w.kind = text(1);
        w.name = text(2).trim();
        w.target = number(3);
        if (w.isMain) {
          s.goalName = w.name;
          s.goal = w.target;
        }
        s.log('goal', '调整心愿 · ${w.name}', 0, w.id);
      case 'deleteWish':
      case 'archiveWish':
        final w = wish(s, text(0));
        require(w.status == 'open', '这份心愿已整理');
        require(
          action != 'deleteWish' ||
              (w.achievedOn == null &&
                  w.receivedOn == null &&
                  !hasWishPayments(s, w.id)),
          '已有完成或付款记录，请归档保留历史',
        );
        w.status = action == 'deleteWish' ? 'deleted' : 'archived';
        releaseWish(s, w);
        s.log(
          'goal',
          '${action == 'deleteWish' ? '删除未完成心愿' : '归档心愿'} · ${w.name}',
          0,
          w.id,
        );
      case 'restoreWish':
        final w = wish(s, text(0));
        require(w.status == 'archived' && !w.completed, '只有未完成的归档心愿可以回到排队');
        w.status = 'open';
        s.log('goal', '心愿回到排队 · ${w.name}', 0, w.id);
      case 'markSaved':
        final w = wish(s, text(0));
        require(
          w.available && w.isMain && w.achievedOn == null,
          '请选择尚未记录攒够的头号心愿',
        );
        require(s.conservative >= w.target, '真实积累还未达到目标；预计收益和借款不算');
        w.achievedOn = s.date;
        w.achievedAmount = s.conservative;
        if (w.kind == 'saving') releaseWish(s, w);
        s.log(
          'wish-saved',
          '攒够纪念 · ${w.name} · 当时积累 ${Money.format(w.achievedAmount)} 元',
          0,
          w.id,
        );
      case 'receiveGift':
        final w = wish(s, text(0));
        require(w.kind == 'gift' && w.available, '请选择尚未到手、未归档的礼物心愿');
        final withdrawals = <Withdrawal>[];
        final loans = <Loan>[];
        for (final id in paymentIds(args[1])) {
          final r = s.requests.where((r) => r.id == id).firstOrNull;
          require(r != null && r.status == 'paid', '自付需属于当前孩子，且已由家长确认实际交付');
          require(
            !r!.usedForGift && (r.wishId == null || r.wishId == w.id),
            '这笔自付已关联另一心愿或已登记到手',
          );
          withdrawals.add(r);
        }
        for (final id in paymentIds(args[2])) {
          final l = s.loans.where((l) => l.id == id).firstOrNull;
          require(
            l != null &&
                l.funded != null &&
                ['active', 'paid'].contains(l.status),
            '预支需属于当前孩子，且家长已实际垫付',
          );
          require(
            !l!.usedForGift && (l.wishId == null || l.wishId == w.id),
            '这笔垫付已关联另一心愿或已登记到手',
          );
          loans.add(l);
        }
        final cost =
            withdrawals.fold<int>(0, (v, r) => v + r.amount) +
            loans.fold<int>(0, (v, l) => v + l.amount);
        require(cost > 0 && cost == number(3), '实际购买金额必须等于已交付自付加已垫付本金');
        // Validate every payment before linking; failure leaves no partial gift receipt.
        for (final r in withdrawals) {
          r.wishId = w.id;
          r.usedForGift = true;
        }
        for (final l in loans) {
          l.wishId = w.id;
          l.usedForGift = true;
        }
        w.receivedOn = s.date;
        w.receivedCost = cost;
        releaseWish(s, w);
        s.log(
          'wish-received',
          '礼物已到手 · ${w.name} · 实际 ${Money.format(cost)} 元，关联原付款，不再扣款',
          0,
          w.id,
        );
      case 'accept':
      case 'submit':
      case 'approve':
      case 'pay':
        final t = s.tasks.where((t) => t.id == text(0)).firstOrNull;
        final states = {
          'accept': ['available', 'accepted'],
          'submit': ['accepted', 'submitted'],
          'approve': ['submitted', 'confirmed'],
          'pay': ['confirmed', 'paid'],
        };
        require(
          t != null &&
              (t.status == states[action]![0] ||
                  (action == 'submit' && t.status == 'needsWork')),
          '这项委托已经更新，请查看最新进度',
        );
        t!.status = states[action]![1];
        if (action == 'pay') {
          s.wallet += t.amount;
          s.laborTotal += t.amount;
        }
        s.log(
          action == 'pay' ? 'income' : 'task',
          '${t.name} · ${taskLabel(t.status)}',
          action == 'pay' ? t.amount : 0,
          t.id,
        );
      case 'editTask':
      case 'cancelTask':
        final t = s.tasks.where((t) => t.id == text(0)).firstOrNull;
        require(
          t != null && t.templateId == null && t.status == 'available',
          '仅可调整尚未接下的临时任务，已有承诺保留',
        );
        if (action == 'cancelTask') {
          t!.status = 'cancelled';
        } else {
          taskTerms(text(1), number(2), text(3));
          t!.name = text(1).trim();
          t.amount = number(2);
          t.detail = text(3).trim();
        }
        s.log(
          'task',
          '${action == 'cancelTask' ? '停用' : '编辑'}临时任务 · ${t.name}',
          0,
          t.id,
        );
      case 'addTask':
        require(
          text(0).trim().isNotEmpty && text(0).trim().length <= 30,
          '委托名称需为 1–30 个字',
        );
        require(number(1) >= 100 && number(1) <= 20000, '委托报酬范围为 1–200 元');
        final detail = args.length > 2 ? text(2).trim() : '请和家长事前商量完成标准';
        taskTerms(text(0), number(1), detail);
        final t = LaborTask(
          id: s.nextId('task'),
          name: text(0).trim(),
          amount: number(1),
          detail: detail,
        );
        s.tasks.add(t);
        result = t.id;
        s.log('task', '新增委托：${t.name}', 0, t.id);
      case 'buy':
        result = buy(s, text(0), number(1), text(2)).id;
      case 'redeem':
        final p = position(s, text(0));
        if (Product.all[p.product]!.market) {
          settleMarket(s, p, s.date, 'redeemed');
          break;
        }
        final elapsed = Day.difference(p.start, s.date).clamp(0, p.days);
        final profit = Money.interest(
          p.principal,
          math.min(10, p.rateBps),
          elapsed,
        );
        p.status = 'redeemed';
        s.wallet += p.principal + profit;
        s.bonusEarned += profit;
        s.log(
          'yield',
          '提前取回${Product.all[p.product]!.name}，本金完整返还',
          profit,
          p.id,
        );
      case 'distributionMode':
        final p = position(s, text(0));
        require(p.product == 'dividend', '这份持有不是分红计划');
        mode(text(1));
        p.distribution = text(1);
        s.distribution = text(1);
        s.log('choice', '下次分红：${text(1) == 'cash' ? '现金分红' : '红利再投'}', 0, p.id);
      case 'request':
        final amount = number(0);
        require(amount >= 100 && amount <= s.wallet, '领取需至少 1 元且不能超过可用零钱');
        final wishId = linkedGift(
          s,
          args.length > 2 ? args[2] as String? : null,
        );
        s.wallet -= amount;
        final r = Withdrawal(
          id: s.nextId('request'),
          amount: amount,
          purpose: text(1).trim().isEmpty ? '我的小小计划' : text(1).trim(),
          date: s.date,
          wishId: wishId,
        );
        s.requests.add(r);
        result = r.id;
        s.log('request', '申请领取 · ${r.purpose}', amount, r.id);
      case 'payRequest':
        final r = s.requests
            .where((r) => r.id == text(0) && r.status == 'pending')
            .firstOrNull;
        require(r != null, '领取已处理');
        r!.status = 'paid';
        s.withdrawn += r.amount;
        s.log('withdraw', '家长已实际交付 · ${r.purpose}', r.amount, r.id);
      case 'marketPermission':
        s.marketEnabled = args[0] as bool;
        s.log(
          'permission',
          s.marketEnabled ? '家长允许家庭波动投资：可能损失本金' : '家长暂停新波动投资，已有持有条款保留',
          0,
          'market',
        );
      case 'familyRates':
        final products = ['sprout', 'annual', 'dividend'];
        require(args.length == products.length, '请分别填写三种产品利率');
        for (var i = 0; i < products.length; i++) {
          require(number(i) >= 0 && number(i) <= 1000, '家庭约定年化范围为 0%–10%');
        }
        for (var i = 0; i < products.length; i++) {
          final id = products[i];
          if (s.rateFor(id) != number(i)) {
            s.productVersions[id] = s.versionFor(id) + 1;
          }
          s.productRates[id] = number(i);
        }
        s.log('settings', '更新家庭共用产品利率，已有持有约定保留', 0, 'family-rates');
      case 'settings':
        require(
          number(0) >= s.bonusEarned + s.marketSpent + s.reserved &&
              number(0) <= Money.maxCents,
          '预算必须覆盖已承担及预留的收益',
        );
        if (args.length > 2) {
          require(number(1) >= 0 && number(1) <= 1000, '家庭约定年化范围为 0%–10%');
        }
        require(
          text(args.length > 2 ? 2 : 1).trim().isNotEmpty &&
              text(args.length > 2 ? 2 : 1).trim().length <= 8,
          '孩子称呼需为 1–8 个字',
        );
        if (args.length > 2) {
          if (s.rateBps != number(1)) s.termsVersion++;
          s.rateBps = number(1);
          for (final id in ['sprout', 'annual', 'dividend']) {
            if (s.rateFor(id) != number(1)) {
              s.productVersions[id] = s.versionFor(id) + 1;
            }
            s.productRates[id] = number(1);
          }
        }
        s.budget = number(0);
        s.name = text(args.length > 2 ? 2 : 1).trim();
        s.log(
          'settings',
          '家长更新新计划的利率和阶段预算，已有约定保留',
          0,
          'terms-${s.termsVersion}',
        );
      case 'goal':
        require(
          text(0).trim().isNotEmpty &&
              text(0).trim().length <= 30 &&
              number(1) > 0 &&
              number(1) <= Money.maxCents &&
              number(2) >= 0 &&
              number(2) <= Money.maxCents,
          '请填写愿望、正数目标和有效的每周计划',
        );
        s.goalName = text(0).trim();
        s.goal = number(1);
        s.weeklyPlan = number(2);
        if (s.mainWish case final w?) {
          require(w.achievedOn == null, '已有攒够纪念的心愿保留原目标，请另写新心愿');
          w.name = s.goalName;
          w.target = s.goal;
        } else {
          s.wishes.add(
            Wish(
              id: s.nextId('wish'),
              name: s.goalName,
              target: s.goal,
              isMain: true,
            ),
          );
        }
        s.log('goal', '更新愿望 · ${s.goalName}', 0, 'goal');
      case 'loanRequest':
        require(
          text(0).trim().isNotEmpty &&
              text(0).trim().length <= 30 &&
              number(1) >= 100 &&
              number(1) <= 100000,
          '用途需 1–30 个字，预支金额为 1–1000 元',
        );
        loanTerms(s.date, number(2), text(3), 0);
        final wishId = linkedGift(
          s,
          args.length > 4 ? args[4] as String? : null,
        );
        require(
          !s.loans.any(
            (l) =>
                ['pending', 'offered', 'approved', 'active'].contains(l.status),
          ),
          '请先安排已有预支',
        );
        final l = Loan(
          id: s.nextId('loan'),
          item: text(0).trim(),
          amount: number(1),
          months: number(2),
          first: text(3),
          requested: s.date,
          wishId: wishId,
        );
        s.loans.add(l);
        result = l.id;
        s.log('loan-request', '提出预支 · ${l.item}，尚未形成欠款', l.amount, l.id);
      case 'offerLoan':
        final l = loan(s, text(0), ['pending', 'offered']);
        loanTerms(s.date, number(1), text(2), number(3));
        l.months = number(1);
        l.first = text(2);
        l.rateBps = number(3);
        l.schedule = schedule(l.amount, l.months, l.first, l.rateBps);
        l.status = 'offered';
        s.log('loan-offer', '家长提出条件 · ${l.item}', 0, l.id);
      case 'acceptLoan':
        final l = loan(s, text(0), ['offered']);
        require(l.first.compareTo(s.date) > 0, '首次还款日已到，请重新约定');
        l.status = 'approved';
        s.log('loan-accept', '孩子接受条件，等待实际垫付', 0, l.id);
      case 'fundLoan':
        final l = loan(s, text(0), ['approved']);
        require(l.first.compareTo(s.date) > 0, '还款日已到，请撤回后重新约定');
        l.status = 'active';
        l.funded = s.date;
        s.log('loan-funded', '家长已实际垫付购买 · ${l.item}', l.amount, l.id);
      case 'cancelLoan':
      case 'rejectLoan':
        final l = loan(
          s,
          text(0),
          action == 'cancelLoan'
              ? ['pending', 'offered', 'approved']
              : ['pending', 'offered'],
        );
        l.status = action == 'cancelLoan' ? 'cancelled' : 'rejected';
        s.log(
          'loan-cancel',
          '预支${action == 'cancelLoan' ? '撤回' : '拒绝'}，没有形成欠款',
          0,
          l.id,
        );
      case 'repayment':
        repay(s, text(0), text(1));
      default:
        throw const RuleViolation('未知业务操作');
    }
    s.check();
    return result;
  }

  static String taskLabel(String status) =>
      const {
        'needsWork': '需要再试试',
        'available': '可以完成',
        'accepted': '已接受',
        'submitted': '待家长检查',
        'confirmed': '待兑现',
        'paid': '已兑现',
        'cancelled': '已停用',
      }[status] ??
      status;
  static Wish wish(ChildAccount s, String id) {
    final w = s.wishes
        .where((w) => w.id == id && w.status != 'deleted')
        .firstOrNull;
    require(w != null, '心愿不存在或不属于这个孩子');
    return w!;
  }

  static bool hasWishPayments(ChildAccount s, String id) =>
      s.requests.any((r) => r.wishId == id) ||
      s.loans.any((l) => l.wishId == id);

  static String? linkedGift(ChildAccount s, String? id) {
    if (id == null || id.isEmpty) return null;
    final w = wish(s, id);
    require(w.kind == 'gift' && w.available, '请选择尚未到手、未归档的礼物心愿');
    return w.id;
  }

  // Retain legacy single-payment command reads; the current UI always sends payment lists.
  static List<String> paymentIds(Object? value) {
    final List<String> ids;
    if (value is String) {
      ids = value.isEmpty ? [] : [value];
    } else {
      require(
        value is List && value.every((id) => id is String && id.isNotEmpty),
        '请选择有效的付款记录',
      );
      ids = (value as List).cast<String>();
    }
    require(ids.toSet().length == ids.length, '同一笔付款不能重复选择');
    return ids;
  }

  static void releaseWish(ChildAccount s, Wish w) {
    if (!w.isMain) return;
    w.isMain = false;
    s.goal = 0;
    s.goalName = '';
  }

  static void taskTerms(String name, int amount, String detail) {
    require(
      name.trim().isNotEmpty && name.trim().length <= 30,
      '任务名称需为 1–30 个字',
    );
    require(amount >= 100 && amount <= 20000, '约定报酬范围为 1–200 元');
    require(
      detail.trim().isNotEmpty && detail.trim().length <= 200,
      '请填写 1–200 字的完成标准',
    );
  }

  static void mode(String m) =>
      require(['cash', 'reinvest'].contains(m), '请选择现金分红或红利再投');
  static Position position(ChildAccount s, String id) {
    final p = s.active.where((p) => p.id == id).firstOrNull;
    require(p != null, '持有已结算或不属于当前孩子');
    return p!;
  }

  static Loan loan(ChildAccount s, String id, List<String> statuses) {
    final l = s.loans
        .where((l) => l.id == id && statuses.contains(l.status))
        .firstOrNull;
    require(l != null, '预支状态已更新或不属于当前孩子');
    return l!;
  }

  static Position buy(
    ChildAccount s,
    String key,
    int amount,
    String distribution, {
    String? on,
  }) {
    final p = Product.all[key];
    mode(distribution);
    require(p != null, '课堂产品不能使用劳动本金交易');
    require(amount >= p!.minimum && amount <= s.wallet, '未达到起存金额或可用零钱不足');
    require(!p.market || s.marketEnabled, '请先由家长允许波动投资，并一起了解本金亏损');
    final expected = p.market
        ? TeachingMarket.reserve(key, amount)
        : Money.interest(amount, s.rateFor(key), p.days);
    require(expected <= s.freeBudget, '家长可用收益预算不足，已有约定不受影响');
    final date = on ?? s.date;
    final pos = Position(
      id: s.nextId('position'),
      product: key,
      principal: amount,
      rateBps: p.market ? 0 : s.rateFor(key),
      days: p.days,
      start: date,
      end: Day.add(date, p.days),
      expected: expected,
      distribution: distribution,
      termsVersion: p.market ? 1 : s.versionFor(key),
    );
    s.wallet -= amount;
    s.positions.add(pos);
    s.log(
      'invest',
      '存入${p.name} · 已预留收益 ${Money.format(expected)} 元',
      amount,
      pos.id,
      on: date,
    );
    return pos;
  }

  static void catchUp(ChildAccount s, String today) {
    Day.parse(today);
    require(today.compareTo(s.date) >= 0, '家庭日期不能倒退，请检查设备日期');
    s.date = today;
    while (true) {
      final due = s.active.where((p) => p.end.compareTo(today) <= 0).toList()
        ..sort((a, b) => a.end.compareTo(b.end));
      if (due.isEmpty) break;
      final p = due.first;
      if (Product.all[p.product]!.market) {
        settleMarket(s, p, p.end, 'matured');
        continue;
      }
      p.status = 'matured';
      s.wallet += p.principal + p.expected;
      s.bonusEarned += p.expected;
      s.log(
        'yield',
        '${Product.all[p.product]!.name}到期 · 本期收益',
        p.expected,
        p.id,
        on: p.end,
      );
      if (p.product == 'dividend') {
        final amount =
            p.principal + (p.distribution == 'reinvest' ? p.expected : 0);
        // Compare terms versions too: raising a rate and reverting it must not silently renew old terms.
        final nextYield = Money.interest(amount, p.rateBps, p.days);
        if (p.rateBps == s.rateFor(p.product) &&
            p.termsVersion == s.versionFor(p.product) &&
            nextYield <= s.freeBudget) {
          buy(s, p.product, amount, p.distribution, on: p.end);
        } else {
          s.log('renewal-stop', '续期需重新安排，本金和收益留在钱包', 0, p.id, on: p.end);
        }
      }
    }
    s.check();
  }

  static void settleMarket(
    ChildAccount s,
    Position p,
    String date,
    String status,
  ) {
    final profit = TeachingMarket.profit(p, date);
    p.status = status;
    s.wallet += p.principal + profit;
    s.marketReturn += profit;
    s.marketSpent += math.max(0, profit);
    s.log(
      'market-return',
      '${Product.all[p.product]!.name} · ${profit < 0 ? '本金发生亏损' : '收益已结算'}',
      profit,
      p.id,
      on: date,
    );
  }

  static void loanTerms(String now, int months, String first, int bps) {
    require(
      months >= 1 && months <= 12 && bps >= 0 && bps <= 1200,
      '期数 1–12 个月，约定年利率 0%–12%',
    );
    Day.parse(first);
    require(first.compareTo(now) > 0, '首次还款日应在今天之后');
  }

  static List<Installment> schedule(
    int amount,
    int months,
    String first,
    int bps,
  ) {
    require(
      amount >= 100 &&
          amount <= 100000 &&
          months >= 1 &&
          months <= 12 &&
          bps >= 0 &&
          bps <= 1200,
      '预支条件无效',
    );
    Day.parse(first);
    var remaining = amount;
    return List.generate(months, (i) {
      final principal = i == months - 1 ? remaining : amount ~/ months;
      final interest = Money.monthly(remaining, bps);
      remaining -= principal;
      return Installment(
        due: Day.month(first, i),
        principal: principal,
        interest: interest,
      );
    });
  }

  static void repay(ChildAccount s, String id, String mode) {
    require(['installment', 'settle'].contains(mode), '还款方式无效');
    final l = loan(s, id, ['active']);
    final next = l.schedule.where((p) => p.balance > 0).firstOrNull;
    require(next != null, '预支已还清');
    final settle = mode == 'settle';
    require(settle || next!.due.compareTo(s.date) <= 0, '月供还未到期，可以选择提前结清');
    final rows = settle ? l.schedule : [next!];
    final amount = rows.fold<int>(
      0,
      (v, p) =>
          v +
          p.principal -
          p.paidPrincipal +
          (p.due.compareTo(s.date) <= 0
              ? p.interest - p.paidInterest - p.waivedInterest
              : 0),
    );
    require(s.wallet >= amount, '零钱不足，本次整笔拒绝；不自动扣款、不加罚息');
    var waived = 0;
    for (final p in rows) {
      p.paidPrincipal = p.principal;
      if (p.due.compareTo(s.date) <= 0) {
        p.paidInterest = p.interest;
      } else {
        waived += p.interest - p.paidInterest - p.waivedInterest;
        p.waivedInterest = p.interest - p.paidInterest;
      }
    }
    s.wallet -= amount;
    s.repaidTotal += amount;
    l.payments.add(LoanPayment(s.date, amount, waived, mode));
    if (l.balance == 0) l.status = 'paid';
    s.log(
      'repay',
      '${settle ? '提前结清' : '主动偿还一期'} · ${l.item} · 免除未来利息 ${Money.format(waived)} 元',
      amount,
      l.id,
    );
  }
}
