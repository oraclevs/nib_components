/// Which direction (if any) a `NibDataTable` column is currently sorted by.
enum NibSortDirection { none, ascending, descending }

/// The current sort state of a `NibDataTable`: which column index, and
/// which direction. `columnIndex: null` means unsorted.
class NibDataTableSort {
  const NibDataTableSort({
    this.columnIndex,
    this.direction = NibSortDirection.none,
  });

  final int? columnIndex;
  final NibSortDirection direction;

  NibDataTableSort copyWith({int? columnIndex, NibSortDirection? direction}) {
    return NibDataTableSort(
      columnIndex: columnIndex ?? this.columnIndex,
      direction: direction ?? this.direction,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NibDataTableSort &&
        other.columnIndex == columnIndex &&
        other.direction == direction;
  }

  @override
  int get hashCode => Object.hash(columnIndex, direction);
}

/// How a `NibDataTable` handles row selection.
enum NibDataTableSelectionMode {
  /// No selection UI or state.
  none,

  /// Tapping a row selects it, replacing any prior selection. No checkbox
  /// column.
  single,

  /// A leading checkbox column, plus a select-all checkbox in the header.
  multi,
}
