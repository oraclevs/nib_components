import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart' show NibAnim, NibMotion, NibTransition;

import '../button/nib_button.dart';
import '../button/nib_button_types.dart';
import '../theme/nib_theme.dart';
import 'nib_pagination_types.dart';

/// A page navigator with ellipsis collapsing for large page counts.
///
/// Simple by default — `NibPagination(currentPage: p, totalPages: n,
/// onPageChanged: ...)` — with a compact ([NibPaginationVariant.compact])
/// alternative, optional first/last jumps, and opt-in motion (a sliding active
/// pill + a pop on the newly-selected page). Every cell is a [NibButton], so it
/// inherits focus, keyboard activation and tap-target sizing for free.
///
/// ```dart
/// NibPagination(currentPage: page, totalPages: 20,
///   onPageChanged: (p) => setState(() => page = p))
/// NibPagination(currentPage: page, totalPages: 20,
///   variant: NibPaginationVariant.compact, onPageChanged: ...)
/// ```
class NibPagination extends StatefulWidget {
  const NibPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.variant = NibPaginationVariant.numbered,
    this.siblingCount = 1,
    this.boundaryCount = 1,
    this.showPrevNext = true,
    this.showFirstLast = false,
    this.disabled = false,
    this.compactLabelBuilder,
    this.itemSize,
    this.gap,
    this.activeColor,
    this.itemBorderRadius,
    this.animated = false,
    this.transition,
    this.semanticLabel,
  });

  /// The active page, 1-based.
  final int currentPage;

  /// Total number of pages.
  final int totalPages;

  /// Called with the target page. `null` renders the control disabled.
  final ValueChanged<int>? onPageChanged;

  /// Numbered (with ellipses) or a compact prev/label/next row.
  final NibPaginationVariant variant;

  /// Pages shown either side of [currentPage] (numbered).
  final int siblingCount;

  /// Pages pinned at each end (numbered).
  final int boundaryCount;

  /// Whether to show the prev/next chevrons.
  final bool showPrevNext;

  /// Whether to show the jump-to-first / jump-to-last chevrons (numbered).
  final bool showFirstLast;

  /// Disables interaction and dims the control.
  final bool disabled;

  /// Builds the compact-variant label. Defaults to `'Page $current of $total'`.
  final String Function(int current, int total)? compactLabelBuilder;

  /// Cell square size. Defaults to 44.
  final double? itemSize;

  /// Spacing between cells. Defaults to 6.
  final double? gap;

  /// The active pill colour. Defaults to `NibTheme.primary`.
  final Color? activeColor;

  /// Corner radius of each cell (and the active pill). Defaults to the theme's
  /// default radius.
  final BorderRadius? itemBorderRadius;

  /// Opt-in `nib_motion`: sliding active pill + pop on the new page. `false`
  /// builds **zero** [NibMotion].
  final bool animated;

  /// Timing/curve for [animated]. `null` → a short ~180ms ease.
  final NibTransition? transition;

  /// Accessible name for the whole control. Defaults to `'Pagination'`.
  final String? semanticLabel;

  @override
  State<NibPagination> createState() => _NibPaginationState();
}

class _NibPaginationState extends State<NibPagination> {
  bool get _interactive => !widget.disabled && widget.onPageChanged != null;
  double get _itemSize => widget.itemSize ?? 48;
  double get _gap => widget.gap ?? 4;

  /// A [NibButton] never lays out below the 48px tap target, so the real cell
  /// footprint (which the row width and pill pitch must use) is at least 48.
  double get _cellFootprint => math.max(_itemSize, 48);

  NibTransition get _transition =>
      widget.transition ??
      const NibTransition(duration: Duration(milliseconds: 180));

  void _go(int page) {
    if (!_interactive) return;
    if (page < 1 || page > widget.totalPages || page == widget.currentPage) {
      return;
    }
    widget.onPageChanged!(page);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totalPages <= 0) return const SizedBox.shrink();
    final theme = NibTheme.of(context);
    final body = widget.variant == NibPaginationVariant.compact
        ? _buildCompact(theme)
        : _buildNumbered(theme);

    return Semantics(
      container: true,
      label: widget.semanticLabel ?? 'Pagination',
      child: body,
    );
  }

  // --- shared cells ---------------------------------------------------------

  Widget _navButton({
    required Key key,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required String semanticLabel,
  }) {
    return NibButton(
      key: key,
      leadingIcon: Icon(icon),
      variant: NibButtonVariant.ghost,
      width: _itemSize,
      height: _itemSize,
      padding: EdgeInsets.zero,
      borderRadius: widget.itemBorderRadius,
      semanticLabel: semanticLabel,
      onPressed: (_interactive && enabled) ? onTap : null,
    );
  }

  // --- compact --------------------------------------------------------------

  Widget _buildCompact(NibTheme theme) {
    final label = widget.compactLabelBuilder?.call(
          widget.currentPage,
          widget.totalPages,
        ) ??
        'Page ${widget.currentPage} of ${widget.totalPages}';

    Widget labelWidget = Padding(
      padding: EdgeInsets.symmetric(horizontal: _gap * 2),
      child: Text(
        label,
        style: TextStyle(
          color: theme.mutedForeground,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
    if (widget.animated) {
      labelWidget = NibMotion(
        key: ValueKey(widget.currentPage),
        initial: const NibAnim(scale: 0.9),
        animate: NibAnim.identity,
        transition: _transition,
        child: labelWidget,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showPrevNext)
          _navButton(
            key: const Key('nib_pagination_prev'),
            icon: Icons.chevron_left,
            enabled: widget.currentPage > 1,
            onTap: () => _go(widget.currentPage - 1),
            semanticLabel: 'Previous page',
          ),
        labelWidget,
        if (widget.showPrevNext)
          _navButton(
            key: const Key('nib_pagination_next'),
            icon: Icons.chevron_right,
            enabled: widget.currentPage < widget.totalPages,
            onTap: () => _go(widget.currentPage + 1),
            semanticLabel: 'Next page',
          ),
      ],
    );
  }

  // --- numbered -------------------------------------------------------------

  Widget _buildNumbered(NibTheme theme) {
    final items = paginationRange(
      currentPage: widget.currentPage,
      totalPages: widget.totalPages,
      siblingCount: widget.siblingCount,
      boundaryCount: widget.boundaryCount,
    );

    final cells = <Widget>[];
    int? activeIndex;

    void add(Widget w) => cells.add(w);

    if (widget.showFirstLast) {
      add(_navButton(
        key: const Key('nib_pagination_first'),
        icon: Icons.keyboard_double_arrow_left,
        enabled: widget.currentPage > 1,
        onTap: () => _go(1),
        semanticLabel: 'First page',
      ));
    }
    if (widget.showPrevNext) {
      add(_navButton(
        key: const Key('nib_pagination_prev'),
        icon: Icons.chevron_left,
        enabled: widget.currentPage > 1,
        onTap: () => _go(widget.currentPage - 1),
        semanticLabel: 'Previous page',
      ));
    }

    for (final item in items) {
      if (item == null) {
        add(_ellipsis(theme));
      } else {
        final active = item == widget.currentPage;
        if (active) activeIndex = cells.length;
        add(_pageButton(theme, item, active));
      }
    }

    if (widget.showPrevNext) {
      add(_navButton(
        key: const Key('nib_pagination_next'),
        icon: Icons.chevron_right,
        enabled: widget.currentPage < widget.totalPages,
        onTap: () => _go(widget.currentPage + 1),
        semanticLabel: 'Next page',
      ));
    }
    if (widget.showFirstLast) {
      add(_navButton(
        key: const Key('nib_pagination_last'),
        icon: Icons.keyboard_double_arrow_right,
        enabled: widget.currentPage < widget.totalPages,
        onTap: () => _go(widget.totalPages),
        semanticLabel: 'Last page',
      ));
    }

    final pitch = _cellFootprint + _gap;
    final rowWidth =
        cells.length * _cellFootprint + (cells.length - 1) * _gap;
    // Centre the (possibly smaller) visual pill within the cell footprint.
    final pillInset = (_cellFootprint - _itemSize) / 2;

    // Interleave gaps so each cell's left == index * pitch.
    final rowChildren = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) rowChildren.add(SizedBox(width: _gap));
      rowChildren.add(cells[i]);
    }

    final stack = SizedBox(
      width: rowWidth,
      height: _cellFootprint,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (activeIndex != null)
            _activePill(theme, activeIndex * pitch + pillInset, pillInset),
          Row(mainAxisSize: MainAxisSize.min, children: rowChildren),
        ],
      ),
    );

    // Responsive: scroll horizontally rather than overflow on a narrow viewport.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedWidth && rowWidth > constraints.maxWidth) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: stack,
          );
        }
        return stack;
      },
    );
  }

  Widget _activePill(NibTheme theme, double left, double top) {
    final pill = Container(
      width: _itemSize,
      height: _itemSize,
      decoration: BoxDecoration(
        color: widget.activeColor ?? theme.primary,
        borderRadius:
            widget.itemBorderRadius ?? BorderRadius.circular(theme.radiusDefault),
      ),
    );

    if (widget.animated) {
      return Positioned(
        left: 0,
        top: top,
        width: _itemSize,
        height: _itemSize,
        child: NibMotion(
          initial: NibAnim(x: left),
          animate: NibAnim(x: left),
          transition: _transition,
          child: pill,
        ),
      );
    }
    return Positioned(
      left: left,
      top: top,
      width: _itemSize,
      height: _itemSize,
      child: pill,
    );
  }

  Widget _pageButton(NibTheme theme, int page, bool active) {
    // Active number sits on the pill → use the contrasting foreground.
    Widget button = active
        ? NibButton(
            content: Text(
              '$page',
              style: TextStyle(
                color: theme.primaryForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
            variant: NibButtonVariant.ghost,
            width: _itemSize,
            height: _itemSize,
            padding: EdgeInsets.zero,
            borderRadius: widget.itemBorderRadius,
            semanticLabel: 'Page $page',
            onPressed: _interactive ? () => _go(page) : null,
          )
        : NibButton(
            label: '$page',
            variant: NibButtonVariant.ghost,
            width: _itemSize,
            height: _itemSize,
            padding: EdgeInsets.zero,
            borderRadius: widget.itemBorderRadius,
            semanticLabel: 'Page $page',
            onPressed: _interactive ? () => _go(page) : null,
          );

    if (active && widget.animated) {
      button = NibMotion(
        key: ValueKey(widget.currentPage),
        initial: const NibAnim(scale: 0.9),
        animate: NibAnim.identity,
        transition: _transition,
        child: button,
      );
    }
    return button;
  }

  Widget _ellipsis(NibTheme theme) {
    return SizedBox(
      width: _itemSize,
      height: _itemSize,
      child: Center(
        child: Text(
          '…',
          style: TextStyle(color: theme.mutedForeground, fontSize: 16),
        ),
      ),
    );
  }
}
