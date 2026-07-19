import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

List<NibAccordionItem> _items() => const [
  NibAccordionItem(title: Text('First'), content: Text('First body')),
  NibAccordionItem(title: Text('Second'), content: Text('Second body')),
  NibAccordionItem(title: Text('Third'), content: Text('Third body')),
];

void main() {
  group('NibAccordion', () {
    testWidgets('renders every item title, content hidden until opened', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(NibAccordion(items: _items())));
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('First body'), findsNothing);
    });

    testWidgets('tapping a header expands and collapses it', (tester) async {
      await tester.pumpWidget(_wrap(NibAccordion(items: _items())));

      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      expect(find.text('First body'), findsOneWidget);

      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      expect(find.text('First body'), findsNothing);
    });

    testWidgets('single-open by default — opening one closes the others', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(NibAccordion(items: _items())));

      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      expect(find.text('First body'), findsOneWidget);

      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(find.text('Second body'), findsOneWidget);
      expect(find.text('First body'), findsNothing); // coordinated closed
    });

    testWidgets('allowMultipleOpen keeps siblings open together', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NibAccordion(items: _items(), allowMultipleOpen: true)),
      );

      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(find.text('First body'), findsOneWidget);
      expect(find.text('Second body'), findsOneWidget);
    });

    testWidgets('defaultOpenIndex starts that item expanded', (tester) async {
      await tester.pumpWidget(
        _wrap(NibAccordion(items: _items(), defaultOpenIndex: 1)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Second body'), findsOneWidget);
      expect(find.text('First body'), findsNothing);
    });

    testWidgets('a disabled item does not open', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibAccordion(
            items: const [
              NibAccordionItem(
                title: Text('Locked'),
                content: Text('Locked body'),
                enabled: false,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Locked'));
      await tester.pumpAndSettle();
      expect(find.text('Locked body'), findsNothing);
    });

    testWidgets('external controller drives open/close', (tester) async {
      final controller = NibAccordionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(NibAccordion(items: _items(), controller: controller)),
      );

      controller.open(2);
      await tester.pumpAndSettle();
      expect(find.text('Third body'), findsOneWidget);

      controller.closeAll();
      await tester.pumpAndSettle();
      expect(find.text('Third body'), findsNothing);
    });

    testWidgets('onExpansionChanged fires with index + state', (tester) async {
      final events = <(int, bool)>[];
      await tester.pumpWidget(
        _wrap(
          NibAccordion(
            items: _items(),
            onExpansionChanged: (i, open) => events.add((i, open)),
          ),
        ),
      );
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      expect(events.last, (0, true));
    });

    testWidgets('builds no NibMotion when animated is false', (tester) async {
      await tester.pumpWidget(_wrap(NibAccordion(items: _items())));
      expect(find.byType(NibMotion), findsNothing);
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('uses NibMotion for the chevron when animated', (tester) async {
      await tester.pumpWidget(
        _wrap(NibAccordion(items: _items(), animated: true)),
      );
      expect(find.byType(NibMotion), findsWidgets);
    });
  });

  group('NibAccordionController', () {
    test('single-open mode keeps at most one index open', () {
      final c = NibAccordionController();
      addTearDown(c.dispose);
      c.open(0);
      c.open(1);
      expect(c.openIndices, {1});
    });

    test('multi-open mode accumulates', () {
      final c = NibAccordionController(allowMultiple: true);
      addTearDown(c.dispose);
      c.open(0);
      c.open(2);
      expect(c.openIndices, {0, 2});
    });

    test('toggle flips a single index', () {
      final c = NibAccordionController();
      addTearDown(c.dispose);
      c.toggle(1);
      expect(c.isOpen(1), isTrue);
      c.toggle(1);
      expect(c.isOpen(1), isFalse);
    });
  });
}
