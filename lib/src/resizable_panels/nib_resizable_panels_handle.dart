import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:nib_motion/nib_motion.dart' show NibAnim, NibMotion, NibTransition;

import '../theme/nib_theme.dart';

/// The fraction (of the group's main-axis extent) a keyboard arrow-key
/// nudge moves a handle by.
const double kNibResizablePanelsKeyboardStep = 0.02;

/// The divider between two adjacent panels in a `NibResizablePanels` group.
/// Built and positioned by `NibResizablePanels`/`NibResizablePanelsLayout` —
/// not part of the public API.
///
/// This task only wires up static appearance (theme-colored line, sized to
/// [handleThickness]). Hover, drag, keyboard, and `animated` support are
/// added on top of this same widget in later tasks.
class NibResizablePanelsHandle extends StatefulWidget {
  const NibResizablePanelsHandle({
    super.key,
    required this.direction,
    required this.groupMainExtent,
    required this.handleThickness,
    required this.sizeFraction,
    required this.animated,
    required this.transition,
    required this.onDeltaFraction,
    required this.onDragEnd,
    required this.onReset,
  });

  /// The group's layout direction. Determines whether this handle paints a
  /// vertical line (horizontal group) or a horizontal line (vertical group).
  final Axis direction;

  /// The group's current main-axis extent in logical pixels — used by later
  /// tasks to convert a drag's pixel delta into a size-fraction delta.
  final double groupMainExtent;

  /// The visual thickness of the painted line, in logical pixels. The
  /// handle's hit/paint slot itself is always [kNibResizablePanelsHandleHitWidth]-wide;
  /// this is only the visible line inside it.
  final double handleThickness;

  /// The current size fraction of the panel immediately before this handle —
  /// used by later tasks for the handle's accessibility value.
  final double sizeFraction;

  /// Whether hover/active color changes animate via `NibMotion`.
  final bool animated;

  /// The transition used for the animated hover/active color change, when
  /// [animated] is `true`. `null` falls back to a short default fade.
  final NibTransition? transition;

  /// Called with a size-fraction delta while this handle is being
  /// dragged/keyboard-nudged. Wired up in Task 5/6.
  final ValueChanged<double> onDeltaFraction;

  /// Called once a drag/keyboard-nudge interaction ends. Wired up in Task
  /// 5/6.
  final VoidCallback onDragEnd;

  /// Called on double-click/tap to reset this handle's adjacent pair to
  /// their initial sizes. Wired up in Task 5.
  final VoidCallback onReset;

  @override
  State<NibResizablePanelsHandle> createState() => _NibResizablePanelsHandleState();
}

class _NibResizablePanelsHandleState extends State<NibResizablePanelsHandle> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'NibResizablePanelsHandle');
  bool _hovered = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleDragUpdate(double primaryDelta) {
    if (widget.groupMainExtent <= 0) return;
    widget.onDeltaFraction(primaryDelta / widget.groupMainExtent);
  }

  void _nudge(double delta) {
    widget.onDeltaFraction(delta);
    widget.onDragEnd();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final horizontal = widget.direction == Axis.horizontal;
    final key = event.logicalKey;

    double? delta;
    if (key == LogicalKeyboardKey.home) {
      delta = -1.0;
    } else if (key == LogicalKeyboardKey.end) {
      delta = 1.0;
    } else if (horizontal && key == LogicalKeyboardKey.arrowLeft) {
      delta = -kNibResizablePanelsKeyboardStep;
    } else if (horizontal && key == LogicalKeyboardKey.arrowRight) {
      delta = kNibResizablePanelsKeyboardStep;
    } else if (!horizontal && key == LogicalKeyboardKey.arrowUp) {
      delta = -kNibResizablePanelsKeyboardStep;
    } else if (!horizontal && key == LogicalKeyboardKey.arrowDown) {
      delta = kNibResizablePanelsKeyboardStep;
    }

    if (delta == null) return KeyEventResult.ignored;
    _nudge(delta);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final horizontal = widget.direction == Axis.horizontal;
    final color = _hovered ? theme.ring : theme.border;
    final percent = (widget.sizeFraction * 100).round();

    final baseLine = SizedBox(
      width: horizontal ? widget.handleThickness : double.infinity,
      height: horizontal ? double.infinity : widget.handleThickness,
    );

    final line = widget.animated
        ? NibMotion(
            animate: NibAnim(color: color),
            transition: widget.transition ?? const NibTransition(duration: Duration(milliseconds: 120)),
            child: baseLine,
          )
        : ColoredBox(color: color, child: baseLine);

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Semantics(
        label: 'Resize handle',
        value: '$percent%',
        increasedValue: '${((widget.sizeFraction + kNibResizablePanelsKeyboardStep) * 100).round()}%',
        decreasedValue: '${((widget.sizeFraction - kNibResizablePanelsKeyboardStep) * 100).round()}%',
        onIncrease: () => _nudge(kNibResizablePanelsKeyboardStep),
        onDecrease: () => _nudge(-kNibResizablePanelsKeyboardStep),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Listener(
            // A raw pointer listener, not a gesture recognizer: fires on
            // every pointer down unconditionally, regardless of how the
            // gesture arena below ends up resolving (tap vs double-tap vs
            // drag) — `GestureDetector.onTapDown` does not reliably fire
            // when `onDoubleTap` and drag callbacks are registered on the
            // same detector, since the double-tap recognizer holds the
            // arena open past the point a plain tap would normally resolve.
            onPointerDown: (_) => _focusNode.requestFocus(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: horizontal ? (DragUpdateDetails d) => _handleDragUpdate(d.delta.dx) : null,
              onHorizontalDragEnd: horizontal ? (_) => widget.onDragEnd() : null,
              onVerticalDragUpdate: horizontal ? null : (DragUpdateDetails d) => _handleDragUpdate(d.delta.dy),
              onVerticalDragEnd: horizontal ? null : (_) => widget.onDragEnd(),
              onDoubleTap: widget.onReset,
              child: Center(child: line),
            ),
          ),
        ),
      ),
    );
  }
}
