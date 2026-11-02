// A named vertical wish-page scroll region owns its range/actions while child controls stay independent.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class NamedPageScroll extends StatelessWidget {
  const NamedPageScroll({
    super.key,
    required this.label,
    required this.child,
    this.controller,
    this.padding = EdgeInsets.zero,
  });
  final String label;
  final Widget child;
  final ScrollController? controller;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Scrollable(
    controller: controller,
    // Expose scroll actions on the named semantics node below; preserve content semantics and gestures.
    excludeFromSemantics: true,
    viewportBuilder: (context, offset) => _ScrollDescription(
      label: label,
      direction: Directionality.of(context),
      position: offset as ScrollPosition,
      child: Viewport(
        offset: offset,
        slivers: [
          SliverPadding(
            padding: padding,
            sliver: SliverToBoxAdapter(child: child),
          ),
        ],
      ),
    ),
  );
}

class _ScrollDescription extends SingleChildRenderObjectWidget {
  const _ScrollDescription({
    required this.label,
    required this.direction,
    required this.position,
    required super.child,
  });
  final String label;
  final TextDirection direction;
  final ScrollPosition position;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _DescriptionRender(label, direction, position);

  @override
  void updateRenderObject(
    BuildContext context,
    _DescriptionRender renderObject,
  ) {
    renderObject.update(label, direction, position);
  }
}

class _DescriptionRender extends RenderProxyBox {
  _DescriptionRender(this.label, this.direction, this.position) {
    position.addListener(markNeedsSemanticsUpdate);
  }
  String label;
  TextDirection direction;
  ScrollPosition position;

  void update(String label, TextDirection direction, ScrollPosition position) {
    if (this.position != position) {
      this.position.removeListener(markNeedsSemanticsUpdate);
      this.position = position;
      position.addListener(markNeedsSemanticsUpdate);
    }
    this.label = label;
    this.direction = direction;
    markNeedsSemanticsUpdate();
  }

  @override
  void performLayout() {
    super.performLayout();
    // Content/window height can change the scroll range without a pixels notification.
    markNeedsSemanticsUpdate();
  }

  void page(double direction) {
    final target =
        (position.pixels + direction * position.viewportDimension * .8).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    position.moveTo(target, duration: const Duration(milliseconds: 200));
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true
      ..label = label
      ..textDirection = direction;
    if (!position.haveDimensions) return;
    config
      ..hasImplicitScrolling = position.physics.allowImplicitScrolling
      ..scrollPosition = position.pixels
      ..scrollExtentMin = position.minScrollExtent
      ..scrollExtentMax = position.maxScrollExtent;
    if (position.pixels < position.maxScrollExtent) {
      config.onScrollUp = () => page(1);
    }
    if (position.pixels > position.minScrollExtent) {
      config.onScrollDown = () => page(-1);
    }
    if (position.maxScrollExtent > position.minScrollExtent) {
      config.onScrollToOffset = (target) => position.jumpTo(
        target.dy.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
  }

  @override
  void dispose() {
    position.removeListener(markNeedsSemanticsUpdate);
    super.dispose();
  }
}
