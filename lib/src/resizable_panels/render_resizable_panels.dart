import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Fixed hit/paint width reserved for each handle slot between panels, in
/// logical pixels. Wider than the thin visual line `NibResizablePanelsHandle`
/// paints inside it, so the handle stays draggable without pixel-perfect
/// precision (the same touch-target concern already raised for Data Table).
const double kNibResizablePanelsHandleHitWidth = 12.0;

class _PanelsParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays out an interleaved `[panel, handle, panel, handle, ..., panel]`
/// child list along [direction]: each panel child gets a tight main-axis
/// extent of `sizes[i] * panelsMainExtent` (the group's main extent minus
/// every handle slot), each handle child gets a fixed
/// [kNibResizablePanelsHandleHitWidth]. Every child is tight to the incoming
/// constraints' cross extent.
///
/// This is a pure function of `(sizes, direction, constraints)` — it owns no
/// gesture/interaction state. `NibResizablePanelsHandle` children (built by
/// `NibResizablePanels`) own hover/drag/keyboard interaction themselves and
/// report changes back up via callbacks; this render object only answers
/// "given these fractions, where does everything go."
class NibResizablePanelsRenderObject extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PanelsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PanelsParentData> {
  NibResizablePanelsRenderObject({
    required this._sizes,
    required this._direction,
  });

  List<double> _sizes;
  List<double> get sizes => _sizes;
  set sizes(List<double> value) {
    if (listEquals(_sizes, value)) return;
    _sizes = value;
    markNeedsLayout();
  }

  Axis _direction;
  Axis get direction => _direction;
  set direction(Axis value) {
    if (_direction == value) return;
    _direction = value;
    markNeedsLayout();
  }

  int get _panelCount => (childCount + 1) ~/ 2;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PanelsParentData) {
      child.parentData = _PanelsParentData();
    }
  }

  @override
  void performLayout() {
    assert(
      constraints.maxWidth.isFinite && constraints.maxHeight.isFinite,
      'NibResizablePanels must be given bounded constraints in both axes '
      '(e.g. wrap it in a SizedBox or Expanded within a bounded parent).',
    );

    final horizontal = _direction == Axis.horizontal;
    final totalMain = horizontal ? constraints.maxWidth : constraints.maxHeight;
    final crossExtent = horizontal
        ? constraints.maxHeight
        : constraints.maxWidth;
    final handleCount = _panelCount - 1;
    final panelsMain =
        totalMain - (handleCount * kNibResizablePanelsHandleHitWidth);

    var child = firstChild;
    var index = 0;
    var panelIndex = 0;
    var cursor = 0.0;
    var panelMainSum = 0.0;

    while (child != null) {
      final parentData = child.parentData! as _PanelsParentData;
      final isHandle = index.isOdd;

      final double mainExtent;
      if (isHandle) {
        mainExtent = kNibResizablePanelsHandleHitWidth;
      } else {
        final isLastPanel = panelIndex == _panelCount - 1;
        mainExtent = isLastPanel
            ? panelsMain - panelMainSum
            : panelsMain * _sizes[panelIndex];
        panelMainSum += mainExtent;
        panelIndex++;
      }

      final childConstraints = horizontal
          ? BoxConstraints.tightFor(width: mainExtent, height: crossExtent)
          : BoxConstraints.tightFor(width: crossExtent, height: mainExtent);
      child.layout(childConstraints);
      parentData.offset = horizontal ? Offset(cursor, 0) : Offset(0, cursor);
      cursor += mainExtent;

      index++;
      child = parentData.nextSibling;
    }

    size = constraints.constrain(
      horizontal ? Size(totalMain, crossExtent) : Size(crossExtent, totalMain),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

/// Widget wrapper for [NibResizablePanelsRenderObject]. [children] must
/// alternate panel/handle/panel/.../panel — `2 * sizes.length - 1` widgets
/// total. Not part of the public API; `NibResizablePanels` is the
/// consumer-facing widget.
class NibResizablePanelsLayout extends MultiChildRenderObjectWidget {
  const NibResizablePanelsLayout({
    super.key,
    required this.direction,
    required this.sizes,
    required super.children,
  });

  final Axis direction;
  final List<double> sizes;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return NibResizablePanelsRenderObject(sizes: sizes, direction: direction);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as NibResizablePanelsRenderObject)
      ..sizes = sizes
      ..direction = direction;
  }
}
