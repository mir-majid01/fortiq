import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Widens the tappable area of a small control without changing its size or
/// position: the visual stays exactly as designed while the touch target
/// grows to the 44×44 minimum. A tap anywhere in the expanded area is
/// delivered to the control as if it landed on its edge.
class ExpandedTapArea extends SingleChildRenderObjectWidget {
  const ExpandedTapArea({
    super.key,
    this.padding = EdgeInsets.zero,
    required super.child,
  });

  /// How far the hit area extends beyond the child on each side.
  final EdgeInsets padding;

  /// Padding that grows a [size]×[size] control to a 44×44 target.
  factory ExpandedTapArea.toTarget({
    Key? key,
    required double size,
    required Widget child,
  }) {
    final pad = ((44 - size) / 2).clamp(0.0, 44.0);
    return ExpandedTapArea(
      key: key,
      padding: EdgeInsets.all(pad),
      child: child,
    );
  }

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderExpandedTapArea(padding);

  @override
  void updateRenderObject(
      BuildContext context, _RenderExpandedTapArea renderObject) {
    renderObject.padding = padding;
  }
}

class _RenderExpandedTapArea extends RenderProxyBox {
  _RenderExpandedTapArea(this._padding);

  EdgeInsets _padding;

  set padding(EdgeInsets value) {
    if (value == _padding) return;
    _padding = value;
    // The hit region changed; nothing to repaint, but mark dirty so parents
    // that cache hit-test results are re-evaluated.
    markNeedsPaint();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final outsideVertically =
        position.dy < -_padding.top || position.dy >= size.height + _padding.bottom;
    final outsideHorizontally =
        position.dx < -_padding.left || position.dx >= size.width + _padding.right;
    if (outsideVertically || outsideHorizontally) return false;
    // Pull the point just inside the child; its right and bottom edges are
    // outside the child's own hit-test bounds.
    final right = size.width > 0 ? size.width - 0.01 : 0.0;
    final bottom = size.height > 0 ? size.height - 0.01 : 0.0;
    final clamped = Offset(
      position.dx.clamp(0.0, right),
      position.dy.clamp(0.0, bottom),
    );
    return super.hitTest(result, position: clamped);
  }
}
