import 'package:flutter/widgets.dart';

/// One crumb in a [NibBreadcrumb] trail.
///
/// The last item in the list is treated as the **current** page (emphasised,
/// non-interactive). Any earlier item with a non-null [onTap] renders as a
/// focusable link.
@immutable
class NibBreadcrumbItem {
  const NibBreadcrumbItem({required this.label, this.icon, this.onTap});

  /// The crumb text.
  final String label;

  /// Optional leading icon.
  final Widget? icon;

  /// Tapped/activated callback. `null` (or being the current/last item) renders
  /// the crumb as plain, non-interactive text.
  final VoidCallback? onTap;
}

/// The visible crumb positions for a trail of [count] items, given whether it is
/// [collapsed]. `null` entries mark the ellipsis/overflow slot; ints are item
/// indices.
///
/// When collapsed, the first [before] and last [after] items are kept and the
/// middle is replaced by a single ellipsis. Never collapses a trail of
/// `count <= before + after`.
///
/// ```dart
/// breadcrumbVisibleIndices(count: 5, collapsed: true);  // [0, null, 4]
/// breadcrumbVisibleIndices(count: 5, collapsed: false); // [0, 1, 2, 3, 4]
/// ```
List<int?> breadcrumbVisibleIndices({
  required int count,
  required bool collapsed,
  int before = 1,
  int after = 1,
}) {
  if (count <= 0) return const [];
  if (!collapsed || count <= before + after) {
    return [for (var i = 0; i < count; i++) i];
  }
  return <int?>[
    for (var i = 0; i < before; i++) i,
    null,
    for (var i = count - after; i < count; i++) i,
  ];
}
