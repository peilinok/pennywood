import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app/controller.dart';
import '../app/named_page_scroll.dart';
import '../app/paper_theme.dart';
import '../app/screens.dart' show TownHome, tell, userMessage;
import '../domain/engine.dart';
import '../domain/model.dart';
import '../domain/money.dart';
import 'panels.dart';
import 'family_settings.dart';

class WishHome extends StatefulWidget {
  const WishHome(this.controller, {super.key});
  final TownController controller;
  @override
  State<WishHome> createState() => _WishHomeState();
}

class _WishHomeState extends State<WishHome> with WidgetsBindingObserver {
  TownController get c => widget.controller;
  ChildAccount get s => c.account;
  PaperColors get p => PaperColors.of(context);
  bool parentMode = false, completedOnly = false;
  int page = 0;
  final scroll = ScrollController();
  final pin = TextEditingController();
  String? pinError;
  bool unlocking = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.lock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scroll.dispose();
    pin.dispose();
    c.lock();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      c.lock();
      pin.clear();
    } else if (state == AppLifecycleState.resumed) {
      c.resume().catchError((Object e) {
        if (mounted) tell(context, e);
      });
    }
  }

  Future<bool> run(String action, List<Object?> args) async {
    try {
      await c.perform(action, args);
      return true;
    } catch (e) {
      if (mounted) tell(context, e);
      return false;
    }
  }

  void navigate(int index) {
    setState(() => page = index);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void changeRole() {
    c.lock();
    pin.clear();
    setState(() {
      parentMode = !parentMode;
      page = 0;
      pinError = null;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> profiles() async {
    final rows = await c.service.db.rows(
      'SELECT id,name FROM children WHERE family_id=? ORDER BY rowid',
      [c.family],
    );
    if (!mounted) return;
    final id = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(parentMode ? '选择管理的孩子' : '今天是谁的心愿手账？'),
        children: [
          for (final r in rows)
            Semantics(
              button: true,
              selected: r['id'] == c.child,
              child: SimpleDialogOption(
                key: Key('switch-${r['id']}'),
                padding: const EdgeInsets.all(20),
                onPressed: () => Navigator.pop(context, r['id']),
                child: Text('${r['name']} ${r['id'] == c.child ? '· 当前' : ''}'),
              ),
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
      pin.clear();
      if (mounted) setState(() => pinError = null);
    }
  }

  Future<void> panel(String name) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TownPanel(c, name),
    );
    if (mounted) setState(() {});
  }

  Future<void> newWish({Wish? wish}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WishEditor(c, wish: wish),
    );
  }

  Future<void> configure(String id) async {
    final q = s.quickTasks.where((q) => q.id == id).firstOrNull;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ActionForm(
        title: '约定${QuickTask.names[id]} · ${s.name}',
        labels: const ['完成标准', '每次报酬（元）'],
        initial: [
          q?.detail ?? QuickTask.standards[id]!,
          q != null && q.amount > 0 ? Money.format(q.amount) : '',
        ],
        note: '请先和孩子说好。每天最多一份；修改只影响新的任务，已提交的标准与金额保留。',
        submitLabel: '保存约定',
        onSubmit: (v) =>
            c.perform('configureQuick', [id, Money.parse(v[1]), v[0]]),
      ),
    );
  }

  Future<void> taskDetail(LaborTask t, {bool parent = false}) async {
    if (parent) {
      await showDialog<void>(
        context: context,
        builder: (_) => TaskReview(c, t.id),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.detail),
              const SizedBox(height: 16),
              Text(
                '约定 ¥${Money.format(t.amount)} · ${Engine.taskLabel(t.status)}',
              ),
              if (t.businessDay != null) Text('本次日期：${t.businessDay}'),
              if (t.feedback.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('家长的小提醒：${t.feedback}'),
                ),
              const SizedBox(height: 12),
              const Text('家长检查并实际兑现后，零钱才增加。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
          if (t.status == 'submitted')
            OutlinedButton(
              key: Key('withdraw-${t.id}'),
              onPressed: () async {
                if (await run('withdrawTask', [t.id]) && context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('撤回这次提交'),
            ),
          if (['accepted', 'needsWork'].contains(t.status))
            FilledButton(
              key: Key('submit-${t.id}'),
              onPressed: () async {
                if (await run(t.templateId == null ? 'submit' : 'quickSubmit', [
                      t.templateId ?? t.id,
                    ]) &&
                    context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('我做好了，提交检查'),
            ),
        ],
      ),
    );
  }

  Future<void> quickTap(String id) async {
    // Use the business clock even during long foreground sessions; a new day needs no restart.
    if (s.date != c.service.clock.today) {
      try {
        await c.resume();
      } catch (e) {
        if (mounted) tell(context, e);
        return;
      }
      if (!mounted) return;
    }
    final q = s.quickTasks.where((q) => q.id == id).firstOrNull;
    final t = s.quickInstance(id);
    if ((q == null || !q.enabled) && t == null) {
      tell(
        context,
        q != null && q.amount > 0
            ? '这项任务暂时休息，已有任务和报酬保留。'
            : '先请家长在「家庭约定」里约好标准和报酬。',
      );
      return;
    }
    if (t == null || ['available', 'accepted'].contains(t.status)) {
      if (await run('quickSubmit', [id]) && mounted) {
        tell(context, '已保存在本机，等待家长检查。误触可点任务撤回。');
      }
    } else {
      await taskDetail(t);
    }
  }

  Widget card(Widget child, {EdgeInsets? padding}) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: p.line),
    ),
    child: child,
  );
  Widget small(String text) =>
      Text(text, style: TextStyle(fontSize: 13, height: 1.6, color: p.muted));
  Widget heading(String title, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (action != null) action,
      ],
    ),
  );
  Widget tag(String text, {bool done = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: done ? p.greenSoft : p.soft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: done ? p.green : p.muted),
    ),
  );

  List<(String, IconData)> get destinations => parentMode
      ? [
          ('待确认', Icons.fact_check_outlined),
          ('孩子与心愿', Icons.favorite_border),
          ('家庭约定', Icons.tune),
        ]
      : [
          ('我的心愿', Icons.card_giftcard),
          ('我的任务', Icons.assignment_outlined),
          ('我的零钱', Icons.account_balance_wallet_outlined),
        ];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, size) {
            final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final wide =
                size.maxWidth >= 1000 &&
                size.maxHeight >= 500 &&
                textScale <= 1.5;
            return Column(
              children: [
                if (c.busy) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wide) sidebar(),
                      Expanded(
                        child: Column(
                          children: [
                            header(wide),
                            Expanded(
                              child: NamedPageScroll(
                                label: parentMode && c.parent == null
                                    ? '家长空间解锁'
                                    : '${destinations[page].$1}内容',
                                controller: scroll,
                                padding: EdgeInsets.fromLTRB(
                                  wide ? 28 : 20,
                                  4,
                                  wide ? 28 : 20,
                                  28,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 1180,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: parentMode && c.parent == null
                                          ? locked()
                                          : parentMode
                                          ? parentPage()
                                          : childPage(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!wide)
                  NavigationBar(
                    height: 64 + (textScale - 1).clamp(0, 2) * 32,
                    selectedIndex: page,
                    onDestinationSelected: navigate,
                    destinations: [
                      for (final d in destinations)
                        NavigationDestination(icon: Icon(d.$2), label: d.$1),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget header(bool wide) => Padding(
    padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 12, wide ? 20 : 12, 16),
    child: Row(
      children: [
        if (!wide)
          IconButton(
            key: const Key('profiles'),
            tooltip: '切换孩子',
            onPressed: c.busy ? null : profiles,
            icon: const Icon(Icons.face_outlined),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              small(
                '${s.name}的${parentMode ? '家长空间' : '心愿手账'}${c.demo ? ' · 独立示例' : ''}',
              ),
              Text(
                parentMode ? '陪每一份小小努力长大。' : '今天，也离心愿近一点。',
                style: TextStyle(
                  fontSize: wide ? 25 : 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (wide) tag('本地存档 · ${c.busy ? '保存中' : '已保存'}', done: !c.busy),
        IconButton(
          key: const Key('theme-toggle'),
          tooltip: p.dark ? '使用浅色' : '使用深色',
          onPressed: () =>
              paperThemeMode.value = p.dark ? ThemeMode.light : ThemeMode.dark,
          icon: Icon(
            p.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
        ),
        if (!wide)
          IconButton(
            key: const Key('parent-entry'),
            tooltip: parentMode ? '回到孩子端' : '家长空间',
            onPressed: changeRole,
            icon: Icon(parentMode ? Icons.logout : Icons.lock_outline),
          ),
        PopupMenuButton<String>(
          tooltip: '更多',
          onSelected: (v) async {
            if (v == 'home') {
              c.lock();
              Navigator.pop(context);
            }
            if (v == 'town') {
              c.lock();
              await Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => TownHome(c)),
              );
              if (mounted) setState(() {});
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'town', child: Text('去小镇散步')),
            PopupMenuItem(value: 'home', child: Text('返回家庭入口')),
          ],
        ),
      ],
    ),
  );

  Widget sidebar() => Container(
    width: 164,
    decoration: BoxDecoration(
      color: p.soft,
      border: Border(right: BorderSide(color: p.line)),
    ),
    padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: p.brand,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.eco_outlined, color: p.onBrand, size: 23),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('栗子小镇', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    'PENNYWOOD',
                    style: TextStyle(fontSize: 10, letterSpacing: 1),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          key: const Key('profiles'),
          onPressed: c.busy ? null : profiles,
          child: Semantics(
            label: '切换孩子，当前${s.name}',
            excludeSemantics: true,
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/svg/mascot.svg',
                  width: 26,
                  height: 34,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(s.name)),
                const Icon(Icons.expand_more, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < destinations.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              button: true,
              selected: i == page,
              child: Material(
                color: i == page ? p.greenSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => navigate(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          destinations[i].$2,
                          color: i == page ? p.green : p.muted,
                          size: 21,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            destinations[i].$1,
                            style: TextStyle(
                              fontWeight: i == page
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: i == page ? p.green : p.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        SvgPicture.asset('assets/svg/mascot.svg', width: 70, height: 90),
        small('慢慢来，也很棒。'),
        const SizedBox(height: 20),
        TextButton.icon(
          key: const Key('parent-entry'),
          onPressed: changeRole,
          icon: Icon(parentMode ? Icons.logout : Icons.lock_outline, size: 18),
          label: Text(parentMode ? '回到孩子端' : '家长空间'),
        ),
      ],
    ),
  );

  List<Widget> childPage() => switch (page) {
    1 => tasksPage(),
    2 => moneyPage(),
    _ => wishesPage(),
  };
  List<Widget> parentPage() => switch (page) {
    1 => wishesPage(parent: true),
    2 => agreementsPage(),
    _ => inboxPage(),
  };

  List<Widget> wishesPage({bool parent = false}) => [
    if (s.mainWish != null)
      wishHero(s.mainWish!)
    else
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset('assets/svg/telescope.svg', height: 90),
            const SizedBox(height: 12),
            const Text(
              '你想把努力，变成什么？',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            small(
              s.wishes.any((w) => w.status != 'deleted')
                  ? '完成的心愿留在心愿夹里，再选一个想努力的方向吧。'
                  : '可以是一份礼物，也可以是第一次攒钱。真实家庭从零开始。',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const Key('new-wish'),
                onPressed: newWish,
                icon: const Icon(Icons.add),
                label: Text(
                  s.wishes.any((w) => w.status != 'deleted')
                      ? '写下新心愿'
                      : '写下第一个心愿',
                ),
              ),
            ),
          ],
        ),
      ),
    if (s.wishes.any((w) => w.status != 'deleted'))
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            small(
              s.wishes.any((w) => w.available && !w.isMain)
                  ? '排队心愿 · ${s.wishes.firstWhere((w) => w.available && !w.isMain).name}'
                  : '一次专心攒一个，其他心愿可以先排队。',
            ),
            TextButton.icon(
              key: const Key('wish-folder'),
              onPressed: wishFolder,
              icon: const Icon(Icons.folder_outlined, size: 19),
              label: const Text('心愿夹'),
            ),
          ],
        ),
      ),
    if (parent) ...[
      heading('孩子的零钱安排'),
      stats(),
      const SizedBox(height: 12),
      small('切换孩子后需重新解锁。两个孩子的心愿、任务与账本独立。'),
      TextButton.icon(
        onPressed: profiles,
        icon: const Icon(Icons.switch_account_outlined),
        label: const Text('选择另一个孩子'),
      ),
    ] else ...[
      heading(
        '做好了，点一下',
        action: TextButton(
          onPressed: () => navigate(1),
          child: const Text('查看任务 ›'),
        ),
      ),
      quickGrid(),
      const SizedBox(height: 10),
      small('现实中做好再点。家长实际兑现后，零钱才会增加。'),
      heading('还有这些小小的可能'),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          actionTile(
            Icons.assignment_outlined,
            '现实劳动与小任务',
            '挑一件约好的事',
            () => navigate(1),
          ),
          actionTile(
            Icons.eco_outlined,
            '让已有零钱慢慢长大',
            '先看期限，再做安排',
            () => panel('savings'),
          ),
          actionTile(
            Icons.handshake_outlined,
            '和家长聊聊预支',
            '看清月供，借款不算积累',
            () => panel('loans'),
          ),
        ],
      ),
    ],
  ];

  Widget wishHero(Wish w) {
    final saved = math.max(0, s.conservative),
        ratio = (math.max(0, s.conservative) / w.target).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, size) {
        final art = size.maxWidth >= 620;
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border.all(color: p.line),
              borderRadius: BorderRadius.circular(24),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                w.kind == 'gift'
                                    ? Icons.card_giftcard
                                    : Icons.savings_outlined,
                                color: p.brand,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '头号心愿 · ${w.kind == 'gift' ? '礼物心愿' : '攒钱目标'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: p.brand,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            w.name,
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Semantics(
                            excludeSemantics: true,
                            label:
                                '已确认积累 ${Money.format(saved)} 元，目标 ${Money.format(w.target)} 元，进度 ${(ratio * 100).floor()}%',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 5,
                                  children: [
                                    Text(
                                      Money.format(saved),
                                      key: const Key('wish-progress-amount'),
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    small('/ ${Money.format(w.target)} 元'),
                                    tag(
                                      '${(ratio * 100).floor()}%',
                                      done: true,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          small(
                            saved >= w.target
                                ? '已经准备好这份积累啦。实际领取还要请家长确认。'
                                : '再攒 ${Money.format(math.max(0, w.target - s.conservative))} 元，就更近一步。',
                          ),
                          if (s.debt > 0)
                            small('已扣除计划待还 ¥${Money.format(s.debt)}，含未来利息。'),
                          if (w.achievedOn != null)
                            small('${w.achievedOn} 已记录攒够纪念，礼物到手另由家长确认。'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (saved >= w.target && w.achievedOn == null)
                                FilledButton(
                                  key: const Key('mark-saved'),
                                  onPressed: c.busy
                                      ? null
                                      : () => confirmWish('markSaved', w),
                                  child: const Text('记下攒够纪念'),
                                ),
                              TextButton(
                                key: const Key('manage-main-wish'),
                                onPressed: () => manageWish(w.id),
                                child: const Text('管理这份心愿'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (art)
                    Expanded(
                      flex: 4,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 240),
                        color: p.night,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              right: 24,
                              top: 20,
                              child: Container(
                                width: 25,
                                height: 25,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE8D19C),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const Positioned(
                              left: 30,
                              top: 34,
                              child: Icon(
                                Icons.auto_awesome,
                                color: Color(0xFFE8D19C),
                                size: 18,
                              ),
                            ),
                            Positioned(
                              bottom: -42,
                              left: -40,
                              right: -80,
                              child: Transform.rotate(
                                angle: -.12,
                                child: Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: p.ground,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                36,
                                28,
                                36,
                                48,
                              ),
                              child: SvgPicture.asset(
                                w.kind == 'gift'
                                    ? 'assets/svg/telescope.svg'
                                    : 'assets/svg/tree-sprout.svg',
                                width: 195,
                                height: 155,
                              ),
                            ),
                            Positioned(
                              left: 10,
                              right: 10,
                              bottom: 20,
                              child: Text(
                                w.kind == 'gift'
                                    ? '把远方的小秘密，看近一点。'
                                    : '让小小的积累，慢慢发芽。',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFFFF3DE),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String wishStatus(Wish w) {
    if (w.status == 'archived') return '已归档';
    if (w.receivedOn != null) return '礼物已到手';
    if (w.kind == 'saving' && w.achievedOn != null) return '已攒够';
    if (w.achievedOn != null) return '已攒够，等礼物到手';
    return w.isMain ? '头号心愿' : '排队中';
  }

  Future<void> confirmWish(String action, Wish w) async {
    final (title, note) = switch (action) {
      'markSaved' => ('记下攒够纪念', '记录今天已达到目标，不扣钱、不冻结零钱。这是当时的纪念，之后的实际积累仍随账本变化。'),
      'deleteWish' => ('删除这份心愿？', '只删除尚未完成、没有付款关联的心愿，不改变零钱与流水。已有纪念或申请请归档。'),
      _ => ('把心愿收进档案？', '保留目标、完成纪念、付款关联与债务。归档头号心愿后，请明确选择下一个。'),
    };
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text('${w.name}\n\n$note'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('再想想'),
          ),
          FilledButton(
            key: Key('confirm-$action'),
            onPressed: () async {
              if (await run(action, [w.id]) && context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  Future<void> manageWish(String id) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final w = s.wishes.firstWhere((w) => w.id == id);
          final loans = s.loans.where((l) => l.wishId == w.id).toList();
          final withdrawals = s.requests
              .where((r) => r.wishId == w.id)
              .toList();
          final giftDebt = loans
              .where((l) => l.usedForGift && l.status == 'active')
              .fold<int>(0, (v, l) => v + l.balance);
          final linked = loans.isNotEmpty || withdrawals.isNotEmpty;
          return AlertDialog(
            title: Text(w.name),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${wishStatus(w)} · 目标 ¥${Money.format(w.target)}'),
                    if (w.achievedOn != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '${w.achievedOn} 攒够纪念\n当时真实积累 ¥${Money.format(w.achievedAmount)}。这是历史里程碑，未重复分配或扣款。',
                        ),
                      ),
                    if (w.receivedOn != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '${w.receivedOn} 礼物已到手\n实际购买 ¥${Money.format(w.receivedCost)}，关联已交付自付与已垫付本金。',
                        ),
                      ),
                    if (loans.any((l) => l.usedForGift))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          giftDebt == 0
                              ? '这份礼物的预支已经还清。'
                              : '这份礼物计划待还 ¥${Money.format(giftDebt)}，含未来约定利息。到手不等于还清。',
                        ),
                      ),
                    if (linked) ...[
                      const SizedBox(height: 12),
                      const Text('关联付款 · 历史保留'),
                      for (final r in withdrawals)
                        Text(
                          '自付 ¥${Money.format(r.amount)} · ${r.date} · ${r.status == 'paid' ? '已交付' : '待交付'}${r.usedForGift ? ' · 已登记到手' : ''}',
                        ),
                      for (final l in loans)
                        Text(
                          '预支本金 ¥${Money.format(l.amount)} · ${l.requested} · ${l.funded == null
                              ? '尚未垫付'
                              : l.status == 'paid'
                              ? '已还清'
                              : '已垫付，待还 ¥${Money.format(l.balance)}'}${l.usedForGift ? ' · 已登记到手' : ''}',
                        ),
                      const Text('已有付款关联，请归档保留历史；到手不会再次扣钱。'),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (w.available && w.achievedOn == null)
                          OutlinedButton(
                            key: Key('edit-wish-$id'),
                            onPressed: c.busy
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    newWish(wish: w);
                                  },
                            child: const Text('编辑心愿'),
                          ),
                        if (w.available && !w.isMain)
                          FilledButton(
                            onPressed: c.busy
                                ? null
                                : () => run('selectWish', [id]),
                            child: const Text('设为头号'),
                          ),
                        if (w.available &&
                            w.isMain &&
                            w.achievedOn == null &&
                            s.conservative >= w.target)
                          FilledButton(
                            onPressed: c.busy
                                ? null
                                : () => confirmWish('markSaved', w),
                            child: const Text('记下攒够纪念'),
                          ),
                        if (w.available && w.kind == 'gift')
                          OutlinedButton(
                            key: Key('receive-gift-$id'),
                            onPressed: c.busy
                                ? null
                                : () async {
                                    if (!parentMode || c.parent == null) {
                                      tell(
                                        context,
                                        '请家长在「孩子与心愿」中核实实际付款，登记礼物到手。',
                                      );
                                      return;
                                    }
                                    await showDialog<void>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => GiftReceipt(c, w),
                                    );
                                  },
                            child: const Text('礼物到手，请家长登记'),
                          ),
                        if (w.status == 'open')
                          TextButton(
                            onPressed: c.busy
                                ? null
                                : () async {
                                    await confirmWish('archiveWish', w);
                                    if (context.mounted &&
                                        s.wishes
                                                .firstWhere(
                                                  (item) => item.id == id,
                                                )
                                                .status ==
                                            'archived') {
                                      Navigator.pop(context);
                                    }
                                  },
                            child: const Text('归档'),
                          ),
                        if (w.status == 'archived' && !w.completed)
                          TextButton(
                            onPressed: c.busy
                                ? null
                                : () => run('restoreWish', [id]),
                            child: const Text('回到排队'),
                          ),
                        if (w.status == 'open' &&
                            w.achievedOn == null &&
                            w.receivedOn == null &&
                            !linked)
                          TextButton(
                            key: Key('delete-wish-$id'),
                            onPressed: c.busy
                                ? null
                                : () async {
                                    await confirmWish('deleteWish', w);
                                    if (context.mounted &&
                                        s.wishes
                                                .firstWhere(
                                                  (item) => item.id == id,
                                                )
                                                .status ==
                                            'deleted') {
                                      Navigator.pop(context);
                                    }
                                  },
                            child: const Text('删除未完成心愿'),
                          ),
                      ],
                    ),
                    if (w.available && w.kind == 'gift') ...[
                      const SizedBox(height: 12),
                      const Text(
                        '自付先在「我的零钱」申请领取，家长确认已实际交付。预支需完成条件确认和实际垫付。登记到手只关联原记录，不再扣钱。',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> editTask(LaborTask t) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ActionForm(
      title: '编辑临时任务 · ${s.name}',
      labels: const ['任务名称', '完成标准', '报酬（元）'],
      initial: [t.name, t.detail, Money.format(t.amount)],
      submitLabel: '保存修改',
      note: '仅限孩子尚未接下的任务。接下后保留原标准和报酬。',
      onSubmit: (v) =>
          c.perform('editTask', [t.id, v[0], Money.parse(v[2]), v[1]]),
    ),
  );

  Future<void> cancelTask(LaborTask t) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('停用「${t.name}」？'),
      content: const Text('孩子尚未接下，这次停用不会入账；处理历史会保留。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('保留'),
        ),
        FilledButton(
          onPressed: () async {
            if (await run('cancelTask', [t.id]) && context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('停用任务'),
        ),
      ],
    ),
  );

  Future<void> wishFolder() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AnimatedBuilder(
        animation: c,
        builder: (context, _) => AlertDialog(
          title: Text('${s.name}的心愿夹'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('同一笔积累只用于头号心愿，其他心愿先排队。'),
                  for (final w in s.wishes.where((w) => w.status != 'deleted'))
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          w.kind == 'gift'
                              ? Icons.card_giftcard
                              : Icons.savings_outlined,
                        ),
                        title: Text(w.name),
                        subtitle: Text(
                          '目标 ¥${Money.format(w.target)} · ${wishStatus(w)}',
                        ),
                        onTap: () => manageWish(w.id),
                        trailing: w.available && !w.isMain
                            ? TextButton(
                                key: Key('main-${w.id}'),
                                onPressed: c.busy
                                    ? null
                                    : () => run('selectWish', [w.id]),
                                child: const Text('设为头号'),
                              )
                            : const Icon(Icons.chevron_right),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
            FilledButton.icon(
              key: const Key('new-wish'),
              onPressed: () {
                Navigator.pop(context);
                newWish();
              },
              icon: const Icon(Icons.add),
              label: const Text('新建心愿'),
            ),
          ],
        ),
      ),
    );
  }

  Widget quickGrid() => LayoutBuilder(
    builder: (context, size) {
      final count = size.maxWidth >= 650
          ? 5
          : size.maxWidth >= 360
          ? 3
          : 2;
      final width = (size.maxWidth - (count - 1) * 12) / count;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final id in QuickTask.names.keys)
            SizedBox(width: width, child: quickCard(id)),
        ],
      );
    },
  );

  Widget quickCard(String id) {
    final q = s.quickTasks.where((q) => q.id == id).firstOrNull,
        t = s.quickInstance(id);
    final label = t == null && (q == null || !q.enabled)
        ? (q != null && q.amount > 0 ? '暂时休息' : '等家长约定')
        : t == null || ['available', 'accepted'].contains(t.status)
        ? '做好点我'
        : t.status == 'paid'
        ? '今天已完成'
        : Engine.taskLabel(t.status);
    return Semantics(
      button: true,
      enabled: !c.busy,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.line),
        ),
        child: InkWell(
          key: Key('quick-$id'),
          borderRadius: BorderRadius.circular(20),
          onTap: c.busy ? null : () => quickTap(id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            child: Column(
              children: [
                ExcludeSemantics(
                  child: SvgPicture.asset(
                    'assets/svg/quick-tasks/$id.svg',
                    width: 52,
                    height: 52,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  QuickTask.names[id]!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                small(
                  q == null || q.amount == 0
                      ? '先说好标准与报酬'
                      : '约定 ${Money.format(t?.amount ?? q.amount)} 元',
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: t?.status == 'paid' ? p.green : p.brand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget actionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => SizedBox(
    width: 280,
    child: Semantics(
      button: true,
      child: Material(
        color: p.soft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(icon, color: p.brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      small(subtitle),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> tasksPage() => [
    heading('每一件小事，都算数'),
    small('常做任务现实中完成后点一下。新任务先接下，再按约定完成。'),
    const SizedBox(height: 16),
    quickGrid(),
    heading('我的任务记录'),
    Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('进行中'),
          selected: !completedOnly,
          onSelected: (_) => setState(() => completedOnly = false),
        ),
        ChoiceChip(
          label: const Text('历史记录'),
          selected: completedOnly,
          onSelected: (_) => setState(() => completedOnly = true),
        ),
      ],
    ),
    const SizedBox(height: 12),
    if (s.tasks
        .where(
          (t) => (['paid', 'cancelled'].contains(t.status)) == completedOnly,
        )
        .isEmpty)
      card(
        small(
          completedOnly
              ? '已兑现和未接取就停用的任务都会留在这里，各自保留处理状态。'
              : '今天的常做任务在上方。家长也可以约一份临时小任务。',
        ),
      ),
    for (final t in s.tasks.reversed.where(
      (t) => (['paid', 'cancelled'].contains(t.status)) == completedOnly,
    ))
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    t.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  tag(Engine.taskLabel(t.status), done: t.status == 'paid'),
                  Text('¥${Money.format(t.amount)}'),
                ],
              ),
              const SizedBox(height: 8),
              small(t.detail),
              if (t.feedback.isNotEmpty)
                Text('家长的小提醒：${t.feedback}', style: TextStyle(color: p.brand)),
              if (t.status == 'available' && t.templateId == null)
                TextButton(
                  key: Key('accept-${t.id}'),
                  onPressed: c.busy ? null : () => run('accept', [t.id]),
                  child: const Text('接下这个任务'),
                )
              else
                TextButton(
                  key: Key('detail-${t.id}'),
                  onPressed: () => taskDetail(t),
                  child: Text(
                    ['accepted', 'needsWork'].contains(t.status)
                        ? '查看要求，做好后提交 ›'
                        : '查看本次状态 ›',
                  ),
                ),
            ],
          ),
        ),
      ),
  ];

  Widget stats() => LayoutBuilder(
    builder: (context, size) {
      final n = size.maxWidth >= 700 ? 4 : 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in [
            ('可用零钱', s.wallet),
            ('持有本金', s.holding),
            ('待领取', s.pendingCash),
            ('计划待还', s.debt),
          ])
            SizedBox(
              width: (size.maxWidth - (n - 1) * 12) / n,
              child: Semantics(
                excludeSemantics: true,
                label: '${item.$1} ${Money.format(item.$2)} 元',
                child: card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      small(item.$1),
                      const SizedBox(height: 6),
                      Text(
                        '¥${Money.format(item.$2)}',
                        key: item.$1 == '可用零钱'
                            ? const Key('wallet-amount')
                            : null,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  List<Widget> moneyPage() => [
    heading('我的每一分，都有来处'),
    stats(),
    const SizedBox(height: 12),
    small('保守积累 = 零钱 + 持有 + 待领取 − 计划待还（含未来利息）。预计收益与借款不算新收入。'),
    heading('慢慢安排自己的零钱'),
    Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        actionTile(
          Icons.eco_outlined,
          '存入与分红',
          '已有本金的下一站',
          () => panel('savings'),
        ),
        actionTile(
          Icons.handshake_outlined,
          '预支与主动还款',
          '看清约定，按月主动还',
          () => panel('loans'),
        ),
        actionTile(
          Icons.payments_outlined,
          '申请实际领取',
          '家长交付后才记为已领取',
          () => panel('journal'),
        ),
        actionTile(
          Icons.show_chart,
          '成长投影',
          '真实收获与未来假设分开',
          () => panel('growth'),
        ),
      ],
    ),
    heading('收获手账'),
    if (s.ledger
        .where(
          (l) => [
            'income',
            'yield',
            'repay',
            'withdraw',
            'invest',
          ].contains(l.kind),
        )
        .isEmpty)
      card(small('家长实际兑现的第一份报酬，会保存在这里。')),
    for (final l in s.ledger.reversed.where(
      (l) =>
          ['income', 'yield', 'repay', 'withdraw', 'invest'].contains(l.kind),
    ))
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: card(
          Row(
            children: [
              Icon(
                l.kind == 'income'
                    ? Icons.task_alt
                    : l.kind == 'yield'
                    ? Icons.eco_outlined
                    : Icons.menu_book_outlined,
                color: p.green,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(l.title), small(l.date)],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '¥${Money.format(l.amount)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
  ];

  List<Widget> locked() => [
    const SizedBox(height: 16),
    card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 32),
          const SizedBox(height: 12),
          Text(
            '这一步交给家长 · ${s.name}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          small('请用建档时设置的口令解锁。离开 APP 或切换孩子后会重新锁定。'),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: TextField(
              key: const Key('parent-pin'),
              controller: pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '家长口令',
                errorText: pinError,
              ),
              onSubmitted: (_) => unlock(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('unlock-parent'),
            onPressed: unlocking ? null : unlock,
            child: Text(unlocking ? '正在解锁…' : '解锁家长空间'),
          ),
          TextButton(
            key: const Key('recover-parent'),
            onPressed: unlocking
                ? null
                : () => recoverParent(context, c.service.auth, c.family),
            child: const Text('忘记口令？使用家长恢复码'),
          ),
        ],
      ),
    ),
  ];

  Future<void> unlock() async {
    if (unlocking) return;
    setState(() => unlocking = true);
    try {
      await c.unlock(pin.text);
      pin.clear();
      if (mounted) setState(() => pinError = null);
    } catch (e) {
      if (mounted) setState(() => pinError = userMessage(e));
    } finally {
      if (mounted) setState(() => unlocking = false);
    }
  }

  List<Widget> inboxPage() {
    final pending = s.tasks
        .where((t) => ['submitted', 'confirmed'].contains(t.status))
        .toList();
    return [
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '正在陪伴 · ${s.name}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            small('${pending.length} 件劳动或学习待处理。检查通过和实际兑现分两步。'),
            const SizedBox(height: 12),
            tag('本机家庭 · 双孩独立账本', done: true),
          ],
        ),
      ),
      heading('每一份认真，都值得看见'),
      if (pending.isEmpty)
        card(
          Column(
            children: [
              SvgPicture.asset('assets/svg/mascot.svg', height: 90),
              const SizedBox(height: 12),
              const Text('暂时没有待确认的任务'),
              small('孩子提交后，会出现在这里。'),
            ],
          ),
        ),
      for (final t in pending)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      t.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    tag(Engine.taskLabel(t.status)),
                  ],
                ),
                const SizedBox(height: 8),
                small(t.detail),
                const SizedBox(height: 12),
                FilledButton(
                  key: Key('review-${t.id}'),
                  style: t.status == 'confirmed'
                      ? FilledButton.styleFrom(
                          backgroundColor: p.accent,
                          foregroundColor: p.onAccent,
                        )
                      : null,
                  onPressed: c.busy ? null : () => taskDetail(t, parent: true),
                  child: Text(
                    t.status == 'confirmed'
                        ? '实际兑现 ¥${Money.format(t.amount)}'
                        : '查看并检查 · ¥${Money.format(t.amount)}',
                  ),
                ),
              ],
            ),
          ),
        ),
      heading('领取、预支与其他约定'),
      small(
        '待实际领取 ${s.requests.where((r) => r.status == 'pending').length} 笔 · 预支待处理 ${s.loans.where((l) => ['pending', 'offered', 'approved'].contains(l.status)).length} 笔',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: () => panel('parent'),
          child: const Text('管理领取、预支和收益预算'),
        ),
      ),
    ];
  }

  List<Widget> agreementsPage() => [
    heading('${s.name}的常做任务'),
    small('先约好标准与报酬，再由孩子在现实里完成。每天最多提交一份，各次记录独立保存。'),
    const SizedBox(height: 16),
    for (final id in QuickTask.names.keys)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: card(
          Row(
            children: [
              SvgPicture.asset(
                'assets/svg/quick-tasks/$id.svg',
                width: 48,
                height: 48,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      QuickTask.names[id]!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    small(
                      s.quickTasks
                              .where((q) => q.id == id && q.amount > 0)
                              .isEmpty
                          ? '尚未约定'
                          : '每次 ¥${Money.format(s.quickTasks.firstWhere((q) => q.id == id).amount)}${s.quickTasks.firstWhere((q) => q.id == id).enabled ? '' : ' · 已暂停'}',
                    ),
                    small(
                      s.quickTasks
                              .where((q) => q.id == id)
                              .firstOrNull
                              ?.detail ??
                          QuickTask.standards[id]!,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  OutlinedButton(
                    key: Key('configure-$id'),
                    onPressed: c.busy ? null : () => configure(id),
                    child: const Text('约定'),
                  ),
                  if (s.quickTasks.any((q) => q.id == id && q.amount > 0))
                    TextButton(
                      key: Key('toggle-$id'),
                      onPressed: c.busy
                          ? null
                          : () => run('setQuickEnabled', [
                              id,
                              !s.quickTasks
                                  .firstWhere((q) => q.id == id)
                                  .enabled,
                            ]),
                      child: Text(
                        s.quickTasks.firstWhere((q) => q.id == id).enabled
                            ? '暂停'
                            : '恢复',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    heading('额外的小任务'),
    Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        key: const Key('add-task'),
        onPressed: () => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ActionForm(
            title: '约一份临时任务 · ${s.name}',
            labels: const ['任务名称', '完成标准', '报酬（元）'],
            initial: const ['', '', ''],
            submitLabel: '保存任务',
            onSubmit: (v) async {
              require(v[1].trim().isNotEmpty, '请填写具体完成标准');
              await c.perform('addTask', [v[0], Money.parse(v[2]), v[1]]);
            },
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('约一份临时任务'),
      ),
    ),
    for (final t in s.tasks.reversed.where((t) => t.templateId == null))
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              small(
                '${Engine.taskLabel(t.status)} · ¥${Money.format(t.amount)} · ${t.detail}',
              ),
              if (t.status == 'available')
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      key: Key('edit-task-${t.id}'),
                      onPressed: c.busy ? null : () => editTask(t),
                      child: const Text('编辑'),
                    ),
                    TextButton(
                      key: Key('cancel-task-${t.id}'),
                      onPressed: c.busy ? null : () => cancelTask(t),
                      child: const Text('停用'),
                    ),
                  ],
                )
              else
                small('保留这次标准、报酬与处理历史。已接受的承诺不随新约定改变。'),
            ],
          ),
        ),
      ),
    heading('收益与预支'),
    small('收益由家长按事先约定与预算承担。预支需孩子阅读条件、家长实际垫付后才生效。'),
    Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        onPressed: () => panel('parent'),
        child: const Text('管理收益预算、领取和预支'),
      ),
    ),
    const SizedBox(height: 20),
    Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        key: const Key('family-data'),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => FamilySettings(c),
        ),
        icon: const Icon(Icons.backup_outlined),
        label: const Text('备份、恢复与家长口令'),
      ),
    ),
    small('亲子互通：当前为本机存档，尚未接入 iCloud。换设备不会自动出现本机记录。'),
  ];
}

// The form owns input/errors so reflow and validation failures preserve the child input.
class WishEditor extends StatefulWidget {
  const WishEditor(this.controller, {this.wish, super.key});
  final TownController controller;
  final Wish? wish;
  @override
  State<WishEditor> createState() => _WishEditorState();
}

class _WishEditorState extends State<WishEditor> {
  late String kind = widget.wish?.kind ?? 'gift';
  @override
  Widget build(BuildContext context) => ActionForm(
    title: widget.wish == null ? '写下一个小心愿' : '调整这份心愿',
    labels: const ['心愿名称', '目标金额（元）'],
    initial: [
      widget.wish?.name ?? '',
      widget.wish == null ? '' : Money.format(widget.wish!.target),
    ],
    submitLabel: widget.wish == null ? '放进心愿夹' : '保存修改',
    leading: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'gift',
            icon: Icon(Icons.card_giftcard),
            label: Text('礼物心愿'),
          ),
          ButtonSegment(
            value: 'saving',
            icon: Icon(Icons.savings_outlined),
            label: Text('攒钱目标'),
          ),
        ],
        selected: {kind},
        onSelectionChanged:
            widget.wish != null &&
                Engine.hasWishPayments(
                  widget.controller.account,
                  widget.wish!.id,
                )
            ? null
            : (v) => setState(() => kind = v.single),
      ),
    ),
    note: '第一个心愿成为头号心愿，之后的先排队。同一笔积累只算一次。',
    onSubmit: (v) => widget.controller.perform(
      widget.wish == null ? 'addWish' : 'editWish',
      [if (widget.wish != null) widget.wish!.id, kind, v[0], Money.parse(v[1])],
    ),
  );
}

class GiftReceipt extends StatefulWidget {
  const GiftReceipt(this.controller, this.wish, {super.key});
  final TownController controller;
  final Wish wish;
  @override
  State<GiftReceipt> createState() => _GiftReceiptState();
}

class _GiftReceiptState extends State<GiftReceipt> {
  final withdrawals = <String>{}, loans = <String>{};
  bool handedOver = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.controller.account;
    final eligibleWithdrawals = s.requests
        .where(
          (r) =>
              r.status == 'paid' &&
              !r.usedForGift &&
              (r.wishId == null || r.wishId == widget.wish.id),
        )
        .toList();
    final eligibleLoans = s.loans
        .where(
          (l) =>
              l.funded != null &&
              ['active', 'paid'].contains(l.status) &&
              !l.usedForGift &&
              (l.wishId == null || l.wishId == widget.wish.id),
        )
        .toList();
    final ownTotal = eligibleWithdrawals
        .where((r) => withdrawals.contains(r.id))
        .fold<int>(0, (v, r) => v + r.amount);
    final loanTotal = eligibleLoans
        .where((l) => loans.contains(l.id))
        .fold<int>(0, (v, l) => v + l.amount);
    return ActionForm(
      title: '礼物已实际到手 · ${s.name}',
      labels: const ['实际购买金额（元）'],
      initial: [Money.format(widget.wish.target)],
      submitLabel: '保存到手纪念',
      note: '逐笔勾选确实用于这份礼物的付款，可合并多笔。旧单据确认后会关联本心愿；每笔只能用一次。未交付或未垫付的单据需先完成对应流程。',
      leading: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.wish.name),
          const SizedBox(height: 16),
          const Text('已实际交付的自付 · 可多选'),
          if (eligibleWithdrawals.isEmpty) const Text('没有可用自付记录'),
          for (final r in eligibleWithdrawals)
            CheckboxListTile(
              key: Key('gift-withdrawal-${r.id}'),
              contentPadding: EdgeInsets.zero,
              value: withdrawals.contains(r.id),
              onChanged: (v) => setState(() {
                if (v!) {
                  withdrawals.add(r.id);
                } else {
                  withdrawals.remove(r.id);
                }
              }),
              title: Text('${r.purpose} · ¥${Money.format(r.amount)}'),
              subtitle: Text(
                '${r.date} · ${r.wishId == null ? '尚未关联，确认后用于本心愿' : '已关联本心愿'}',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          const SizedBox(height: 16),
          const Text('家长已实际垫付的预支 · 可多选'),
          if (eligibleLoans.isEmpty) const Text('没有可用垫付记录'),
          for (final l in eligibleLoans)
            CheckboxListTile(
              key: Key('gift-loan-${l.id}'),
              contentPadding: EdgeInsets.zero,
              value: loans.contains(l.id),
              onChanged: (v) => setState(() {
                if (v!) {
                  loans.add(l.id);
                } else {
                  loans.remove(l.id);
                }
              }),
              title: Text('${l.item} · 本金 ¥${Money.format(l.amount)}'),
              subtitle: Text(
                '${l.funded} · ${l.status == 'paid' ? '已还清' : '计划待还 ¥${Money.format(l.balance)}，含未来利息'}\n${l.wishId == null ? '尚未关联，确认后用于本心愿' : '已关联本心愿'}',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              '已选自付 ¥${Money.format(ownTotal)} + 垫付本金 ¥${Money.format(loanTotal)}\n付款合计 ¥${Money.format(ownTotal + loanTotal)}，应与实际购买金额一致',
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            key: const Key('gift-handed-over'),
            contentPadding: EdgeInsets.zero,
            value: handedOver,
            onChanged: (v) => setState(() => handedOver = v!),
            title: const Text('已核实上述付款用于这份礼物，孩子已实际收到'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
      onSubmit: (v) async {
        require(handedOver, '请先核实付款用途与礼物实际到手');
        await widget.controller.perform('receiveGift', [
          widget.wish.id,
          withdrawals.toList()..sort(),
          loans.toList()..sort(),
          Money.parse(v[0]),
        ]);
      },
    );
  }
}

class ActionForm extends StatefulWidget {
  const ActionForm({
    required this.title,
    required this.labels,
    required this.initial,
    required this.submitLabel,
    required this.onSubmit,
    this.note,
    this.leading,
    this.secretFields = const {},
    super.key,
  });
  final String title, submitLabel;
  final List<String> labels, initial;
  final String? note;
  final Widget? leading;
  final Set<int> secretFields;
  final Future<void> Function(List<String>) onSubmit;
  @override
  State<ActionForm> createState() => _ActionFormState();
}

class _ActionFormState extends State<ActionForm> with WidgetsBindingObserver {
  late final inputs = [
    for (final text in widget.initial) TextEditingController(text: text),
  ];
  final form = GlobalKey<FormState>();
  String? error;
  bool saving = false;
  final Set<int> revealed = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    for (final i in widget.secretFields) {
      inputs[i].clear();
    }
    if (revealed.isNotEmpty) setState(revealed.clear);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final input in inputs) {
      input.dispose();
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.leading != null) widget.leading!,
                if (widget.note != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      widget.note!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                for (var i = 0; i < inputs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      key: Key('action-field-$i'),
                      controller: inputs[i],
                      obscureText:
                          widget.secretFields.contains(i) &&
                          !revealed.contains(i),
                      enableSuggestions: !widget.secretFields.contains(i),
                      autocorrect: !widget.secretFields.contains(i),
                      decoration: InputDecoration(
                        labelText: widget.labels[i],
                        suffixIcon: widget.secretFields.contains(i)
                            ? IconButton(
                                tooltip: revealed.contains(i) ? '隐藏输入' : '显示输入',
                                icon: Icon(
                                  revealed.contains(i)
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(() {
                                  if (!revealed.add(i)) revealed.remove(i);
                                }),
                              )
                            : null,
                      ),
                      keyboardType: widget.labels[i].contains('（元）')
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? '请填写${widget.labels[i]}'
                          : null,
                    ),
                  ),
                if (error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      key: const Key('form-error'),
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
          key: const Key('action-save'),
          onPressed: saving
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  setState(() {
                    saving = true;
                    error = null;
                  });
                  try {
                    await widget.onSubmit(inputs.map((e) => e.text).toList());
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) setState(() => error = userMessage(e));
                  } finally {
                    if (mounted) setState(() => saving = false);
                  }
                },
          child: Text(saving ? '保存中…' : widget.submitLabel),
        ),
      ],
    ),
  );
}

class TaskReview extends StatefulWidget {
  const TaskReview(this.controller, this.id, {super.key});
  final TownController controller;
  final String id;
  @override
  State<TaskReview> createState() => _TaskReviewState();
}

class _TaskReviewState extends State<TaskReview> {
  bool delivered = false;
  String? error;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller, p = PaperColors.of(context);
      final t = c.account.tasks.firstWhere((t) => t.id == widget.id);
      return AlertDialog(
        title: Text('正在处理 · ${c.account.name}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(t.detail),
                const SizedBox(height: 16),
                Text(
                  '约定 ¥${Money.format(t.amount)} · ${Engine.taskLabel(t.status)}',
                ),
                if (c.parent == null) const Text('家长空间已锁定，请返回重新解锁。'),
                if (t.status == 'confirmed') ...[
                  const SizedBox(height: 16),
                  const Text('检查通过还没有入账。请先完成现实中的交付或预留代管。'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: p.accentSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: CheckboxListTile(
                      key: const Key('payment-delivered'),
                      value: delivered,
                      onChanged: c.busy
                          ? null
                          : (v) => setState(() => delivered = v!),
                      title: Text('我已向${c.account.name}实际交付，或预留代管这笔报酬'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
                if (t.status == 'paid')
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('已经兑现并保存，孩子的心愿进度已更新。'),
                  ),
                if (error != null)
                  Text(error!, style: TextStyle(color: p.danger)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: c.busy ? null : () => Navigator.pop(context),
            child: const Text('返回'),
          ),
          if (t.status == 'submitted')
            OutlinedButton(
              key: Key('feedback-${t.id}'),
              onPressed: c.busy || c.parent == null
                  ? null
                  : () async {
                      await showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => ActionForm(
                          title: '给${c.account.name}一个具体的小提醒',
                          labels: const ['哪里再试试就更好'],
                          initial: const [''],
                          submitLabel: '送出小提醒',
                          onSubmit: (v) =>
                              c.perform('requestChanges', [t.id, v[0]]),
                        ),
                      );
                      if (context.mounted &&
                          c.account.tasks
                                  .firstWhere((x) => x.id == t.id)
                                  .status ==
                              'needsWork') {
                        Navigator.pop(context);
                      }
                    },
              child: const Text('给个小提醒'),
            ),
          if (t.status == 'submitted')
            FilledButton(
              key: Key('approve-${t.id}'),
              onPressed: c.busy || c.parent == null
                  ? null
                  : () => perform('approve', [t.id]),
              child: const Text('检查通过'),
            ),
          if (t.status == 'confirmed')
            FilledButton(
              key: Key('pay-${t.id}'),
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.onAccent,
              ),
              onPressed: c.busy || !delivered || c.parent == null
                  ? null
                  : () => perform('pay', [t.id]),
              child: Text('确认兑现 ¥${Money.format(t.amount)}'),
            ),
        ],
      );
    },
  );
  Future<void> perform(String action, List<Object?> args) async {
    try {
      await widget.controller.perform(action, args);
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = userMessage(e));
    }
  }
}
