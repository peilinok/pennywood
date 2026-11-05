import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app/paper_theme.dart';
import '../domain/market.dart';
import '../domain/money.dart';

// A self-contained, read-only lesson: animation never touches the clock or family ledger.
class InvestmentLab extends StatefulWidget {
  const InvestmentLab({
    this.projectionPrincipal = 10000,
    this.projectionRateBps = 800,
    this.weeklyPlan = 0,
    super.key,
  });
  final int projectionPrincipal, projectionRateBps, weeklyPlan;
  @override
  State<InvestmentLab> createState() => _InvestmentLabState();
}

class _InvestmentLabState extends State<InvestmentLab>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController playback;
  late List<List<int>> marketSeries;
  String topic = 'market';
  int step = 60, scenario = 0, rate = 8;
  bool distributed = false, reinvest = false, contribute = false;
  late final principal = TextEditingController(
    text: Money.format(widget.projectionPrincipal),
  );
  late final weekly = TextEditingController(
    text: Money.format(widget.weeklyPlan),
  );
  int get limit => topic == 'market' ? 60 : 20;
  bool get reduced =>
      MediaQuery.of(context).disableAnimations ||
      MediaQuery.of(context).accessibleNavigation ||
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .reduceMotion;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    marketSeries = createMarketSeries();
    playback =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..addListener(() {
            final next = (playback.value * limit).round();
            if (next != step) setState(() => step = next);
          })
          ..addStatusListener((_) {
            if (mounted) setState(() {});
          });
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (reduced) playback.stop();
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduced) playback.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) playback.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    playback.dispose();
    principal.dispose();
    weekly.dispose();
    super.dispose();
  }

  void move(int next) {
    playback.stop();
    setState(() => step = next.clamp(0, limit));
  }

  void play() {
    if (reduced) {
      move(limit);
      return;
    }
    if (playback.isAnimating) {
      playback.stop();
      setState(() {});
      return;
    }
    playback.forward(from: step == limit ? 0 : step / limit);
    setState(() {});
  }

  Widget card(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: PaperColors.of(context).soft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
  Widget title(String text) => Text(
    text,
    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
  );
  Widget journeyControls(String unit) => Column(
    children: [
      Slider(
        key: const Key('lesson-time'),
        label: '$step $unit',
        value: step.toDouble(),
        min: 0,
        max: limit.toDouble(),
        divisions: limit,
        semanticFormatterCallback: (v) => '${v.round()} $unit',
        onChanged: (v) => move(v.round()),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            tooltip: '向前看一$unit',
            onPressed: step == 0 ? null : () => move(step - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$step $unit', key: const Key('lesson-step')),
          IconButton(
            tooltip: '再看一$unit',
            onPressed: step == limit ? null : () => move(step + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
          FilledButton.tonalIcon(
            key: const Key('lesson-play'),
            onPressed: play,
            icon: Icon(playback.isAnimating ? Icons.pause : Icons.play_arrow),
            label: Text(
              reduced
                  ? '看完整旅程'
                  : playback.isAnimating
                  ? '暂停'
                  : '播放成长旅程',
            ),
          ),
        ],
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final p = PaperColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: SvgPicture.asset(
                'assets/svg/mascot.svg',
                width: 52,
                height: 64,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title('阿栗的财富实验室'), const Text('让时间走一走，看看小钱会发生什么。')],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in [
              ('market', '起伏的旅程'),
              ('compound', '收益生小收益'),
              ('dividend', '分红去哪儿'),
              ('projection', '我的假设'),
            ])
              ChoiceChip(
                key: Key('lesson-${item.$1}'),
                label: Text(item.$2),
                selected: topic == item.$1,
                onSelected: (_) {
                  playback.stop();
                  setState(() {
                    topic = item.$1;
                    step = limit;
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (topic == 'market') ...marketLesson(p),
        if (topic == 'compound') ...compoundLesson(p),
        if (topic == 'dividend') ...dividendLesson(p),
        if (topic == 'projection') ...projectionLesson(),
        const Text('实验室只做演示，不动你的零钱。教学行情不是真实基金或纳指行情，曲线上涨也不保证未来赚钱。'),
      ],
    );
  }

  List<List<int>> createMarketSeries() {
    final low = TeachingMarket.curve(
      'lowVol',
      '2026-01-01',
      1800,
      scenario: scenario,
      bounded: false,
    );
    final high = TeachingMarket.curve(
      'growth',
      '2026-01-01',
      1800,
      scenario: scenario,
      bounded: false,
    );
    final a = [for (var i = 0; i <= 60; i++) low[i * 30]];
    final b = [for (var i = 0; i <= 60; i++) high[i * 30]];
    return [a, b];
  }

  List<Widget> marketLesson(PaperColors p) {
    final a = marketSeries[0], b = marketSeries[1];
    final previous = step == 0 ? 0 : step - 1;
    final down = b[step] < b[previous];
    return [
      card([
        title('两袋各 100 元，会走出怎样的路？'),
        const Text('实线是红利低波，圆点线是成长高波；长远有向上倾向，路上会回头。'),
        const SizedBox(height: 12),
        LearningChart(
          series: [a, b],
          step: step,
          labels: const ['红利低波', '成长高波'],
          unit: '月',
        ),
        Text(
          '第 $step 月 · 低波 ¥${Money.format(a[step])} · 高波 ¥${Money.format(b[step])}',
          key: const Key('lesson-market-value'),
        ),
        Text(
          down ? '遇到回调了！高波这一个月变少，原来的本金也可能亏。' : '看看弯弯的路：涨得快，也可能跌得深。试试往前或往后看一个月。',
          style: TextStyle(color: down ? p.danger : p.green),
        ),
        journeyControls('月'),
        TextButton.icon(
          key: const Key('lesson-new-path'),
          onPressed: () {
            playback.stop();
            setState(() {
              scenario++;
              marketSeries = createMarketSeries();
              step = 60;
            });
          },
          icon: const Icon(Icons.shuffle),
          label: const Text('换一段随机旅程'),
        ),
        const Text('这里演示 5 年趋势，不套用单笔上限。真实零钱计划每 30 天结算并设亏损/收益边界，存入前要和家长一起确认。'),
      ]),
    ];
  }

  List<Widget> compoundLesson(PaperColors p) {
    final compound = <int>[10000], simple = <int>[10000];
    for (var i = 1; i <= 20; i++) {
      compound.add(
        compound.last + Money.interest(compound.last, rate * 100, 365),
      );
      simple.add(10000 + Money.interest(10000, rate * 100, 365) * i);
    }
    return [
      card([
        title('留下的小果实，也能长出新果实'),
        const Text('同样从 100 元出发：实线留下收益，圆点线每年把收益取出。'),
        ExcludeSemantics(
          child: AnimatedScale(
            scale: 0.65 + step / 60,
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 240),
            child: SvgPicture.asset('assets/svg/tree-annual.svg', height: 100),
          ),
        ),
        LearningChart(
          series: [compound, simple],
          step: step,
          labels: const ['收益再投入', '取出收益（含已取出）'],
          unit: '年',
        ),
        Text(
          '第 $step 年 · 再投入 ¥${Money.format(compound[step])}\n取出方案合计 ¥${Money.format(simple[step])}\n小收益又长出了 ¥${Money.format(compound[step] - simple[step])}',
          key: const Key('lesson-compound-value'),
        ),
        journeyControls('年'),
        Text('假设年化 $rate%（演示参数）'),
        Slider(
          key: const Key('lesson-rate'),
          value: rate.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          label: '$rate%',
          onChanged: (v) {
            playback.stop();
            setState(() => rate = v.round());
          },
        ),
        const Text('两条路都拥有收益。差别是留下的收益，会参加下一年；越久差距越明显。这不是家长已承诺的收益。'),
      ]),
    ];
  }

  List<Widget> projectionLesson() {
    int base, addition;
    try {
      base = Money.parse(principal.text);
      addition = contribute ? Money.parse(weekly.text) * 52 : 0;
    } catch (_) {
      return [projectionInputs(), const Text('请填写有效假设金额；这里不会修改真实账户。')];
    }
    var reinvested = base, simplePrincipal = base, withdrawn = 0;
    final a = [base], b = [base];
    for (var i = 0; i < 20; i++) {
      reinvested +=
          Money.interest(reinvested, widget.projectionRateBps, 365) + addition;
      withdrawn += Money.interest(
        simplePrincipal,
        widget.projectionRateBps,
        365,
      );
      simplePrincipal += addition;
      a.add(reinvested);
      b.add(simplePrincipal + withdrawn);
    }
    return [
      projectionInputs(),
      LearningChart(
        series: [a, b],
        step: step,
        labels: const ['收益再投入', '取出收益（含已取出）'],
        unit: '年',
      ),
      Text(
        '预计收益再投入：¥${Money.format(a[step])}\n预计取出收益（包括已取出部分）：¥${Money.format(b[step])}\n预计差额：¥${Money.format(a[step] - b[step])}',
        key: const Key('projection-value'),
      ),
      journeyControls('年'),
      const Text(
        '仅为假设：默认以扣除计划待还后的积累为起点，按当前年化每年结算；劳动计划按每年末投入 52 周。金额与计划只在本课堂演示，未来收入、利率、预算可能改变，投影不会入账，也不是承诺。',
      ),
    ];
  }

  Widget projectionInputs() => card([
    title('如果把收益也留下？'),
    Text('假设年化 ${(widget.projectionRateBps / 100).toStringAsFixed(2)}%'),
    TextField(
      key: const Key('projection-principal'),
      controller: principal,
      decoration: const InputDecoration(labelText: '假设起点（元）'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
    ),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('加入每周计划劳动留存'),
      value: contribute,
      onChanged: (v) => setState(() => contribute = v!),
    ),
    if (contribute)
      TextField(
        key: const Key('projection-weekly'),
        controller: weekly,
        decoration: const InputDecoration(labelText: '假设每周留存（元）'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
      ),
  ]);

  List<Widget> dividendLesson(PaperColors p) => [
    card([
      title('分红像分果实，不会凭空多一袋钱'),
      const Text('起点：100 份，每份 1.03 元，一共 103 元。'),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('果实放口袋'),
            selected: !reinvest,
            onSelected: (_) => setState(() => reinvest = false),
          ),
          ChoiceChip(
            label: const Text('果实种回去'),
            selected: reinvest,
            onSelected: (_) => setState(() => reinvest = true),
          ),
        ],
      ),
      const SizedBox(height: 16),
      AnimatedSwitcher(
        duration: reduced ? Duration.zero : const Duration(milliseconds: 450),
        child: Column(
          key: ValueKey('$distributed-$reinvest'),
          children: [
            ExcludeSemantics(
              child: Icon(
                distributed && !reinvest
                    ? Icons.account_balance_wallet_outlined
                    : Icons.park_outlined,
                size: 72,
                color: p.green,
              ),
            ),
            Text(
              !distributed
                  ? '树上的份额：103 元'
                  : reinvest
                  ? '种回去：103 份 × 1 元'
                  : '树上 100 元 ＋ 口袋 3 元',
              style: const TextStyle(fontSize: 20),
            ),
            const Text('总额一直是 103 元'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.tonal(
        key: const Key('lesson-distribute'),
        onPressed: () => setState(() => distributed = !distributed),
        child: Text(distributed ? '回到分红前' : '摘下这次分红'),
      ),
      Text(
        distributed
            ? '分出每份 0.03 元后，每份净值变成 1 元。放口袋可使用；种回去的份额会参与下一次涨跌。'
            : '点一下，看看 3 元果实会去哪里。',
      ),
    ]),
  ];
}

class LearningChart extends StatelessWidget {
  const LearningChart({
    required this.series,
    required this.step,
    required this.labels,
    required this.unit,
    super.key,
  });
  final List<List<int>> series;
  final int step;
  final List<String> labels;
  final String unit;
  @override
  Widget build(BuildContext context) {
    final p = PaperColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          image: true,
          label:
              '收益曲线，第 $step $unit。${[for (var i = 0; i < series.length; i++) '${labels[i]} ${Money.format(series[i][step])} 元'].join('，')}',
          child: ExcludeSemantics(
            child: SizedBox(
              height: 190,
              child: RepaintBoundary(
                child: CustomPaint(painter: _CurvePainter(series, step, p)),
              ),
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text('起点 · ¥${Money.format(series.first.first)}'),
            Text('第 $step $unit'),
          ],
        ),
        Wrap(
          spacing: 12,
          children: [
            for (var i = 0; i < labels.length; i++)
              Text(
                '${i == 0 ? '━' : '•••'} ${labels[i]}',
                style: TextStyle(color: i == 0 ? p.green : p.brand),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter(this.series, this.step, this.colors);
  final List<List<int>> series;
  final int step;
  final PaperColors colors;
  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = math.max(
      1.0,
      series.expand((s) => s).reduce(math.max) * 1.08,
    );
    final minValue = math.min(
      series.expand((s) => s).reduce(math.min) * 0.9,
      9000.0,
    );
    final height = size.height - 24;
    Offset point(int i, int value) => Offset(
      12 + (size.width - 24) * i / (series.first.length - 1),
      12 + height * (1 - (value - minValue) / (maxValue - minValue)),
    );
    final grid = Paint()
      ..color = colors.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = 12 + height * i / 4;
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), grid);
    }
    final baseline = point(0, series.first.first).dy;
    canvas.drawLine(
      Offset(12, baseline),
      Offset(size.width - 12, baseline),
      Paint()
        ..color = colors.control
        ..strokeWidth = 1,
    );
    for (var j = 0; j < series.length; j++) {
      final paint = Paint()
        ..color = j == 0 ? colors.green : colors.brand
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(point(0, series[j][0]).dx, point(0, series[j][0]).dy);
      for (var i = 1; i <= step; i++) {
        final a = point(i - 1, series[j][i - 1]), b = point(i, series[j][i]);
        if (j == 0) {
          path.lineTo(b.dx, b.dy);
        } else {
          final count = math.max(1, (b - a).distance ~/ 6);
          for (var k = 0; k < count; k++) {
            canvas.drawCircle(
              Offset.lerp(a, b, k / count)!,
              1.8,
              Paint()..color = paint.color,
            );
          }
        }
      }
      if (j == 0) canvas.drawPath(path, paint);
      final end = point(step, series[j][step]);
      canvas.drawCircle(end, 6, Paint()..color = paint.color);
      canvas.drawCircle(end, 2, Paint()..color = colors.surface);
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) =>
      old.series != series ||
      old.step != step ||
      old.colors.dark != colors.dark;
}
