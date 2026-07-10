import 'package:flutter/widgets.dart';

/// Builds the cell widget for [row] in this column.
typedef NibCellBuilder<T> = Widget Function(BuildContext context, T row);

/// Returns the value used to sort rows by this column. Must be
/// [Comparable] with itself (e.g. `String`, `num`, `DateTime`).
typedef NibSortValueGetter<T> = Comparable<Object?> Function(T row);

/// One column definition for a `NibDataTable<T>`.
class NibDataColumn<T> {
  const NibDataColumn({
    required this.label,
    required this.cellBuilder,
    this.sortValue,
    this.width,
    this.minWidth = 96,
  }) : assert(width == null || width > 0, 'width must be positive'),
       assert(minWidth > 0, 'minWidth must be positive');

  /// The header label.
  final String label;

  /// Builds each row's cell content for this column.
  final NibCellBuilder<T> cellBuilder;

  /// If set, this column's header can be tapped to sort by it, using this
  /// as the comparison key. If `null`, this column is not sortable.
  final NibSortValueGetter<T>? sortValue;

  /// Fixed column width. If `null`, the column flexes to fill remaining
  /// space (subject to [minWidth]).
  final double? width;

  /// Minimum width when this column is flexible (i.e. [width] is `null`).
  /// Also weights this column's share of flexible space relative to other flexible
  /// columns — a column with a larger [minWidth] gets proportionally more flex space.
  /// Only a true floor once the viewport is too narrow to fit every column's
  /// [minWidth] — [NibDataTable] then switches to horizontal scrolling instead of
  /// compressing columns below it.
  final double minWidth;

  /// Whether tapping this column's header cycles its sort direction.
  bool get sortable => sortValue != null;
}
