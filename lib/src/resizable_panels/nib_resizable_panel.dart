import 'package:flutter/widgets.dart';

/// One panel in a `NibResizablePanels` group.
///
/// [minSize]/[maxSize]/[initialSize] are fractions (`0.0`–`1.0`) of the
/// group's own main-axis extent, not pixels — this keeps the layout correct
/// across window/viewport resizes without reconciling absolute pixel bounds
/// against a shrinking or growing container.
@immutable
class NibResizablePanel {
  /// Creates a panel. If [initialSize] is omitted, this panel shares the
  /// fraction left over after every panel with an explicit [initialSize] is
  /// accounted for, split evenly among the other omitted panels.
  const NibResizablePanel({
    required this.child,
    this.minSize = 0.1,
    this.maxSize = 1.0,
    this.initialSize,
  }) : assert(minSize >= 0.0 && minSize <= 1.0, 'minSize must be within 0.0-1.0.'),
       assert(maxSize >= 0.0 && maxSize <= 1.0, 'maxSize must be within 0.0-1.0.'),
       assert(minSize <= maxSize, 'minSize must be <= maxSize.'),
       assert(
         initialSize == null || (initialSize >= 0.0 && initialSize <= 1.0),
         'initialSize must be within 0.0-1.0.',
       );

  /// The panel's content.
  final Widget child;

  /// The minimum fraction (of the group's main-axis extent) this panel can
  /// be resized to. Defaults to `0.1` (10%).
  final double minSize;

  /// The maximum fraction this panel can be resized to. Defaults to `1.0`
  /// (100%) — effectively unbounded, since the other panels' own minimums
  /// prevent any single panel from actually reaching it.
  final double maxSize;

  /// This panel's starting fraction of the group. `null` shares the
  /// remaining space evenly with every other panel that also omits it.
  final double? initialSize;
}
