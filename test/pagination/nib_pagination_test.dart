import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

Widget _wrap(Widget child, {double width = 600}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

const _prev = Key('nib_pagination_prev');
const _next = Key('nib_pagination_next');
const _first = Key('nib_pagination_first');
const _last = Key('nib_pagination_last');

void main() {
  group('paginationRange', () {
    test('collapses both sides around the current page', () {
      expect(paginationRange(currentPage: 5, totalPages: 10), [
        1,
        null,
        4,
        5,
        6,
        null,
        10,
      ]);
    });

    test('near the start shows the head run then one ellipsis', () {
      expect(paginationRange(currentPage: 1, totalPages: 10), [
        1,
        2,
        3,
        4,
        5,
        null,
        10,
      ]);
    });

    test('small counts show every page (no ellipsis)', () {
      expect(paginationRange(currentPage: 2, totalPages: 3), [1, 2, 3]);
    });

    test('total 7 all pages fit (no ellipsis)', () {
      expect(paginationRange(currentPage: 4, totalPages: 7), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      ]);
    });

    test('total 9 current 5 ellipsizes both sides', () {
      expect(paginationRange(currentPage: 5, totalPages: 9), [
        1,
        null,
        4,
        5,
        6,
        null,
        9,
      ]);
    });
  });

  group('NibPagination — numbered', () {
    testWidgets('renders sibling pages + ellipsis, collapses the rest', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibPagination(currentPage: 5, totalPages: 10, onPageChanged: (_) {}),
        ),
      );
      expect(find.text('4'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('2'), findsNothing); // collapsed
      expect(find.text('…'), findsNWidgets(2));
    });

    testWidgets('tapping a page fires onPageChanged', (tester) async {
      int? page;
      await tester.pumpWidget(
        _wrap(
          NibPagination(
            currentPage: 5,
            totalPages: 10,
            onPageChanged: (p) => page = p,
          ),
        ),
      );
      await tester.tap(find.text('6'));
      expect(page, 6);
    });

    testWidgets('prev/next step by one', (tester) async {
      int? page;
      await tester.pumpWidget(
        _wrap(
          NibPagination(
            currentPage: 5,
            totalPages: 10,
            onPageChanged: (p) => page = p,
          ),
        ),
      );
      await tester.tap(find.byKey(_next));
      expect(page, 6);
      await tester.tap(find.byKey(_prev));
      expect(page, 4);
    });

    testWidgets('prev disabled on the first page', (tester) async {
      int? page;
      await tester.pumpWidget(
        _wrap(
          NibPagination(
            currentPage: 1,
            totalPages: 10,
            onPageChanged: (p) => page = p,
          ),
        ),
      );
      await tester.tap(find.byKey(_prev), warnIfMissed: false);
      expect(page, isNull);
    });

    testWidgets('next disabled on the last page', (tester) async {
      int? page;
      await tester.pumpWidget(
        _wrap(
          NibPagination(
            currentPage: 10,
            totalPages: 10,
            onPageChanged: (p) => page = p,
          ),
        ),
      );
      await tester.tap(find.byKey(_next), warnIfMissed: false);
      expect(page, isNull);
    });

    testWidgets('showFirstLast jumps to 1 / total', (tester) async {
      int? page;
      await tester.pumpWidget(
        _wrap(
          NibPagination(
            currentPage: 5,
            totalPages: 10,
            showFirstLast: true,
            onPageChanged: (p) => page = p,
          ),
        ),
      );
      await tester.tap(find.byKey(_last));
      expect(page, 10);
      await tester.tap(find.byKey(_first));
      expect(page, 1);
    });
  });

  group('NibPagination — compact', () {
    testWidgets('shows the label and prev/next only', (tester) async {
      int? page;
      await tester.pumpWidget(
        _wrap(
          NibPagination(
            currentPage: 5,
            totalPages: 10,
            variant: NibPaginationVariant.compact,
            onPageChanged: (p) => page = p,
          ),
        ),
      );
      expect(find.text('Page 5 of 10'), findsOneWidget);
      expect(find.text('4'), findsNothing);
      await tester.tap(find.byKey(_next));
      expect(page, 6);
    });

    testWidgets('custom compactLabelBuilder', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibPagination(
            currentPage: 3,
            totalPages: 8,
            variant: NibPaginationVariant.compact,
            compactLabelBuilder: (c, t) => '$c / $t',
            onPageChanged: (_) {},
          ),
        ),
      );
      expect(find.text('3 / 8'), findsOneWidget);
    });
  });

  group('NibPagination — animation', () {
    testWidgets('animated:true builds NibMotion', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibPagination(
            currentPage: 5,
            totalPages: 10,
            animated: true,
            onPageChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(NibMotion), findsWidgets);
    });

    testWidgets('animated:false builds zero NibMotion', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibPagination(currentPage: 5, totalPages: 10, onPageChanged: (_) {}),
        ),
      );
      expect(find.byType(NibMotion), findsNothing);
    });
  });

  group('NibPagination — responsive', () {
    testWidgets('narrow width does not overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibPagination(currentPage: 10, totalPages: 20, onPageChanged: (_) {}),
          width: 150,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
