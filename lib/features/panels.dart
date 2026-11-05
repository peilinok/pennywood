import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app/controller.dart';
import '../app/detail_page.dart';
import '../app/paper_theme.dart';
import '../app/screens.dart' show field, tell, userMessage;
import '../domain/model.dart';
import '../domain/money.dart';
import '../domain/market.dart';

int months(String value) {
  final n = int.tryParse(value);
  require(n != null && n >= 1 && n <= 12, '期数请填写 1–12 之间的整数');
  return n!;
}

Future<void> proposeAdvance(
  BuildContext context,
  TownController c,
  Wish wish,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => BookForm(
      '和家长商量预支 · ${c.account.name}',
      [
        ('购买用途', wish.name),
        ('预支金额（元）', '60'),
        ('偿还期数（月）', '3'),
        ('首次还款日 YYYY-MM-DD', Day.month(c.account.date, 1)),
      ],
      asPage: true,
      initialWish: wish.id,
      wishes: [wish],
      note: '先提出想法，家长会给出最终条件。你接受并由家长实际垫付后才生效；预支不进入零钱，也不算攒够。',
      onSubmit: (data) => c.perform('loanRequest', [
        data[0],
        Money.parse(data[1]),
        months(data[2]),
        data[3],
        data[4],
      ]),
    ),
  ),
);

Future<void> requestWithdrawal(BuildContext context, TownController c) async {
  final s = c.account;
  final form = BookForm(
    '申请实际领取 · ${s.name}',
    asPage: true,
    [('金额（元）', ''), ('用来做什么', s.goalName)],
    note: '先从可用零钱转到待领取，仍属于你的资产。家长确认实际交付后才记为已领取。为礼物自付时请选择对应心愿。',
    wishes: s.wishes.where((w) => w.available && w.kind == 'gift').toList(),
    onSubmit: (data) =>
        c.perform('request', [Money.parse(data[0]), data[1], data[2]]),
  );
  await Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => form));
}

Future<void> offerAdvance(BuildContext context, TownController c, Loan l) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BookForm(
          '家长提出最终条件 · ${l.item}',
          [
            ('偿还期数（月）', '${l.months}'),
            ('首次还款日 YYYY-MM-DD', l.first),
            ('家庭约定年利率（%，可为 0）', (l.rateBps / 100).toStringAsFixed(2)),
          ],
          asPage: true,
          note: '1–12 个月，0%–12% 年利率。等额本金、按月单利，分位余数归最后一期。孩子接受后等待实际垫付，生效后固定。',
          submitLabel: '保存最终条件',
          onSubmit: (v) => c.perform('offerLoan', [
            l.id,
            months(v[0]),
            v[1],
            Money.parse(v[2]),
          ]),
        ),
      ),
    );

class FinancePage extends StatefulWidget {
  const FinancePage(this.controller, this.section, {this.recordId, super.key});
  final TownController controller;
  final String section;
  final String? recordId;
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  TownController get c => widget.controller;
  ChildAccount get s => c.account;
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
  Widget button(
    String label,
    VoidCallback onTap, {
    String? key,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(right: 8, bottom: 6),
    child: FilledButton.tonal(
      key: key == null ? null : Key(key),
      onPressed: c.busy || !enabled ? null : onTap,
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
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => DetailPage(
      title: Text(
        '${switch (widget.section) {
          'savings' => '安排零钱',
          'holding' => '持有详情',
          _ => '预支记录',
        }} · ${s.name}',
      ),
      content: SingleChildScrollView(
        key: PageStorageKey('${c.child}-${widget.section}-${widget.recordId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: switch (widget.section) {
            'savings' => savings(),
            'holding' => [
              for (final p in s.positions.where((p) => p.id == widget.recordId))
                positionCard(p),
            ],
            'parent-loans' => [
              for (final l in s.loans.where((l) => l.id == widget.recordId))
                loanCard(l, parent: true),
            ],
            _ => loans(),
          },
        ),
      ),
    ),
  );
  List<Widget> savings() => [
    paper(
      Text(
        '可用零钱 ¥${Money.format(s.wallet)} · 可用收益预算 ¥${Money.format(s.freeBudget)}',
      ),
    ),
    for (final market in [false, true]) ...[
      heading(market ? '会涨会跌' : '固定约定'),
      if (market) note('使用现实零钱，亏损会减少本金；需要家长事先开启。'),
      for (final p in Product.all.values.where((p) => p.market == market))
        paper(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text('${p.days} 天 · ${p.minimum ~/ 100} 元起'),
              Text(
                p.market
                    ? '非保本 · 最高亏损 ${p.lossCapBps ~/ 100}% · 最高收益 ${p.gainCapBps ~/ 100}%'
                    : '约定年化 ${(s.rateFor(p.id) / 100).toStringAsFixed(2)}%',
              ),
              if (p.market && !s.marketEnabled) const Text('请先和家长一起开启'),
              button(
                p.market && !s.marketEnabled ? '等待家长开启' : '了解并存入',
                () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => DepositForm(c, p)),
                ),
                key: 'deposit-${p.id}',
                enabled: !p.market || s.marketEnabled,
              ),
            ],
          ),
        ),
    ],
    note('家庭教学计划的收益由家长预算承担。已有持有沿用存入时的承诺。'),
  ];
  Widget positionCard(Position p) => paper(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.status != 'active') Text('已结算 · ${p.end}'),
        Text(
          Product.all[p.product]!.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        Text(
          Product.all[p.product]!.market
              ? '投入本金 ¥${Money.format(p.principal)} · 参考价值 ¥${Money.format(p.principal + TeachingMarket.profit(p, s.date))}\n${p.start} 至 ${p.end} · 本期最多收益 ¥${Money.format(p.expected)} 已预留\n参考涨跌未入账；到期或取回时结算，可能亏损本金。'
              : '本金 ¥${Money.format(p.principal)} · 本期年化 ${(p.rateBps / 100).toStringAsFixed(2)}%\n${p.start} 至 ${p.end} · 本期预计收益 ¥${Money.format(p.expected)}\n条款版本 ${p.termsVersion}，已由家长预留本期收益',
          style: const TextStyle(height: 1.7),
        ),
        if (p.status == 'active')
          Wrap(
            children: [
              button('提前取回', () async {
                final days = Day.difference(p.start, s.date).clamp(0, p.days);
                final market = Product.all[p.product]!.market;
                final profit = market
                    ? TeachingMarket.profit(p, s.date)
                    : Money.interest(
                        p.principal,
                        math.min(10, p.rateBps),
                        days,
                      );
                if (await confirm(
                  '提前取回这份计划？',
                  market
                      ? '投入 ¥${Money.format(p.principal)}，当前涨跌 ¥${Money.format(profit)}。本次实际取回 ¥${Money.format(p.principal + profit)}，亏损会记入账本。'
                      : '持有 $days 天，以本期利率和 0.10% 中较低者重算，收益 ¥${Money.format(profit)}。本金 ¥${Money.format(p.principal)} 完整取回。',
                )) {
                  await run('redeem', [p.id]);
                }
              }),
              if (p.product == 'dividend')
                button(
                  '下次：${p.distribution == 'cash' ? '现金分红' : '红利再投'} · 修改',
                  () async {
                    final mode = p.distribution == 'cash' ? 'reinvest' : 'cash';
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
  );

  List<Widget> loans() => [
    note('看清每月需还金额再接受；实际垫付后生效，不会自动扣款或新增罚息。'),
    for (final l in s.loans.reversed.where(
      (l) => widget.recordId == null || l.id == widget.recordId,
    ))
      loanCard(l),
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

  Future<void> offer(Loan l) => offerAdvance(context, c, l);
}

class DepositForm extends StatefulWidget {
  const DepositForm(this.controller, this.product, {super.key});
  final TownController controller;
  final Product product;
  @override
  State<DepositForm> createState() => _DepositFormState();
}

class _DepositFormState extends State<DepositForm> {
  late final amount = TextEditingController(
    text: '${widget.product.minimum ~/ 100}',
  );
  late String distribution = widget.controller.account.distribution;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, p = widget.product, s = c.account;
    int? principal;
    try {
      principal = Money.parse(amount.text);
    } catch (_) {
      /* Incomplete amount input has no preview. */
    }
    final profit = principal == null
        ? null
        : p.market
        ? TeachingMarket.reserve(p.id, principal)
        : Money.interest(principal, s.rateFor(p.id), p.days);
    return PopScope(
      canPop: !saving,
      child: DetailPage(
        title: Text('存入${p.name}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('可用零钱 ¥${Money.format(s.wallet)} · ${p.minimum ~/ 100} 元起'),
              const SizedBox(height: 16),
              TextField(
                key: const Key('deposit-amount'),
                controller: amount,
                enabled: !saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '存入金额（元）'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              Text(
                '${s.name}的本次约定 · ${p.days} 天',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('${s.date} 至 ${Day.add(s.date, p.days)}'),
              if (p.market) ...[
                const Text('非保本：取回时，收益和亏损都会实际记入账本。上涨没有保证。'),
                Text(
                  '最多亏损 ${p.lossCapBps ~/ 100}% · 最多收益 ${p.gainCapBps ~/ 100}%',
                ),
                if (principal != null)
                  Text(
                    '本次本金 ¥${Money.format(principal)} · 最多亏损 ¥${Money.format(Money.rounded(principal, p.lossCapBps, 1, 10000))}',
                  ),
                if (profit != null)
                  Text('本次最多收益 ¥${Money.format(profit)}，从家长预算预留。'),
                const Text(
                  '到期或提前取回时，本金与实际涨跌回零钱；提前取回按当天教学行情结算。家长已允许新波动投资。这不是基金或纳指真实报价。',
                ),
              ] else ...[
                Text(
                  '约定年化 ${(s.rateFor(p.id) / 100).toStringAsFixed(2)}% · 条款版本 ${s.versionFor(p.id)}',
                ),
                if (profit != null)
                  Text('本期预计收益 ¥${Money.format(profit)}，从家长预算预留。'),
                const Text('提前取回保留本金，收益按本期利率与 0.10% 中较低者重算。'),
                if (p.id == 'dividend') ...[
                  RadioGroup<String>(
                    groupValue: distribution,
                    onChanged: (v) {
                      if (!saving) setState(() => distribution = v!);
                    },
                    child: Column(
                      children: [
                        RadioListTile(
                          value: 'cash',
                          title: const Text('现金分红：收益进零钱，本金续期'),
                          enabled: !saving,
                        ),
                        RadioListTile(
                          value: 'reinvest',
                          title: const Text('红利再投：本金与收益一起续期'),
                          enabled: !saving,
                        ),
                      ],
                    ),
                  ),
                  const Text('续期检查原承诺、利率变更与预算；不满足时本息回零钱。'),
                ] else
                  const Text('到期本息自动回零钱；继续存入时重新确认。'),
              ],
              const SizedBox(height: 12),
              Text('当前可用收益预算 ¥${Money.format(s.freeBudget)}。存入只转移本金，不增加劳动收入。'),
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    key: const Key('deposit-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            key: const Key('confirm-deposit'),
            onPressed: saving
                ? null
                : () async {
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    try {
                      await c.perform('buy', [
                        p.id,
                        Money.parse(amount.text),
                        distribution,
                      ]);
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
            child: Text(saving ? '正在保存…' : '确认存入'),
          ),
        ],
      ),
    );
  }
}

class BookForm extends StatefulWidget {
  const BookForm(
    this.title,
    this.fields, {
    this.note,
    this.distribution,
    this.wishes,
    this.onSubmit,
    this.submitLabel,
    this.asPage = false,
    this.initialWish = '',
    super.key,
  });
  final String title;
  final List<(String, String)> fields;
  final String? note;
  final String? submitLabel;
  final bool asPage;
  final String initialWish;
  final String? distribution;
  final List<Wish>? wishes;
  final Future<void> Function(List<String>)? onSubmit;
  @override
  State<BookForm> createState() => _BookFormState();
}

class _BookFormState extends State<BookForm> {
  late String? distribution = widget.distribution;
  late String wish = widget.initialWish;
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
    child: FormSurface(
      asPage: widget.asPage,
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
        if (!widget.asPage)
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
                : widget.submitLabel ?? '保存申请',
          ),
        ),
      ],
    ),
  );
}
