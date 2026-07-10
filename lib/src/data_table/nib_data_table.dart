import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import '../theme/nib_theme.dart';
import 'nib_data_column.dart';
import 'nib_data_table_controller.dart';
import 'nib_data_table_types.dart';

/// A native, virtualized, sortable, selectable data table.
///
/// Simplest usage needs only [columns] and [rows]:
///
/// ```dart
/// NibDataTable<Person>(
///   columns: [
///     NibDataColumn(label: 'Name', cellBuilder: (context, p) => Text(p.name)),
///   ],
///   rows: people,
/// )
/// ```
class NibDataTable<T> extends StatefulWidget {
  const NibDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.rowKey,
    this.selectionMode = NibDataTableSelectionMode.none,
    this.onSelectionChanged,
    this.onSort,
    this.onRowTap,
    this.loading = false,
    this.emptyState,
    this.rowHeight = 48,
    this.headerHeight = 44,
    this.stickyHeader = true,
    this.controller,
    this.animated = false,
    this.transition,
    this.semanticLabel,
  });

  /// The column definitions, in display order.
  final List<NibDataColumn<T>> columns;

  /// The rows to display. Sorted internally unless [onSort] is provided
  /// (in which case the caller is expected to already provide `rows` in
  /// the requested order — e.g. for server-side sorting).
  final List<T> rows;

  /// Produces a stable [Key] for a row, used to key its rendered widget
  /// (important when [animated] is `true`). Defaults to `ValueKey(row)`,
  /// which requires `T` to have stable `==`/`hashCode` (or stable
  /// identity) across rebuilds.
  final Key Function(T row)? rowKey;

  /// Whether/how rows can be selected.
  final NibDataTableSelectionMode selectionMode;

  /// Called whenever the selection changes (any [selectionMode]).
  final ValueChanged<Set<T>>? onSelectionChanged;

  /// Called when the user changes sort by tapping a sortable column
  /// header. If `null`, `NibDataTable` sorts [rows] itself using that
  /// column's `NibDataColumn.sortValue`. If set, the caller owns
  /// re-ordering `rows` (e.g. server-side); `NibDataTable` still tracks
  /// and displays the sort indicator.
  final void Function(int columnIndex, NibSortDirection direction)? onSort;

  /// Called when a row is tapped, regardless of [selectionMode].
  final ValueChanged<T>? onRowTap;

  /// Shows skeleton rows instead of [rows] while `true`.
  final bool loading;

  /// Shown instead of the row list when [rows] is empty and not
  /// [loading]. Defaults to a centered "No data" message.
  final Widget? emptyState;

  /// The height of every row, in logical pixels.
  final double rowHeight;

  /// The height of the header row, in logical pixels.
  final double headerHeight;

  /// Whether the header stays pinned while the body scrolls.
  final bool stickyHeader;

  /// Drives sort/selection state externally. Never required for basic
  /// use — `NibDataTable` creates and owns its own controller when this
  /// is `null`.
  final NibDataTableController<T>? controller;

  /// Opt-in row-entrance animation, via `nib_motion`. `false` allocates
  /// zero `NibMotion`/`MotionValue` overhead.
  final bool animated;

  /// The transition used for [animated] row entrances. Defaults to a
  /// 220ms ease-in-out fade/slide when `animated` is `true` and this is
  /// `null`.
  final NibTransition? transition;

  /// Accessibility label for the table as a whole.
  final String? semanticLabel;

  @override
  State<NibDataTable<T>> createState() => _NibDataTableState<T>();
}

class _NibDataTableState<T> extends State<NibDataTable<T>> {
  late NibDataTableController<T> _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant NibDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _unbindController();
      _bindController(widget.controller);
    }
  }

  @override
  void dispose() {
    _unbindController();
    super.dispose();
  }

  void _bindController(NibDataTableController<T>? external) {
    _controller = external ?? NibDataTableController<T>();
    _ownsController = external == null;
    _controller.addListener(_handleControllerChanged);
  }

  void _unbindController() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
  }

  void _handleControllerChanged() => setState(() {});

  Key _keyFor(T row) => widget.rowKey?.call(row) ?? ValueKey<T>(row);

  List<T> get _displayedRows {
    final sort = _controller.sort;
    if (widget.onSort != null || sort.columnIndex == null) {
      return widget.rows;
    }
    final column = widget.columns[sort.columnIndex!];
    final getter = column.sortValue;
    if (getter == null) return widget.rows;
    final sorted = List<T>.of(widget.rows)
      ..sort((a, b) => getter(a).compareTo(getter(b)));
    if (sort.direction == NibSortDirection.descending) {
      return sorted.reversed.toList(growable: false);
    }
    return sorted;
  }

  Widget _sizedCell(NibDataColumn<T> column, Widget child) {
    if (column.width != null) {
      return SizedBox(width: column.width, child: child);
    }
    return Expanded(
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: column.minWidth),
        child: child,
      ),
    );
  }

  void _cycleSort(int columnIndex) {
    final current = _controller.sort;
    final NibSortDirection nextDirection;
    if (current.columnIndex != columnIndex) {
      nextDirection = NibSortDirection.ascending;
    } else {
      nextDirection = switch (current.direction) {
        NibSortDirection.none => NibSortDirection.ascending,
        NibSortDirection.ascending => NibSortDirection.descending,
        NibSortDirection.descending => NibSortDirection.none,
      };
    }
    _controller.setSort(
      NibDataTableSort(
        columnIndex: nextDirection == NibSortDirection.none ? null : columnIndex,
        direction: nextDirection,
      ),
    );
    widget.onSort?.call(columnIndex, nextDirection);
  }

  void _toggleRow(T row) {
    switch (widget.selectionMode) {
      case NibDataTableSelectionMode.none:
        return;
      case NibDataTableSelectionMode.single:
        final already = _controller.selected.contains(row);
        _controller.setSelected(already ? <T>{} : {row});
      case NibDataTableSelectionMode.multi:
        _controller.toggleSelected(row);
    }
    widget.onSelectionChanged?.call(_controller.selected);
  }

  void _toggleSelectAll(List<T> visibleRows, bool selectAll) {
    _controller.setSelected(selectAll ? visibleRows.toSet() : <T>{});
    widget.onSelectionChanged?.call(_controller.selected);
  }

  Widget _buildHeaderRow(BuildContext context, NibTheme theme, List<T> rows) {
    final sort = _controller.sort;
    final selected = _controller.selected;
    final allSelected = rows.isNotEmpty && rows.every(selected.contains);
    final someSelected = rows.any(selected.contains);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.card,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: SizedBox(
        height: widget.headerHeight,
        child: Row(
          children: [
            if (widget.selectionMode == NibDataTableSelectionMode.multi)
              SizedBox(
                width: 48,
                child: Checkbox(
                  value: allSelected ? true : (someSelected ? null : false),
                  tristate: true,
                  onChanged: (_) => _toggleSelectAll(rows, !allSelected),
                ),
              ),
            for (var i = 0; i < widget.columns.length; i++)
              _sizedCell(widget.columns[i], _buildHeaderCell(theme, i, sort)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(NibTheme theme, int columnIndex, NibDataTableSort sort) {
    final column = widget.columns[columnIndex];
    final isSorted = sort.columnIndex == columnIndex && sort.direction != NibSortDirection.none;
    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              column.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isSorted) ...[
            const SizedBox(width: 4),
            Icon(
              sort.direction == NibSortDirection.ascending
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 14,
              color: theme.mutedForeground,
            ),
          ],
        ],
      ),
    );

    if (!column.sortable) {
      return Align(alignment: Alignment.centerLeft, child: label);
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => _cycleSort(columnIndex),
        child: Align(alignment: Alignment.centerLeft, child: label),
      ),
    );
  }

  Widget _buildRow(BuildContext context, NibTheme theme, T row, int index) {
    final selected = _controller.selected.contains(row);
    final cells = Row(
      children: [
        if (widget.selectionMode == NibDataTableSelectionMode.multi)
          SizedBox(
            width: 48,
            child: Checkbox(
              value: selected,
              onChanged: (_) => _toggleRow(row),
            ),
          ),
        for (var i = 0; i < widget.columns.length; i++)
          _sizedCell(
            widget.columns[i],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: theme.foreground),
                  child: widget.columns[i].cellBuilder(context, row),
                ),
              ),
            ),
          ),
      ],
    );

    final content = Container(
      height: widget.rowHeight,
      color: selected ? theme.secondary : null,
      child: cells,
    );

    final tappable = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          widget.onRowTap?.call(row);
          if (widget.selectionMode == NibDataTableSelectionMode.single) {
            _toggleRow(row);
          }
        },
        child: content,
      ),
    );

    if (!widget.animated) return tappable;

    return NibMotion(
      key: _keyFor(row),
      initial: const NibAnim(opacity: 0, y: 6),
      animate: const NibAnim(opacity: 1, y: 0),
      transition:
          widget.transition ?? const NibTransition(duration: Duration(milliseconds: 220)),
      child: tappable,
    );
  }

  Widget _buildSkeletonRow(NibTheme theme) {
    final blockCount =
        widget.columns.length + (widget.selectionMode == NibDataTableSelectionMode.multi ? 1 : 0);
    final row = SizedBox(
      key: const ValueKey('nib-data-table-skeleton-row'),
      height: widget.rowHeight,
      child: Row(
        children: [
          for (var i = 0; i < blockCount; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.muted,
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (!widget.animated) return row;
    return NibShimmer(enabled: true, child: row);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final rows = _displayedRows;

    return Semantics(
      label: widget.semanticLabel,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.border),
          borderRadius: BorderRadius.circular(theme.radiusDefault),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.radiusDefault),
          child: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: widget.stickyHeader,
                delegate: _NibDataTableHeaderDelegate(
                  height: widget.headerHeight,
                  child: _buildHeaderRow(context, theme, rows),
                ),
              ),
              if (widget.loading)
                SliverFixedExtentList.builder(
                  itemExtent: widget.rowHeight,
                  itemCount: 8,
                  itemBuilder: (context, index) => _buildSkeletonRow(theme),
                )
              else if (rows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child:
                      widget.emptyState ??
                      Center(
                        child: Text(
                          'No data',
                          style: TextStyle(color: theme.mutedForeground),
                        ),
                      ),
                )
              else
                SliverFixedExtentList.builder(
                  itemExtent: widget.rowHeight,
                  itemCount: rows.length,
                  itemBuilder: (context, index) =>
                      _buildRow(context, theme, rows[index], index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NibDataTableHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _NibDataTableHeaderDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _NibDataTableHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}
