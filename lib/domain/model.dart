import 'money.dart';

class Product {
  const Product(this.id, this.name, this.days, this.minimum);
  final String id, name;
  final int days, minimum;
  static const all = {
    'sprout': Product('sprout', '小树定期', 90, 1000),
    'annual': Product('annual', '年轮定期', 365, 5000),
    'dividend': Product('dividend', '小镇分红计划', 30, 1000),
  };
}

class LaborTask {
  LaborTask({
    required this.id,
    required this.name,
    required this.amount,
    this.detail = '分类摆好图书，和家长一起检查',
    this.status = 'available',
    this.templateId,
    this.businessDay,
    this.feedback = '',
  });
  final String id;
  String name, detail, status, feedback;
  final String? templateId, businessDay;
  int amount;
}

// Store recurring agreements separately from completions; instances snapshot the amount and standard.
class QuickTask {
  QuickTask({
    required this.id,
    required this.detail,
    this.amount = 0,
    this.enabled = false,
  });
  final String id;
  String detail;
  int amount;
  bool enabled;
  static const names = {
    'dishes': '洗碗',
    'mop': '拖地',
    'toys': '整理玩具',
    'vegetables': '摘菜',
    'study': '学习',
  };
  static const standards = {
    'dishes': '洗净自己的餐具，擦干水槽边的水，和家长一起检查',
    'mop': '拖净约定的区域，收好工具，小心湿滑',
    'toys': '按类别收好玩具，地面留出通道',
    'vegetables': '与家长一起挑出可用菜叶，清理桌面，不使用刀具',
    'study': '完成事先约好的阅读或探索，说说自己的发现',
  };
  String get name => names[id]!;
}

class Wish {
  Wish({
    required this.id,
    required this.name,
    required this.target,
    this.kind = 'gift',
    this.isMain = false,
    this.status = 'open',
    this.achievedOn,
    this.achievedAmount = 0,
    this.receivedOn,
    this.receivedCost = 0,
  });
  final String id;
  String name, kind;
  int target;
  bool isMain;
  String status;
  String? achievedOn, receivedOn;
  int achievedAmount, receivedCost;
  bool get completed =>
      receivedOn != null || (kind == 'saving' && achievedOn != null);
  bool get available => status == 'open' && !completed;
}

class Position {
  Position({
    required this.id,
    required this.product,
    required this.principal,
    required this.rateBps,
    required this.days,
    required this.start,
    required this.end,
    required this.expected,
    this.distribution = 'cash',
    this.status = 'active',
    this.termsVersion = 1,
  });
  final String id, product, start, end;
  final int principal, rateBps, days, expected, termsVersion;
  String status, distribution;
}

class Withdrawal {
  Withdrawal({
    required this.id,
    required this.amount,
    required this.purpose,
    required this.date,
    this.status = 'pending',
    this.wishId,
    this.usedForGift = false,
  });
  final String id, purpose, date;
  final int amount;
  String status;
  String? wishId;
  bool usedForGift;
}

class Installment {
  Installment({
    required this.due,
    required this.principal,
    required this.interest,
    this.paidPrincipal = 0,
    this.paidInterest = 0,
    this.waivedInterest = 0,
  });
  final String due;
  final int principal, interest;
  int paidPrincipal, paidInterest, waivedInterest;
  int get balance =>
      principal - paidPrincipal + interest - paidInterest - waivedInterest;
}

class LoanPayment {
  LoanPayment(this.date, this.amount, this.waived, this.mode);
  final String date, mode;
  final int amount, waived;
}

class Loan {
  Loan({
    required this.id,
    required this.item,
    required this.amount,
    required this.months,
    required this.first,
    required this.requested,
    this.rateBps = 0,
    this.status = 'pending',
    this.funded,
    this.wishId,
    this.usedForGift = false,
    List<Installment>? schedule,
  }) : schedule = schedule ?? [];
  final String id, item, requested;
  final int amount;
  int months, rateBps;
  String first, status;
  String? funded;
  String? wishId;
  bool usedForGift;
  List<Installment> schedule;
  final List<LoanPayment> payments = [];
  int get balance => schedule.fold(0, (v, p) => v + p.balance);
}

class LedgerEntry {
  LedgerEntry(
    this.id,
    this.date,
    this.kind,
    this.title,
    this.amount,
    this.reference, {
    this.operationId = 'legacy',
    this.actorRole = 'legacy',
  });
  final String id, date, kind, title, reference;
  String operationId, actorRole;
  final int amount;
}

class ChildAccount {
  ChildAccount({
    required this.id,
    required this.name,
    required this.date,
    this.wallet = 0,
    this.laborTotal = 0,
    this.bonusEarned = 0,
    this.withdrawn = 0,
    this.repaidTotal = 0,
    this.budget = 0,
    this.rateBps = 0,
    this.termsVersion = 1,
    this.sequence = 0,
    this.distribution = 'cash',
    this.goal = 19800,
    this.goalName = '第一架天文望远镜',
    this.weeklyPlan = 0,
    List<Wish>? wishes,
    List<QuickTask>? quickTasks,
    List<LaborTask>? tasks,
    List<Position>? positions,
    List<Withdrawal>? requests,
    List<Loan>? loans,
    List<LedgerEntry>? ledger,
  }) : wishes = wishes ?? [],
       quickTasks = quickTasks ?? [],
       tasks = tasks ?? [],
       positions = positions ?? [],
       requests = requests ?? [],
       loans = loans ?? [],
       ledger = ledger ?? [];
  final String id;
  String name, date, distribution, goalName;
  int wallet,
      laborTotal,
      bonusEarned,
      withdrawn,
      repaidTotal,
      budget,
      rateBps,
      termsVersion,
      sequence,
      goal,
      weeklyPlan;
  final List<Wish> wishes;
  final List<QuickTask> quickTasks;
  Wish? get mainWish =>
      wishes.where((w) => w.isMain && w.available).firstOrNull;
  LaborTask? quickInstance(String id) => tasks.reversed
      .where(
        (t) =>
            t.templateId == id && (t.status != 'paid' || t.businessDay == date),
      )
      .firstOrNull;
  final List<LaborTask> tasks;
  final List<Position> positions;
  final List<Withdrawal> requests;
  final List<Loan> loans;
  final List<LedgerEntry> ledger;
  Iterable<Position> get active => positions.where((p) => p.status == 'active');
  int get holding => active.fold(0, (v, p) => v + p.principal);
  int get reserved => active.fold(0, (v, p) => v + p.expected);
  int get pendingCash => requests
      .where((p) => p.status == 'pending')
      .fold(0, (v, p) => v + p.amount);
  int get assets => wallet + holding + pendingCash;
  int get freeBudget => budget - bonusEarned - reserved;
  int get debt =>
      loans.where((l) => l.status == 'active').fold(0, (v, l) => v + l.balance);
  int get conservative => assets - debt;
  String nextId(String prefix) => '$prefix-${++sequence}';
  void log(
    String kind,
    String title,
    int amount,
    String reference, {
    String? on,
  }) => ledger.add(
    LedgerEntry(nextId('history'), on ?? date, kind, title, amount, reference),
  );
  void check() {
    require(wallet >= 0 && assets <= Money.maxCents, '零钱不足或超过账户范围');
    require(freeBudget >= 0, '不能侵占已结算与已承诺的收益预算');
    require(
      assets == laborTotal + bonusEarned - withdrawn - repaidTotal,
      '账务核对未通过，本次操作未保存',
    );
    final received = <String, int>{};
    void checkPayment(String? wishId, bool used, bool paid, int amount) {
      require(!used || wishId != null, '到手付款缺少心愿关联');
      if (wishId == null) return;
      final wish = wishes.where((w) => w.id == wishId).firstOrNull;
      require(
        wish != null && wish.kind == 'gift' && wish.status != 'deleted',
        '付款心愿关联无效',
      );
      if (used) {
        require(paid && wish!.receivedOn != null, '到手记录必须关联实际完成的付款');
        received.update(wishId, (v) => v + amount, ifAbsent: () => amount);
      }
    }

    for (final r in requests) {
      checkPayment(r.wishId, r.usedForGift, r.status == 'paid', r.amount);
    }
    for (final l in loans) {
      checkPayment(
        l.wishId,
        l.usedForGift,
        l.funded != null && ['active', 'paid'].contains(l.status),
        l.amount,
      );
    }
    for (final w in wishes) {
      require(
        w.receivedOn == null
            ? w.receivedCost == 0 && !received.containsKey(w.id)
            : w.kind == 'gift' &&
                  w.receivedCost > 0 &&
                  received[w.id] == w.receivedCost,
        '礼物到手金额与原付款核对未通过',
      );
    }
  }
}

class SceneState {
  SceneState({
    this.x = 400,
    this.y = 380,
    this.evening = false,
    this.sound = false,
    this.zoom = 1,
    this.panX = 0,
    this.panY = 0,
    Set<String>? visited,
  }) : visited = visited ?? {};
  double x, y, zoom, panX, panY;
  bool evening, sound;
  Set<String> visited;
}
