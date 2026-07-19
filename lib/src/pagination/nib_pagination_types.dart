import 'dart:math' as math;

/// The two layouts a [NibPagination] can render.
enum NibPaginationVariant {
  /// `‹ 1 … 4 [5] 6 … 10 ›` — pinned boundaries, sibling pages around the
  /// current one, and ellipses collapsing the rest.
  numbered,

  /// `‹ Prev · "Page 5 of 10" · Next ›` — a compact prev/label/next row, ideal
  /// on phones or as a table pager.
  compact,
}

/// Computes the visible page slots for a numbered pagination, collapsing large
/// gaps into ellipses. `null` entries mark an ellipsis; ints are page numbers.
///
/// A port of MUI's `usePagination` item algorithm: [boundaryCount] pages are
/// pinned at each end, [siblingCount] pages are shown either side of
/// [currentPage], and a gap of a single page is shown as that page (never an
/// ellipsis for just one number).
///
/// ```dart
/// paginationRange(currentPage: 5, totalPages: 10); // [1, null, 4, 5, 6, null, 10]
/// paginationRange(currentPage: 1, totalPages: 10); // [1, 2, 3, 4, 5, null, 10]
/// ```
List<int?> paginationRange({
  required int currentPage,
  required int totalPages,
  int siblingCount = 1,
  int boundaryCount = 1,
}) {
  if (totalPages <= 0) return const [];

  List<int> range(int start, int end) => [for (var i = start; i <= end; i++) i];

  final startPages = range(1, math.min(boundaryCount, totalPages));
  final endPages = range(
    math.max(totalPages - boundaryCount + 1, boundaryCount + 1),
    totalPages,
  );

  final siblingsStart = math.max(
    math.min(
      currentPage - siblingCount,
      totalPages - boundaryCount - siblingCount * 2 - 1,
    ),
    boundaryCount + 2,
  );
  final siblingsEnd = math.min(
    math.max(currentPage + siblingCount, boundaryCount + siblingCount * 2 + 2),
    endPages.isNotEmpty ? endPages.first - 2 : totalPages - 1,
  );

  return <int?>[
    ...startPages,
    // Head: an ellipsis when >1 page is hidden, else the single hidden page.
    if (siblingsStart > boundaryCount + 2)
      null
    else if (boundaryCount + 1 < totalPages - boundaryCount)
      boundaryCount + 1,
    ...range(siblingsStart, siblingsEnd),
    // Tail: an ellipsis when >1 page is hidden, else the single hidden page.
    if (siblingsEnd < totalPages - boundaryCount - 1)
      null
    else if (totalPages - boundaryCount > boundaryCount)
      totalPages - boundaryCount,
    ...endPages,
  ];
}
