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

List<NibBreadcrumbItem> _items(int n, {void Function(int)? onTap}) => [
  for (var i = 0; i < n; i++)
    NibBreadcrumbItem(label: 'Item$i', onTap: () => onTap?.call(i)),
];

void main() {
  group('breadcrumbVisibleIndices', () {
    test('collapsed drops the middle to an ellipsis', () {
      expect(breadcrumbVisibleIndices(count: 5, collapsed: true), [0, null, 4]);
    });

    test('not collapsed shows every index', () {
      expect(breadcrumbVisibleIndices(count: 5, collapsed: false), [
        0,
        1,
        2,
        3,
        4,
      ]);
    });

    test('honours before/after counts', () {
      expect(
        breadcrumbVisibleIndices(
          count: 6,
          collapsed: true,
          before: 2,
          after: 1,
        ),
        [0, 1, null, 5],
      );
    });

    test('does not collapse when count <= before + after', () {
      expect(breadcrumbVisibleIndices(count: 2, collapsed: true), [0, 1]);
    });
  });

  group('NibBreadcrumb — render', () {
    testWidgets('renders labels and separators', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibBreadcrumb(
            items: const [
              NibBreadcrumbItem(label: 'Home'),
              NibBreadcrumbItem(label: 'Docs'),
              NibBreadcrumbItem(label: 'Guide'),
            ],
          ),
        ),
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Docs'), findsOneWidget);
      expect(find.text('Guide'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    });

    testWidgets('the last crumb is current (not a link)', (tester) async {
      var lastTapped = false;
      await tester.pumpWidget(
        _wrap(
          NibBreadcrumb(
            items: [
              const NibBreadcrumbItem(label: 'Home'),
              NibBreadcrumbItem(
                label: 'Current',
                onTap: () => lastTapped = true,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Current'), warnIfMissed: false);
      expect(lastTapped, isFalse);
    });

    testWidgets('tapping a link fires its onTap', (tester) async {
      int? tapped;
      await tester.pumpWidget(
        _wrap(NibBreadcrumb(items: _items(4, onTap: (i) => tapped = i))),
      );
      await tester.tap(find.text('Item1'));
      expect(tapped, 1);
    });
  });

  group('NibBreadcrumb — collapse', () {
    testWidgets('maxVisibleItems collapses the middle to an ellipsis', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NibBreadcrumb(items: _items(5), maxVisibleItems: 3)),
      );
      expect(find.text('…'), findsOneWidget);
      expect(find.text('Item0'), findsOneWidget); // first
      expect(find.text('Item4'), findsOneWidget); // current
      expect(find.text('Item2'), findsNothing); // collapsed away
    });

    testWidgets('tapping the ellipsis opens the hidden crumbs in a popover', (
      tester,
    ) async {
      int? tapped;
      await tester.pumpWidget(
        _wrap(
          NibBreadcrumb(
            items: _items(5, onTap: (i) => tapped = i),
            maxVisibleItems: 3,
          ),
        ),
      );
      expect(find.text('Item2'), findsNothing);
      await tester.tap(find.text('…'));
      await tester.pumpAndSettle();
      expect(find.text('Item2'), findsOneWidget); // now in the overflow menu
      await tester.tap(find.text('Item2'));
      await tester.pumpAndSettle();
      expect(tapped, 2);
    });

    testWidgets('narrow width collapses without overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibBreadcrumb(
            items: const [
              NibBreadcrumbItem(label: 'Dashboard'),
              NibBreadcrumbItem(label: 'Projects'),
              NibBreadcrumbItem(label: 'Repositories'),
              NibBreadcrumbItem(label: 'Settings'),
              NibBreadcrumbItem(label: 'Access tokens'),
            ],
          ),
          width: 140,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('…'), findsOneWidget);
    });
  });

  group('NibBreadcrumb — animation', () {
    testWidgets('animated:true builds NibMotion', (tester) async {
      await tester.pumpWidget(
        _wrap(NibBreadcrumb(items: _items(3), animated: true)),
      );
      expect(find.byType(NibMotion), findsWidgets);
    });

    testWidgets('animated:false builds zero NibMotion', (tester) async {
      await tester.pumpWidget(_wrap(NibBreadcrumb(items: _items(3))));
      expect(find.byType(NibMotion), findsNothing);
    });
  });
}
