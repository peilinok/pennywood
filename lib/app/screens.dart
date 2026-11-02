import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../data/service.dart';
import '../domain/model.dart';
import '../domain/money.dart';
import '../game/town_game.dart';
import '../features/panels.dart';
import '../features/wish_home.dart';
import '../features/family_settings.dart';
import 'controller.dart';

String userMessage(Object error) {
  if (error is RuleViolation) return error.message;
  debugPrint('栗子小镇操作失败：$error');
  return '保存暂时未完成，请重试；原有记录已保留。';
}

void tell(BuildContext context, Object message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message is String ? message : userMessage(message)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 76),
        duration: const Duration(seconds: 2),
      ),
    );
}

class FamilyEntry extends StatefulWidget {
  const FamilyEntry(this.service, {super.key});
  final TownService service;
  @override
  State<FamilyEntry> createState() => _FamilyEntryState();
}

class _FamilyEntryState extends State<FamilyEntry> {
  late Future<List<Map<String, dynamic>>> families;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    families = widget.service.db.rows('SELECT * FROM families ORDER BY demo');
  }

  Future<void> enter(Map<String, dynamic> family) async {
    var service = widget.service;
    if (family['demo'] == 1) {
      final dates = await service.db.rows(
        'SELECT MAX(date) AS date FROM children WHERE family_id=?',
        [family['id']],
      );
      final saved = dates.single['date'] as String?;
      final today = service.clock.today;
      service = TownService(
        service.db,
        service.auth,
        FixedClock(saved != null && saved.compareTo(today) > 0 ? saved : today),
      );
    }
    final controller = TownController(
      service,
      family['id'],
      family['active_child'],
    );
    try {
      await controller.load();
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => WishHome(controller)));
      controller.dispose();
      if (mounted) setState(reload);
    } catch (e) {
      if (mounted) tell(context, e);
    }
  }

  Future<void> setup(bool demo) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SetupDialog(widget.service, demo),
    );
    if (result == true) {
      setState(reload);
      final rows = await families;
      await enter(rows.singleWhere((r) => r['id'] == (demo ? 'demo' : 'real')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/svg/mascot.svg',
                      width: 74,
                      height: 80,
                    ),
                    const SizedBox(width: 20),
                    const Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '栗子小镇',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text('Pennywood · 我的心愿手账'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('把每天的小小努力，攒成自己的心愿。'),
                const SizedBox(height: 20),
                FutureBuilder(
                  future: families,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text('存档暂时无法打开，请重新打开 APP；原有存档已保留。');
                    }
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    final rows = snapshot.data!;
                    return Column(
                      children: [
                        for (final family in rows)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: FilledButton.icon(
                              onPressed: () => enter(family),
                              icon: Icon(
                                family['demo'] == 1
                                    ? Icons.auto_stories
                                    : Icons.home_rounded,
                              ),
                              label: Text(
                                family['demo'] == 1 ? '进入独立示例家庭' : '回到我们的家庭',
                              ),
                            ),
                          ),
                        if (!rows.any((r) => r['id'] == 'real'))
                          FilledButton.icon(
                            key: const Key('create-real'),
                            onPressed: () => setup(false),
                            icon: const Icon(Icons.cottage_outlined),
                            label: const Text('建立我们的家庭 · 从零开始'),
                          ),
                        if (!rows.any((r) => r['id'] == 'demo'))
                          TextButton(
                            onPressed: () => setup(true),
                            child: const Text('先体验独立示例家庭'),
                          ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          key: const Key('restore-at-entry'),
                          onPressed: () async {
                            if (await restoreFamily(context, widget.service) &&
                                mounted) {
                              setState(reload);
                            }
                          },
                          icon: const Icon(Icons.restore),
                          label: const Text('从家庭加密备份恢复'),
                        ),
                        for (final family in rows)
                          TextButton(
                            onPressed: () => recoverParent(
                              context,
                              widget.service.auth,
                              family['id'] as String,
                            ),
                            child: Text(
                              '${family['demo'] == 1 ? '示例家庭' : '我们的家庭'} · 忘记家长口令',
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  '存档保存在本机。请家长定期导出加密备份，卸载前先确认备份可用。',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class SetupDialog extends StatefulWidget {
  const SetupDialog(this.service, this.demo, {super.key});
  final TownService service;
  final bool demo;
  @override
  State<SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<SetupDialog> {
  final first = TextEditingController(),
      second = TextEditingController(),
      pin = TextEditingController(),
      again = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in [first, second, pin, again]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> create() async {
    setState(() => busy = true);
    try {
      require(pin.text == again.text, '两次口令不一致');
      await widget.service.createFamily(
        widget.demo ? 'demo' : 'real',
        pin.text,
        [first.text, second.text],
        demo: widget.demo,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = userMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.demo ? '建立独立示例家庭' : '欢迎来到栗子小镇'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.demo
                  ? '示例有教学本金，与真实家庭完全分开；口令由你设置。'
                  : '两个孩子各有自己的任务、钱包和小镇。初始余额与收益预算均为零。',
            ),
            const SizedBox(height: 12),
            field(first, '第一个孩子的称呼', key: 'first-name'),
            field(second, '第二个孩子的称呼', key: 'second-name'),
            field(pin, '家长口令（6–12 位数字）', key: 'setup-pin', secret: true),
            field(again, '再次输入家长口令', key: 'setup-pin-again', secret: true),
            const Text(
              '请妥善保管家长口令，建档后可在家长空间生成恢复码并另行保存。',
              style: TextStyle(fontSize: 12),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, false),
        child: const Text('返回'),
      ),
      FilledButton(
        key: const Key('finish-setup'),
        onPressed: busy ? null : create,
        child: Text(busy ? '正在建档…' : '开始小镇生活'),
      ),
    ],
  );
}

Widget field(
  TextEditingController controller,
  String label, {
  String? key,
  bool secret = false,
  TextInputType? keyboard,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: TextField(
    key: key == null ? null : Key(key),
    controller: controller,
    obscureText: secret,
    keyboardType: secret ? TextInputType.number : keyboard,
    decoration: InputDecoration(labelText: label),
  ),
);

class TownHome extends StatefulWidget {
  const TownHome(this.controller, {super.key});
  final TownController controller;
  @override
  State<TownHome> createState() => _TownHomeState();
}

class _TownHomeState extends State<TownHome> with WidgetsBindingObserver {
  TownController get c => widget.controller;
  late TownGame game;
  bool panelOpen = false;
  late String gameChild;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    makeGame();
  }

  void makeGame() {
    gameChild = c.child;
    game =
        TownGame(
            c.scene,
            onEnter: (place) async {
              if (c.scene.sound) await SystemSound.play(SystemSoundType.click);
              await openPanel(place);
            },
            onSave: c.saveScene,
            onError: reportError,
          )
          ..settledYield = c.account.bonusEarned
          ..secondChild = c.child == 'second';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void reportError(Object error) {
    if (mounted) tell(context, error);
  }

  Future<void> saveSceneSafely() async {
    try {
      await c.saveScene();
    } catch (e) {
      reportError(e);
    }
  }

  Future<void> guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      reportError(e);
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      guard(() => game.stop());
      c.lock();
    } else if (state == AppLifecycleState.resumed) {
      c.resume().catchError((Object e) {
        if (mounted) tell(context, e);
      });
    }
  }

  Future<void> openPanel(String place) async {
    if (panelOpen || !mounted) return;
    panelOpen = true;
    try {
      await game.stop();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TownPanel(c, place),
      );
    } catch (e) {
      if (mounted) tell(context, e);
    } finally {
      panelOpen = false;
      if (mounted) {
        setState(() {
          if (gameChild != c.child) {
            makeGame();
          }
          game.settledYield = c.account.bonusEarned;
        });
      }
    }
  }

  Future<void> profiles() async {
    await game.stop();
    if (!mounted) return;
    final children = await c.service.db.rows(
      'SELECT id,name FROM children WHERE family_id=? ORDER BY rowid',
      [c.family],
    );
    if (!mounted) return;
    final id = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('今天是谁的小镇？'),
        children: [
          for (final child in children)
            SimpleDialogOption(
              key: Key('switch-${child['id']}'),
              onPressed: () => Navigator.pop(context, child['id']),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${child['name']}的小镇 ${c.child == child['id'] ? '· 当前' : ''}',
                ),
              ),
            ),
        ],
      ),
    );
    if (id != null && id != c.child) {
      await c.switchChild(id);
      if (mounted) setState(makeGame);
    }
  }

  Widget pill(Widget child, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    decoration: BoxDecoration(
      color: color ?? const Color(0xFFFFFBEA),
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24607843),
          offset: Offset(0, 3),
          blurRadius: 0,
        ),
      ],
    ),
    child: child,
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) {
      final s = c.account;
      // This Flutter version exposes iOS reduceMotion separately from disableAnimations.
      game.reduceMotion =
          MediaQuery.disableAnimationsOf(context) ||
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .reduceMotion;
      return Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 500;
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTapUp: (d) => game.tap(d.localPosition),
                      onScaleStart: (_) => game.startGesture(),
                      onScaleUpdate: (d) =>
                          game.gesture(d.scale, d.focalPointDelta),
                      onScaleEnd: (_) => saveSceneSafely(),
                      child: GameWidget(
                        key: ValueKey('${c.family}-${c.child}'),
                        game: game,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 8,
                    child: pill(
                      TextButton(
                        key: const Key('profiles'),
                        onPressed: () => guard(profiles),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/svg/mascot.svg',
                              width: 32,
                              height: 36,
                            ),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.demo ? '独立示例家庭' : '栗子小镇 · Pennywood',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF8D9476),
                                  ),
                                ),
                                Text(
                                  '${s.name}的小镇  ›',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 8,
                    child: Row(
                      children: [
                        pill(
                          TextButton(
                            key: const Key('wallet'),
                            onPressed: () => openPanel('journal'),
                            child: Text(
                              '零钱 ¥${Money.format(s.wallet)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          color: const Color(0xFFF6E6AC),
                        ),
                        const SizedBox(width: 8),
                        pill(
                          IconButton(
                            key: const Key('parent-entry'),
                            tooltip: '家长空间',
                            onPressed: () => openPanel('parent'),
                            icon: const Icon(Icons.family_restroom_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!compact)
                    Positioned(
                      left: 18,
                      top: 96,
                      width: 190,
                      child: pill(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('今天的故事', style: TextStyle(fontSize: 12)),
                            Text(
                              story(s),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton(
                              onPressed: () => game.visit('tasks'),
                              child: const Text('去委托小铺 →'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    right: 12,
                    top: compact ? 80 : 110,
                    child: Column(
                      children: [
                        IconButton.filledTonal(
                          tooltip: '放大',
                          onPressed: () {
                            setState(
                              () => c.scene.zoom = (c.scene.zoom + .15).clamp(
                                .75,
                                1.6,
                              ),
                            );
                            saveSceneSafely();
                          },
                          icon: const Icon(Icons.add),
                        ),
                        IconButton.filledTonal(
                          tooltip: '缩小',
                          onPressed: () {
                            setState(
                              () => c.scene.zoom = (c.scene.zoom - .15).clamp(
                                .75,
                                1.6,
                              ),
                            );
                            saveSceneSafely();
                          },
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton.filledTonal(
                          tooltip: '镜头复位',
                          onPressed: () {
                            setState(() {
                              c.scene.zoom = 1;
                              c.scene.panX = 0;
                              c.scene.panY = 0;
                            });
                            saveSceneSafely();
                          },
                          icon: const Icon(Icons.center_focus_strong),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: compact ? 62 : 90,
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() => c.scene.evening = !c.scene.evening);
                            saveSceneSafely();
                          },
                          child: Text(c.scene.evening ? '☾ 黄昏' : '☀ 午后'),
                        ),
                        IconButton(
                          tooltip: c.scene.sound ? '关闭音效' : '开启音效',
                          onPressed: () {
                            setState(() => c.scene.sound = !c.scene.sound);
                            if (c.scene.sound) {
                              SystemSound.play(SystemSoundType.click);
                            }
                            saveSceneSafely();
                          },
                          icon: Icon(
                            c.scene.sound ? Icons.volume_up : Icons.volume_off,
                          ),
                        ),
                        if (!compact)
                          Text(
                            '足迹 ${c.scene.visited.length}/4 · ${s.date}',
                            style: const TextStyle(fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: pill(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            nav(Icons.home_outlined, '小镇', () {
                              guard(() => game.stop());
                              setState(() {
                                c.scene.zoom = 1;
                                c.scene.panX = 0;
                                c.scene.panY = 0;
                              });
                              saveSceneSafely();
                            }),
                            nav(
                              Icons.account_balance_wallet_outlined,
                              '口袋',
                              () => openPanel('journal'),
                            ),
                            nav(
                              Icons.task_alt,
                              '委托',
                              () => game.visit('tasks'),
                              key: 'tasks-entry',
                            ),
                            nav(
                              Icons.star_border,
                              '愿望',
                              () => game.visit('wish'),
                            ),
                            nav(
                              Icons.menu_book_outlined,
                              '成长',
                              () => game.visit('growth'),
                            ),
                            nav(
                              Icons.logout,
                              '家庭',
                              () => guard(() async {
                                await game.stop();
                                c.lock();
                                if (context.mounted) Navigator.pop(context);
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (constraints.maxWidth < constraints.maxHeight)
                    const Positioned(
                      left: 12,
                      right: 12,
                      top: 78,
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Text('把窗口横向展开，小镇更宽敞；位置和表单会为你保留。'),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
  Widget nav(IconData icon, String text, VoidCallback tap, {String? key}) =>
      TextButton(
        key: key == null ? null : Key(key),
        onPressed: tap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 21),
            Text(text, style: const TextStyle(fontSize: 11)),
          ],
        ),
      );
  String story(ChildAccount s) {
    final t = s.tasks.where((t) => t.status != 'cancelled').firstOrNull;
    if (t == null) return '先和家长约好一份现实任务';
    return switch (t.status) {
      'available' => '一份努力，一个小小愿望',
      'accepted' => '在现实中完成，再回来告诉家长',
      'submitted' => '请家长检查你的努力',
      'confirmed' => '等待家长兑现报酬',
      _ => '劳动有了收获，想怎么安排？',
    };
  }
}
