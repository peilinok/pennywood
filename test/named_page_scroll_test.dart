import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/app/named_page_scroll.dart';

void main() {
  testWidgets(
    'Named scroll regions retain buttons, range, semantic paging, and dragging',
    (tester) async {
      final handle = tester.ensureSemantics();
      final controller = ScrollController();
      var taps = 0;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NamedPageScroll(
                label: '我的心愿内容',
                controller: controller,
                child: Column(
                  children: [
                    const Text('我的心愿'),
                    FilledButton(
                      onPressed: () => taps++,
                      child: const Text('管理心愿'),
                    ),
                    const SizedBox(height: 1200),
                    FilledButton(
                      onPressed: () => taps++,
                      child: const Text('底部按钮'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final nodes = <SemanticsNode>[];
        void collect(SemanticsNode node) {
          nodes.add(node);
          node.visitChildren((child) {
            collect(child);
            return true;
          });
        }

        collect(
          tester
              .binding
              .renderViews
              .single
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!,
        );
        final region = nodes.singleWhere(
          (node) => node.getSemanticsData().hasAction(SemanticsAction.scrollUp),
        );
        expect(region.label, '我的心愿内容');
        final data = region.getSemanticsData();
        expect(data.scrollPosition, 0);
        expect(data.scrollExtentMax, greaterThan(0));
        expect(data.hasAction(SemanticsAction.scrollUp), isTrue);
        final button = tester.getSemantics(
          find.widgetWithText(FilledButton, '管理心愿'),
        );
        expect(button.id, isNot(region.id));
        tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
          button.id,
          SemanticsAction.tap,
        );
        await tester.pump();
        expect(taps, 1);
        tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
          region.id,
          SemanticsAction.scrollUp,
        );
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(0));
        final old = controller.offset;
        await tester.drag(find.byType(NamedPageScroll), const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(old));
        tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
          region.id,
          SemanticsAction.scrollToOffset,
          Float64List.fromList([0, controller.position.maxScrollExtent]),
        );
        await tester.pumpAndSettle();
        expect(controller.offset, controller.position.maxScrollExtent);
        expect(
          find.widgetWithText(FilledButton, '底部按钮').hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.text('底部按钮'));
        expect(taps, 2);
        expect(
          region.getSemanticsData().hasAction(SemanticsAction.scrollDown),
          isTrue,
        );
        controller.jumpTo(0);
        await tester.pumpAndSettle();
        // After autofocus or test positioning, the bottom control must be hittable on the next frame.
        await tester.ensureVisible(find.text('底部按钮'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(FilledButton, '底部按钮').hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.text('底部按钮'));
        expect(taps, 3);
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        handle.dispose();
      }
    },
  );
}
