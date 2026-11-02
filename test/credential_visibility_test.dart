import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/features/wish_home.dart';

void main() {
  testWidgets(
    'Leaving the foreground clears and conceals secrets while retaining ordinary input',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionForm(
              title: '输入保护',
              labels: const ['备注', '备份密码'],
              initial: const ['', ''],
              submitLabel: '确认',
              secretFields: const {1},
              onSubmit: (_) async {},
            ),
          ),
        ),
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '保留这份说明');
      await tester.enterText(fields.at(1), '仅供测试的备份密码');
      await tester.tap(find.byTooltip('显示输入'));
      await tester.pump();
      expect(tester.widget<TextField>(fields.at(1)).obscureText, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(tester.widget<TextField>(fields.at(1)).obscureText, isTrue);
      expect(tester.widget<TextField>(fields.at(1)).controller!.text, isEmpty);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      expect(tester.widget<TextField>(fields.at(0)).controller!.text, '保留这份说明');
      expect(tester.widget<TextField>(fields.at(1)).controller!.text, isEmpty);
      expect(tester.widget<TextField>(fields.at(1)).obscureText, isTrue);
      expect(find.byTooltip('显示输入'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
