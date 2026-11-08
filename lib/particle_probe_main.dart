import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/paper_theme.dart';

void main() => runApp(const ParticleProbeApp());

class ParticleProbeApp extends StatelessWidget {
  const ParticleProbeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: paperTheme(Brightness.light),
    home: const _ProbeEntry(),
  );
}

class _ProbeEntry extends StatefulWidget {
  const _ProbeEntry();

  @override
  State<_ProbeEntry> createState() => _ProbeEntryState();
}

class _ProbeEntryState extends State<_ProbeEntry> {
  String? error;
  bool opening = false;

  Future<void> open(String method) async {
    setState(() {
      opening = true;
      error = null;
    });
    try {
      await const MethodChannel(
        'pennywood/particle-probe',
      ).invokeMethod(method);
    } on PlatformException {
      if (mounted) setState(() => error = '无法打开验证页面，请重试。');
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('栗子小镇 · 配对验证')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '验证粒子配对图',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                const Text('先验证粒子图识别，再验证扫码连接与免扫码重连。\n仅使用独立测试配对和测试消息，尚未接入家庭账本。'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: opening ? null : () => open('open'),
                  child: Text(opening ? '正在打开…' : '开始拍照验证'),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: opening ? null : () => open('openNearby'),
                  child: const Text('开始双机连接验证'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(error!, semanticsLabel: error),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
