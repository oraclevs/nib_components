import 'package:flutter/widgets.dart';
import 'package:nib_motion/nib_motion.dart' show NibTransition;

import '../theme/nib_theme.dart';

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
  bool _hovered = false;

  void _handleDragUpdate(double primaryDelta) {
    if (widget.groupMainExtent <= 0) return;
    widget.onDeltaFraction(primaryDelta / widget.groupMainExtent);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final horizontal = widget.direction == Axis.horizontal;
    final color = _hovered ? theme.ring : theme.border;

    final line = SizedBox(
      width: horizontal ? widget.handleThickness : double.infinity,
      height: horizontal ? double.infinity : widget.handleThickness,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: horizontal ? (DragUpdateDetails d) => _handleDragUpdate(d.delta.dx) : null,
        onHorizontalDragEnd: horizontal ? (_) => widget.onDragEnd() : null,
        onVerticalDragUpdate: horizontal ? null : (DragUpdateDetails d) => _handleDragUpdate(d.delta.dy),
        onVerticalDragEnd: horizontal ? null : (_) => widget.onDragEnd(),
        onDoubleTap: widget.onReset,
        child: Center(child: ColoredBox(color: color, child: line)),
      ),
    );
  }
}
