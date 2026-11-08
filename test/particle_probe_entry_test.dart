import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/particle_probe_main.dart';

void main() {
  const channel = MethodChannel('pennywood/particle-probe');
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Probe entry opens only the user-selected native test', (
    tester,
  ) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
    await tester.pumpWidget(const ParticleProbeApp());
    expect(calls, isEmpty);
    expect(find.textContaining('尚未接入家庭账本'), findsOneWidget);
    await tester.tap(find.text('开始拍照验证'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始双机连接验证'));
    await tester.pumpAndSettle();
    expect(calls, ['open', 'openNearby']);
  });

  testWidgets(
    'Failed native presentation unlocks retry without claiming success',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls++;
        await pending.future;
        throw PlatformException(code: 'busy');
      });
      await tester.pumpWidget(const ParticleProbeApp());
      await tester.tap(find.text('开始双机连接验证'));
      await tester.pump();
      for (final button in tester.widgetList<FilledButton>(
        find.byType(FilledButton),
      )) {
        expect(button.onPressed, isNull);
      }
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('无法打开验证页面，请重试。'), findsOneWidget);
      expect(calls, 1);
      for (final button in tester.widgetList<FilledButton>(
        find.byType(FilledButton),
      )) {
        expect(button.onPressed, isNotNull);
      }
    },
  );
}
