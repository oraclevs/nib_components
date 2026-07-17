import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal — a numbered pager over a handful of pages.
class PaginationMinimalExample extends StatefulWidget {
  const PaginationMinimalExample({super.key});

  @override
  State<PaginationMinimalExample> createState() =>
      _PaginationMinimalExampleState();
}

class _PaginationMinimalExampleState extends State<PaginationMinimalExample> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Minimal — page $_page of 5'),
        const SizedBox(height: 16),
        NibPagination(
          currentPage: _page,
          totalPages: 5,
          onPageChanged: (p) => setState(() => _page = p),
        ),
      ],
    );
  }
}

/// 2. Large count — ellipsis collapsing, first/last jumps, siblings, animated
/// (sliding pill + active-page pop).
class PaginationLargeExample extends StatefulWidget {
  const PaginationLargeExample({super.key});

  @override
  State<PaginationLargeExample> createState() => _PaginationLargeExampleState();
}

class _PaginationLargeExampleState extends State<PaginationLargeExample> {
  int _page = 8;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Large — page $_page of 50 (first/last, animated)'),
        const SizedBox(height: 16),
        NibPagination(
          currentPage: _page,
          totalPages: 50,
          siblingCount: 2,
          showFirstLast: true,
          animated: true,
          onPageChanged: (p) => setState(() => _page = p),
        ),
      ],
    );
  }
}

/// 3. Compact — prev / "Page X of Y" / next, animated.
class PaginationCompactExample extends StatefulWidget {
  const PaginationCompactExample({super.key});

  @override
  State<PaginationCompactExample> createState() =>
      _PaginationCompactExampleState();
}

class _PaginationCompactExampleState extends State<PaginationCompactExample> {
  int _page = 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Compact — phone-friendly pager'),
        const SizedBox(height: 16),
        NibPagination(
          currentPage: _page,
          totalPages: 12,
          variant: NibPaginationVariant.compact,
          animated: true,
          onPageChanged: (p) => setState(() => _page = p),
        ),
      ],
    );
  }
}
