import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app/controller.dart';
import '../app/paper_theme.dart';
import '../app/screens.dart' show field, tell, userMessage;
import '../domain/engine.dart';
import '../domain/model.dart';
import '../domain/money.dart';

int months(String value) {
  final n = int.tryParse(value);
  require(n != null && n >= 1 && n <= 12, '期数请填写 1–12 之间的整数');
  return n!;
}

class TownPanel extends StatefulWidget {
  const TownPanel(this.controller, this.initial, {super.key});
  final TownController controller;
  final String initial;
  @override
  State<TownPanel> createState() => _TownPanelState();
}

class _TownPanelState extends State<TownPanel> {
  TownController get c => widget.controller;
  ChildAccount get s => c.account;
  late String tab;
  final pin = TextEditingController();
  String? error;
  int years = 10;
  bool contribute = false;
  @override
  void initState() {
    super.initState();
    tab = widget.initial;
  }

  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  Future<void> run(String action, List<Object?> args, {String? op}) async {
    try {
      await c.perform(action, args, operationId: op);
      if (mounted) tell(context, '已保存，${s.name}的记录已更新');
    } catch (e) {
      if (mounted) tell(context, e);
    }
  }

  Future<bool> confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(body)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('再想想'),
            ),
            FilledButton(
              key: const Key('confirm-action'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认'),
            ),
          ],
        ),
      ) ??
      false;
  Future<List<String>?> form(
    String title,
    List<(String, String)> fields, {
    String? note,
    String? distribution,
  }) => showDialog<List<String>>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        BookForm(title, fields, note: note, distribution: distribution),
  );
  Widget button(String label, VoidCallback onTap, {String? key}) => Padding(
    padding: const EdgeInsets.only(right: 8, bottom: 6),
    child: FilledButton.tonal(
      key: key == null ? null : Key(key),
      onPressed: c.busy ? null : onTap,
      child: Text(label),
    ),
  );
  Widget paper(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: PaperColors.of(context).surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: PaperColors.of(context).line),
    ),
    child: child,
  );
  Widget note(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: PaperColors.of(context).muted,
        height: 1.6,
      ),
    ),
  );
  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    ),
  );
  Widget intro(String room, String speech) => LayoutBuilder(
    builder: (context, constraints) {
      final illustration = SvgPicture.asset(
        'assets/svg/room-$room.svg',
        width: 132,
        height: 88,
      );
      final dialogue = paper(
        Row(
          children: [
            SvgPicture.asset('assets/svg/mascot.svg', width: 38, height: 45),
            const SizedBox(width: 12),
            Expanded(child: Text(speech)),
          ],
        ),
      );
      if (constraints.maxWidth < 480) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [illustration, const SizedBox(height: 12), dialogue],
        );
      }
      return Row(
        children: [
          illustration,
          const SizedBox(width: 14),
          Expanded(child: dialogue),
        ],
      );
    },
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: SizedBox(
          width: 1040,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 10, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${title(tab)} · ${s.name}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (c.demo) const Chip(label: Text('独立示例')),
                    IconButton(
                      key: const Key('close-panel'),
                      tooltip: '关闭面板',
                      onPressed: () {
                        if (widget.initial == 'parent') c.lock();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (c.busy) const LinearProgressIndicator(minHeight: 2),
              Flexible(
                child: SingleChildScrollView(
                  key: PageStorageKey(tab),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: content(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  String title(String id) =>
      const {
        'tasks': '委托小铺',
        'savings': '储蓄小屋',
        'wish': '愿望工坊',
        'growth': '时光树 · 成长手账',
        'journal': '我的零钱口袋',
        'loans': '预支与主动还款',
        'parent': '家长空间',
        'lesson': '产品小课堂',
      }[id] ??
      id;
  List<Widget> content() => switch (tab) {
    'tasks' => tasks(),
    'savings' => savings(),
    'journal' => wallet(),
    'wish' => wish(),
    'growth' => growth(),
    'loans' => loans(),
    'parent' => parent(),
    'lesson' => lesson(),
    _ => [],
  };

  List<Widget> tasks() => [
    intro('tasks', '我是小铺掌柜。先和家长说好要求，再到现实里完成劳动。接下与提交都不会增加零钱。'),
    for (final t in s.tasks)
      paper(
        Row(
          children: [
            const Icon(
              Icons.auto_stories_outlined,
              size: 32,
              color: Color(0xFF9B9765),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${t.detail}\n${Engine.taskLabel(t.status)}',
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),
            Text(
              '¥${Money.format(t.amount)}  ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (t.status == 'available')
              button(
                '接下委托',
                () => run('accept', [t.id]),
                key: 'accept-${t.id}',
              ),
            if (t.status == 'accepted')
              button('现实中完成，提交', () async {
                if (await confirm(
                  '已经在现实里完成了吗？',
                  '${t.name}\n${t.detail}\n提交后请家长检查；此时不会增加零钱。',
                )) {
                  await run('submit', [t.id]);
                }
              }, key: 'submit-${t.id}'),
          ],
        ),
      ),
    note('家长检查完成和确认报酬兑现是两步。兑现前不会入账，探索小镇也不会发钱。'),
  ];
  List<Widget> savings() => [
    intro('savings', '我是阿栗。你赚来的钱值得认真安排。预计收益要等到约定日期结算，才成为零钱。'),
    paper(
      Text(
        '可用零钱 ¥${Money.format(s.wallet)} · 持有本金 ¥${Money.format(s.holding)}\n家长新计划年化 ${(s.rateBps / 100).toStringAsFixed(2)}% · 可用收益预算 ¥${Money.format(s.freeBudget)}',
      ),
    ),
    Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final p in Product.all.values)
          SizedBox(
            width: 245,
            child: paper(
              Column(
                children: [
                  SvgPicture.asset(
                    'assets/svg/tree-annual.svg',
                    width: 70,
                    height: 80,
                  ),
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${p.days} 天${p.id == 'dividend' ? '一期' : '到期'} · ${p.minimum ~/ 100} 元起',
                  ),
                  const SizedBox(height: 8),
                  button('了解并存入', () => deposit(p), key: 'deposit-${p.id}'),
                ],
              ),
            ),
          ),
      ],
    ),
    heading('我的持有'),
    if (s.active.isEmpty) note('还没有持有计划，先慢慢攒起来。'),
    for (final p in s.active)
      paper(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Product.all[p.product]!.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              '本金 ¥${Money.format(p.principal)} · 本期年化 ${(p.rateBps / 100).toStringAsFixed(2)}%\n${p.start} 至 ${p.end} · 本期预计收益 ¥${Money.format(p.expected)}\n条款版本 ${p.termsVersion}，已由家长预留本期收益',
              style: const TextStyle(height: 1.7),
            ),
            Wrap(
              children: [
                button('提前取回', () async {
                  final days = Day.difference(p.start, s.date).clamp(0, p.days);
                  final profit = Money.interest(
                    p.principal,
                    math.min(10, p.rateBps),
                    days,
                  );
                  if (await confirm(
                    '提前取回这份计划？',
                    '持有 $days 天，以本期利率和 0.10% 中较低者重算，收益 ¥${Money.format(profit)}。本金 ¥${Money.format(p.principal)} 完整取回。',
                  )) {
                    await run('redeem', [p.id]);
                  }
                }),
                if (p.product == 'dividend')
                  button(
                    '下次：${p.distribution == 'cash' ? '现金分红' : '红利再投'} · 修改',
                    () async {
                      final mode = p.distribution == 'cash'
                          ? 'reinvest'
                          : 'cash';
                      if (await confirm(
                        '修改下一次分红',
                        '${mode == 'cash' ? '收益进入零钱，本金按同条件续期' : '本金与收益一起续期'}。每次续期检查预算；利率提出变更或预算不足时，本息回钱包。已结算记录不会修改。',
                      )) {
                        await run('distributionMode', [p.id, mode]);
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    button('产品小课堂', () => setState(() => tab = 'lesson')),
    note('这些是家庭教学计划，收益由家长按事先约定和预算承担，不是市场报价。年轮/小树到期自动回钱包；需要本息续存时，可重新确认一笔存入。'),
  ];
  Future<void> deposit(Product p) async {
    final data = await form(
      '存入${p.name}',
      [('存入金额（元）', '${p.minimum ~/ 100}')],
      distribution: p.id == 'dividend' ? s.distribution : null,
      note:
          '${p.days} 天，家庭约定年化 ${(s.rateBps / 100).toStringAsFixed(2)}%，条款版本 ${s.termsVersion}。存入只转移本金。',
    );
    if (data == null) return;
    try {
      final amount = Money.parse(data[0]);
      final mode = p.id == 'dividend' ? data[1] : s.distribution;
      Engine.mode(mode);
      final profit = Money.interest(amount, s.rateBps, p.days);
      if (await confirm(
        '确认这次家庭约定',
        '本金 ¥${Money.format(amount)} · ${p.days} 天\n本期预计收益 ¥${Money.format(profit)}，从家长预算预留。\n${p.id == 'dividend' ? (mode == 'cash' ? '收益进零钱，本金续期' : '收益与本金一起续期') : '到期本息回零钱钱包'}。',
      )) {
        await run('buy', [p.id, amount, mode]);
      }
    } catch (e) {
      if (mounted) tell(context, e);
    }
  }

  List<Widget> wallet() => [
    intro('tasks', '每一笔努力，都有自己的故事。待领取仍属于你的资产；实际交付后才从账户减少。'),
    paper(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '可以安排的零钱 ¥${Money.format(s.wallet)}',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
          Text(
            '持有 ¥${Money.format(s.holding)} · 待领取 ¥${Money.format(s.pendingCash)}\n账户资产 ¥${Money.format(s.assets)} · 已领取 ¥${Money.format(s.withdrawn)}\n计划待还 ¥${Money.format(s.debt)}（包含未来利息）',
            style: const TextStyle(height: 1.8),
          ),
          Wrap(
            children: [
              button('申请实际领取', withdraw),
              button('预支与还款', () => setState(() => tab = 'loans')),
            ],
          ),
        ],
      ),
    ),
    for (final r in s.requests.where((r) => r.status == 'pending'))
      paper(
        Text(
          '待家长实际交付：¥${Money.format(r.amount)} · ${r.purpose}${r.wishId == null ? '' : '\n心愿：${s.wishes.firstWhere((w) => w.id == r.wishId).name}'}',
        ),
      ),
    heading('每一笔都有来处'),
    if (s.ledger.isEmpty) note('这是零余额的新账户。完成第一份现实劳动后，记录会出现在这里。'),
    for (final l in s.ledger.reversed)
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(switch (l.kind) {
          'income' => Icons.task_alt,
          'yield' => Icons.eco_outlined,
          'repay' => Icons.calendar_month,
          _ => Icons.menu_book_outlined,
        }),
        title: Text(l.title),
        subtitle: Text('${l.date} · ${l.reference}'),
        trailing: Text('¥${Money.format(l.amount)}'),
      ),
  ];
  Future<void> withdraw() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BookForm(
        '申请实际领取 · ${s.name}',
        [('金额（元）', ''), ('用来做什么', s.goalName)],
        note: '先从可用零钱转到待领取，仍属于你的资产。家长确认实际交付后才记为已领取。为礼物自付时请选择对应心愿。',
        wishes: s.wishes.where((w) => w.available && w.kind == 'gift').toList(),
        onSubmit: (data) =>
            c.perform('request', [Money.parse(data[0]), data[1], data[2]]),
      ),
    );
  }

  List<Widget> wish() => [
    intro('wish', '我是星星。今天花掉也好，留给未来也好，先想一想为什么想要它。'),
    paper(
      Column(
        children: [
          SvgPicture.asset('assets/svg/telescope.svg', height: 90),
          Text(
            s.goalName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: s.goal > 0
                ? (math.max(0, s.conservative) / s.goal).clamp(0, 1)
                : 0,
            minHeight: 10,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 12),
          Text(
            '保守积累 ¥${Money.format(s.conservative)} / 目标 ¥${Money.format(s.goal)}',
          ),
          note('保守积累 = 账户资产 − 计划待还（包括未来利息）。预计收益尚未计入。'),
        ],
      ),
    ),
    Wrap(
      children: [
        button('编辑愿望', () async {
          final data = await form('我的新愿望', [
            ('愿望名称', s.goalName),
            ('目标金额（元）', Money.format(s.goal)),
            ('每周计划劳动留存（元）', Money.format(s.weeklyPlan)),
          ]);
          if (data != null) {
            try {
              await run('goal', [
                data[0],
                Money.parse(data[1]),
                Money.parse(data[2]),
              ]);
            } catch (e) {
              if (mounted) tell(context, e);
            }
          }
        }),
        button('申请领取零钱', withdraw),
        button('预支与主动还款', () => setState(() => tab = 'loans')),
      ],
    ),
  ];
  List<Widget> loans() => [
    intro('wish', '看清每月需要偿还多少，再决定是否接受。只有家长实际垫付购买，计划才生效。不会自动扣款或新增罚息。'),
    for (final l in s.loans.reversed) loanCard(l),
    button('写一份预支提议', () async {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => BookForm(
          '先写下我的提议 · ${s.name}',
          [
            ('购买用途', s.goalName),
            ('预支金额（元）', '60'),
            ('偿还期数（月）', '3'),
            ('首次还款日 YYYY-MM-DD', Day.month(s.date, 1)),
          ],
          note: '1–1000 元，1–12 个月。家长将提出最终利息与日期；垫付不进入零钱钱包，也不算自己攒够。',
          wishes: s.wishes
              .where((w) => w.available && w.kind == 'gift')
              .toList(),
          onSubmit: (data) => c.perform('loanRequest', [
            data[0],
            Money.parse(data[1]),
            months(data[2]),
            data[3],
            data[4],
          ]),
        ),
      );
    }),
    note('现金分红不会自动抵债；到账后可以自行选择主动还款。提前结清只支付未还本金与已到期利息，免除未来利息。'),
  ];
  Widget loanCard(Loan l, {bool parent = false}) {
    final status = const {
      'pending': '等待家长提出条件',
      'offered': '等待孩子阅读并接受',
      'approved': '孩子已接受，等待家长实际垫付',
      'active': '已生效，请按月主动还款',
      'paid': '已还清',
      'rejected': '家长暂不接受',
      'cancelled': '已撤回',
    }[l.status]!;
    final next = l.schedule.where((p) => p.balance > 0).firstOrNull;
    return paper(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l.item} · ¥${Money.format(l.amount)}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          if (l.wishId != null)
            Text(
              '心愿：${s.wishes.firstWhere((w) => w.id == l.wishId).name}${l.usedForGift ? ' · 礼物已到手' : ''}',
            ),
          Text(
            '$status\n家庭约定年化 ${(l.rateBps / 100).toStringAsFixed(2)}% · ${l.months} 个月 · 首次 ${l.first}',
            style: const TextStyle(height: 1.8),
          ),
          if (l.schedule.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 25,
                columns: const [
                  DataColumn(label: Text('还款日')),
                  DataColumn(label: Text('本金')),
                  DataColumn(label: Text('利息')),
                  DataColumn(label: Text('本期本息')),
                  DataColumn(label: Text('剩余')),
                ],
                rows: [
                  for (final p in l.schedule)
                    DataRow(
                      cells: [
                        DataCell(Text(p.due)),
                        DataCell(Text(Money.format(p.principal))),
                        DataCell(Text(Money.format(p.interest))),
                        DataCell(Text(Money.format(p.principal + p.interest))),
                        DataCell(Text(Money.format(p.balance))),
                      ],
                    ),
                ],
              ),
            ),
          Wrap(
            children: [
              if (!parent && l.status == 'offered')
                button('阅读后接受这些条件', () async {
                  if (await confirm(
                    '确认接受家长最终条件？',
                    '${l.item} · 本金 ¥${Money.format(l.amount)}\n家庭约定年化 ${(l.rateBps / 100).toStringAsFixed(2)}%\n共 ${l.months} 期，本息合计 ¥${Money.format(l.balance)}。\n请先看清上方每期月供；只有实际垫付后才记欠款。',
                  )) {
                    await run('acceptLoan', [l.id]);
                  }
                }),
              if (!parent &&
                  ['pending', 'offered', 'approved'].contains(l.status))
                button('撤回提议', () => run('cancelLoan', [l.id])),
              if (!parent && l.status == 'active' && next != null)
                button('主动还一期', () async {
                  final index = l.schedule.indexOf(next);
                  if (await confirm(
                    '主动偿还这期？',
                    '还款日 ${next.due}\n本期需 ¥${Money.format(next.balance)}，从可用零钱支付。未到还款日不能扣款，零钱不足整笔拒绝。',
                  )) {
                    await run('repayment', [
                      l.id,
                      'installment',
                    ], op: 'repay-${l.id}-$index');
                  }
                }),
              if (!parent && l.status == 'active')
                button('提前结清', () async {
                  final amount = l.schedule.fold<int>(
                    0,
                    (v, p) =>
                        v +
                        p.principal -
                        p.paidPrincipal +
                        (p.due.compareTo(s.date) <= 0
                            ? p.interest - p.paidInterest - p.waivedInterest
                            : 0),
                  );
                  if (await confirm(
                    '提前结清？',
                    '需要 ¥${Money.format(amount)}\n全部未还本金与已到期未付利息一起支付，未到期利息免除。',
                  )) {
                    await run('repayment', [
                      l.id,
                      'settle',
                    ], op: 'settle-${l.id}');
                  }
                }),
              if (parent && ['pending', 'offered'].contains(l.status))
                button('提出最终条件', () => offer(l)),
              if (parent && ['pending', 'offered'].contains(l.status))
                button('暂不接受', () => run('rejectLoan', [l.id])),
              if (parent && l.status == 'approved')
                button('确认已实际垫付购买', () async {
                  if (await confirm(
                    '家长已实际垫付？',
                    '请确认已为${s.name}垫付 ¥${Money.format(l.amount)} 购买${l.item}。此后月供计划生效；借款不会进入孩子钱包或劳动收入。',
                  )) {
                    await run('fundLoan', [l.id]);
                  }
                }),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> offer(Loan l) async {
    final data = await form(
      '家长提出最终条件',
      [
        ('偿还期数（月）', '${l.months}'),
        ('首次还款日 YYYY-MM-DD', l.first),
        ('家庭约定年利率（%，可为 0）', (l.rateBps / 100).toStringAsFixed(2)),
      ],
      note: '1–12 个月，0%–12% 年利率。采用等额本金、按月单利；分位余数归最后一期。孩子接受前可以调整，生效后固定。',
    );
    if (data != null) {
      try {
        await run('offerLoan', [
          l.id,
          months(data[0]),
          data[1],
          Money.parse(data[2]),
        ]);
      } catch (e) {
        if (mounted) tell(context, e);
      }
    }
  }

  List<Widget> parent() {
    if (c.parent == null) {
      return [
        intro('tasks', '这一步交给家长。离开 APP 或退出家长空间后，会重新锁定。'),
        field(pin, '家长口令', key: 'parent-pin', secret: true),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        button('解锁家长空间', () async {
          try {
            await c.unlock(pin.text);
            pin.clear();
            setState(() => error = null);
          } catch (e) {
            setState(() => error = userMessage(e));
          }
        }, key: 'unlock-parent'),
      ];
    }
    return [
      note(
        '当前管理：${s.name} · ${c.demo ? '独立示例家庭' : '真实家庭'}。以下检查、兑现、预算和垫付仅作用于这个孩子。',
      ),
      button('选择管理的孩子', () async {
        final rows = await c.service.db.rows(
          'SELECT id,name FROM children WHERE family_id=? ORDER BY rowid',
          [c.family],
        );
        if (!mounted) return;
        final id = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('明确选择管理的孩子'),
            children: [
              for (final r in rows)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, r['id']),
                  child: Text(r['name']),
                ),
            ],
          ),
        );
        if (id != null && id != c.child) {
          try {
            await c.switchChild(id);
          } catch (e) {
            if (mounted) tell(context, e);
          }
        }
      }),
      heading('现实劳动 · 检查与兑现分开'),
      for (final t in s.tasks.where(
        (t) => ['submitted', 'confirmed'].contains(t.status),
      ))
        paper(
          Row(
            children: [
              Expanded(
                child: Text(
                  '${t.name}\n${t.detail}\n¥${Money.format(t.amount)} · ${Engine.taskLabel(t.status)}',
                ),
              ),
              if (t.status == 'submitted')
                button(
                  '检查完成',
                  () => run('approve', [t.id]),
                  key: 'approve-${t.id}',
                ),
              if (t.status == 'confirmed')
                button('确认已兑现', () async {
                  if (await confirm(
                    '报酬已经实际兑现？',
                    '确认已向${s.name}交付或预留代管 ¥${Money.format(t.amount)} 劳动报酬。这一步才增加零钱和劳动收入。',
                  )) {
                    await run('pay', [t.id]);
                  }
                }, key: 'pay-${t.id}'),
            ],
          ),
        ),
      button('创建现实劳动委托', () async {
        final data = await form('事前约定一份委托', [
          ('名称（1–30 字）', ''),
          ('报酬（1–200 元）', ''),
          ('完成标准', ''),
        ]);
        if (data != null) {
          try {
            require(data[2].trim().isNotEmpty, '请填写明确完成标准');
            await run('addTask', [data[0], Money.parse(data[1]), data[2]]);
          } catch (e) {
            if (mounted) tell(context, e);
          }
        }
      }),
      heading('收益约定与预算'),
      paper(
        Text(
          '阶段总预算 ¥${Money.format(s.budget)}\n已结算 ¥${Money.format(s.bonusEarned)} · 有效承诺预留 ¥${Money.format(s.reserved)}\n可用 ¥${Money.format(s.freeBudget)} · 新计划年化 ${(s.rateBps / 100).toStringAsFixed(2)}%',
          style: const TextStyle(height: 1.8),
        ),
      ),
      button('调整后续约定', () async {
        final data = await form('家长约定', [
          ('阶段收益总预算（元）', Money.format(s.budget)),
          ('新计划家庭约定年化（%）', (s.rateBps / 100).toStringAsFixed(2)),
          ('孩子称呼', s.name),
        ], note: '预算不能低于已结算与预留承诺之和；预算不会自动按月恢复。改利率只影响新计划，分红下一期需孩子重新安排。');
        if (data != null) {
          try {
            await run('settings', [
              Money.parse(data[0]),
              Money.parse(data[1]),
              data[2],
            ]);
          } catch (e) {
            if (mounted) tell(context, e);
          }
        }
      }),
      heading('实际领取交付'),
      for (final r in s.requests.where((r) => r.status == 'pending'))
        paper(
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r.purpose}\n待交付 ¥${Money.format(r.amount)}${r.wishId == null ? '' : '\n心愿：${s.wishes.firstWhere((w) => w.id == r.wishId).name}'}',
                ),
              ),
              button('确认实际交付', () async {
                if (await confirm(
                  '确认钱已实际交付给孩子？',
                  '${s.name} · ¥${Money.format(r.amount)}\n交付后从账户资产减少，不能重复交付。',
                )) {
                  await run('payRequest', [r.id]);
                }
              }),
            ],
          ),
        ),
      heading('预支与家长垫付'),
      for (final l in s.loans.reversed) loanCard(l, parent: true),
      if (c.demo) ...[
        heading('独立示例日期'),
        note('仅用于体验结算，不会改变真实家庭日期。当前 ${s.date}'),
        Wrap(
          children: [
            for (final days in [30, 90, 365])
              button('示例前进 $days 天', () async {
                try {
                  await c.advanceDemo(days);
                } catch (e) {
                  if (mounted) tell(context, e);
                }
              }),
          ],
        ),
      ],
    ];
  }

  List<Widget> growth() {
    final base = math.max(0, s.conservative),
        annualAdd = contribute ? s.weeklyPlan * 52 : 0;
    var reinvest = base, simplePrincipal = base, withdrawnYield = 0;
    final points = <(int, int)>[(base, base)];
    for (var i = 0; i < years; i++) {
      reinvest += Money.interest(reinvest, s.rateBps, 365) + annualAdd;
      withdrawnYield += Money.interest(simplePrincipal, s.rateBps, 365);
      simplePrincipal += annualAdd;
      points.add((reinvest, simplePrincipal + withdrawnYield));
    }
    return [
      intro('growth', '新的劳动增加本金，收益留下也会参与下一次积累。我们把真实记录和未来假设分开看。'),
      paper(
        Text(
          '已兑现劳动 ¥${Money.format(s.laborTotal)} · 已结算收益 ¥${Money.format(s.bonusEarned)}\n已实际领取 ¥${Money.format(s.withdrawn)} · 已偿还 ¥${Money.format(s.repaidTotal)}',
          style: const TextStyle(height: 1.8),
        ),
      ),
      heading('如果把收益也留下？ · 预计'),
      Text('$years 年后 · 当前家庭约定年化 ${(s.rateBps / 100).toStringAsFixed(2)}%'),
      Slider(
        value: years.toDouble(),
        min: 1,
        max: 20,
        divisions: 19,
        onChanged: (v) => setState(() => years = v.round()),
      ),
      SizedBox(height: 180, child: CustomPaint(painter: GrowthChart(points))),
      paper(
        Text(
          '预计收益再投入：¥${Money.format(reinvest)}\n预计取出收益（包括已取出部分）：¥${Money.format(simplePrincipal + withdrawnYield)}\n预计差额：¥${Money.format(reinvest - simplePrincipal - withdrawnYield)}',
          style: const TextStyle(height: 1.8),
        ),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('加入每周 ¥${Money.format(s.weeklyPlan)} 计划劳动留存'),
        value: contribute,
        onChanged: (v) => setState(() => contribute = v!),
      ),
      note(
        '仅为假设投影：以扣除计划待还后的积累为起点，按当前约定年化每年结算；计划劳动按每年末投入 52 周金额。两条曲线都计入收益，取出方案的收益不继续参与下一期。未来收入、利率和预算可能改变；投影不计入当前资产，也不是家长已承诺兑付。',
      ),
      heading('已经发生的收益故事'),
      for (final l
          in s.ledger.where((l) => l.kind == 'yield').toList().reversed)
        ListTile(
          title: Text(l.title),
          subtitle: Text(l.date),
          trailing: Text('¥${Money.format(l.amount)}'),
        ),
    ];
  }

  List<Widget> lesson() => [
    heading('分红时，钱没有凭空变多'),
    SvgPicture.asset('assets/svg/tree-annual.svg', height: 90),
    paper(
      const Text(
        '分红前：100 份 × 1.03 元 = 103 元\n每份分红 0.03 元后，除息净值为 1.00 元。\n\n现金分红：100 份 × 1.00 元 + 3 元现金 = 103 元\n红利再投：103 份 × 1.00 元 = 103 元\n\n两种方式在分红时总额相同，区别是收益的下一站。',
        style: TextStyle(height: 1.9),
      ),
    ),
    heading('净值也可能下降'),
    paper(
      const Text(
        '100 份 × 0.95 元 = 95 元。价格变化可能带来亏损。\n课堂只作教学演示，不使用你现实劳动赚来的钱进行基金交易。',
        style: TextStyle(height: 1.8),
      ),
    ),
    button('回储蓄小屋', () => setState(() => tab = 'savings')),
  ];
}

class BookForm extends StatefulWidget {
  const BookForm(
    this.title,
    this.fields, {
    this.note,
    this.distribution,
    this.wishes,
    this.onSubmit,
    super.key,
  });
  final String title;
  final List<(String, String)> fields;
  final String? note;
  final String? distribution;
  final List<Wish>? wishes;
  final Future<void> Function(List<String>)? onSubmit;
  @override
  State<BookForm> createState() => _BookFormState();
}

class _BookFormState extends State<BookForm> {
  late String? distribution = widget.distribution;
  String wish = '';
  String? error;
  bool saving = false;
  final form = GlobalKey<FormState>();
  late final controllers = [
    for (final f in widget.fields) TextEditingController(text: f.$2),
  ];
  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.note != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(widget.note!),
                  ),
                for (var i = 0; i < controllers.length; i++)
                  if (widget.onSubmit == null)
                    field(
                      controllers[i],
                      widget.fields[i].$1,
                      key: 'book-field-$i',
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TextFormField(
                        key: Key('book-field-$i'),
                        controller: controllers[i],
                        decoration: InputDecoration(
                          labelText: widget.fields[i].$1,
                        ),
                        keyboardType: widget.fields[i].$1.contains('（元）')
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                              )
                            : TextInputType.text,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? '请填写${widget.fields[i].$1}'
                            : null,
                      ),
                    ),
                if (widget.wishes != null) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('关联心愿（明确选择）'),
                  ),
                  RadioGroup<String>(
                    groupValue: wish,
                    onChanged: (v) {
                      if (!saving) setState(() => wish = v!);
                    },
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          key: const Key('payment-wish-none'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('普通用途，暂不关联心愿'),
                          value: '',
                          enabled: !saving,
                        ),
                        for (final w in widget.wishes!)
                          RadioListTile<String>(
                            key: Key('payment-wish-${w.id}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(w.name),
                            subtitle: Text('礼物目标 ¥${Money.format(w.target)}'),
                            value: w.id,
                            enabled: !saving,
                          ),
                      ],
                    ),
                  ),
                ],
                if (distribution != null) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'cash', label: Text('现金分红')),
                      ButtonSegment(value: 'reinvest', label: Text('红利再投')),
                    ],
                    selected: {distribution!},
                    onSelectionChanged: (v) =>
                        setState(() => distribution = v.single),
                  ),
                ],
                if (error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      key: const Key('book-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('返回'),
        ),
        FilledButton(
          key: const Key('book-continue'),
          onPressed: saving
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  final data = [
                    ...controllers.map((c) => c.text),
                    if (distribution != null) distribution!,
                    if (widget.wishes != null) wish,
                  ];
                  if (widget.onSubmit == null) {
                    Navigator.pop(context, data);
                    return;
                  }
                  setState(() {
                    saving = true;
                    error = null;
                  });
                  try {
                    await widget.onSubmit!(data);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        error = userMessage(e);
                        saving = false;
                      });
                    }
                  }
                },
          child: Text(
            saving
                ? '正在保存…'
                : widget.onSubmit == null
                ? '继续'
                : '保存申请',
          ),
        ),
      ],
    ),
  );
}

class GrowthChart extends CustomPainter {
  GrowthChart(this.points);
  final List<(int, int)> points;
  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = math
        .max(1, points.map((p) => math.max(p.$1, p.$2)).reduce(math.max))
        .toDouble();
    for (var series = 0; series < 2; series++) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final p = points[i];
        final x = 12 + i * (size.width - 24) / (points.length - 1),
            y =
                size.height -
                18 -
                (series == 0 ? p.$1 : p.$2) * (size.height - 36) / maxValue;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = series == 0
              ? const Color(0xFF789564)
              : const Color(0xFFBBAD86)
          ..strokeWidth = series == 0 ? 4 : 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GrowthChart oldDelegate) =>
      oldDelegate.points != points;
}
