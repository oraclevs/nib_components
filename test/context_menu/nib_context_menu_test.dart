import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// A distinct trigger type so `find.byType` is unambiguous (a bare `ColoredBox`
/// also appears elsewhere in the Material scaffold).
class _Trigger extends StatelessWidget {
  const _Trigger();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 200,
    height: 100,
    child: ColoredBox(color: Colors.grey),
  );
}

void main() {
  group('NibContextMenu (trigger wrapper)', () {
    testWidgets('a right-click opens the menu', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibContextMenu(
            items: [
              NibMenuItem(label: 'Copy'),
              NibMenuItem(label: 'Paste'),
            ],
            child: _Trigger(),
          ),
        ),
      );

      expect(find.text('Copy'), findsNothing);
      await tester.tap(find.byType(_Trigger), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
    });

    testWidgets('a long-press opens the menu', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibContextMenu(
            items: [NibMenuItem(label: 'Item A')],
            child: _Trigger(),
          ),
        ),
      );

      await tester.longPress(find.byType(_Trigger));
      await tester.pumpAndSettle();
      expect(find.text('Item A'), findsOneWidget);
    });

    testWidgets('dividers and section headers render', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibContextMenu(
            items: [
              NibMenuSection('Edit'),
              NibMenuItem(label: 'Cut'),
              NibMenuDivider(),
              NibMenuItem(label: 'Delete', destructive: true),
            ],
            child: _Trigger(),
          ),
        ),
      );
      await tester.tap(find.byType(_Trigger), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('selecting a leaf fires callbacks and closes the menu', (
      tester,
    ) async {
      var selected = '';
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          NibContextMenu(
            onItemSelected: (item) => selected = item.label,
            items: [
              NibMenuItem(label: 'Rename', onSelected: () => tapped = true),
            ],
            child: const _Trigger(),
          ),
        ),
      );
      await tester.tap(find.byType(_Trigger), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(selected, 'Rename');
      expect(tapped, isTrue);
      expect(find.text('Rename'), findsNothing); // closed
    });

    testWidgets('an outside tap dismisses without selecting', (tester) async {
      var selected = false;
      await tester.pumpWidget(
        _wrap(
          NibContextMenu(
            onItemSelected: (_) => selected = true,
            items: const [NibMenuItem(label: 'Only')],
            child: const _Trigger(),
          ),
        ),
      );
      await tester.tap(find.byType(_Trigger), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text('Only'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Only'), findsNothing);
      expect(selected, isFalse);
    });

    testWidgets(
      'a submenu opens and a nested leaf selection closes everything',
      (tester) async {
        var selected = '';
        await tester.pumpWidget(
          _wrap(
            NibContextMenu(
              onItemSelected: (item) => selected = item.label,
              items: const [
                NibMenuItem(label: 'Top'),
                NibMenuItem(
                  label: 'More',
                  submenu: [
                    NibMenuItem(label: 'Nested A'),
                    NibMenuItem(label: 'Nested B'),
                  ],
                ),
              ],
              child: const _Trigger(),
            ),
          ),
        );
        await tester.tap(find.byType(_Trigger), buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        expect(find.text('Nested A'), findsOneWidget);
        expect(find.text('Top'), findsOneWidget); // parent stays open

        await tester.tap(find.text('Nested B'));
        await tester.pumpAndSettle();
        expect(selected, 'Nested B');
        expect(find.text('Top'), findsNothing); // whole chain closed
        expect(find.text('Nested A'), findsNothing);
      },
    );

    testWidgets('keyboard: ArrowDown then Enter selects the first item', (
      tester,
    ) async {
      var selected = '';
      await tester.pumpWidget(
        _wrap(
          NibContextMenu(
            onItemSelected: (item) => selected = item.label,
            items: const [
              NibMenuItem(label: 'First'),
              NibMenuItem(label: 'Second'),
            ],
            child: const _Trigger(),
          ),
        ),
      );
      await tester.tap(find.byType(_Trigger), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(selected, 'First');
      expect(find.text('First'), findsNothing);
    });

    testWidgets('Escape closes the menu', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibContextMenu(
            items: [NibMenuItem(label: 'Esc me')],
            child: _Trigger(),
          ),
        ),
      );
      await tester.tap(find.byType(_Trigger), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text('Esc me'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Esc me'), findsNothing);
    });

    testWidgets('builds no NibMotion when not animated, some when animated', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const NibContextMenu(
            items: [NibMenuItem(label: 'Plain')],
            child: _Trigger(),
          ),
        ),
      );
      await tester.tap(find.byType(_Trigger), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.byType(NibMotion), findsNothing);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _wrap(
          const NibContextMenu(
            animated: true,
            items: [NibMenuItem(label: 'Anim')],
            child: _Trigger(),
          ),
        ),
      );
      await tester.tap(find.byType(_Trigger), buttons: kSecondaryButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(NibMotion), findsWidgets);
      await tester.pumpAndSettle();
    });
  });

  group('showNibContextMenu (imperative)', () {
    testWidgets('completes with the chosen item and clamps to the viewport', (
      tester,
    ) async {
      NibMenuItem? result;
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );

      // Open near the bottom-right corner (screen is 800x600 in tests).
      final future = showNibContextMenu(
        ctx,
        globalPosition: const Offset(790, 590),
        items: const [NibMenuItem(label: 'Clamped')],
      );
      future.then((v) => result = v);
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.text('Clamped'));
      expect(rect.right, lessThanOrEqualTo(800));
      expect(rect.bottom, lessThanOrEqualTo(600));

      await tester.tap(find.text('Clamped'));
      await tester.pumpAndSettle();
      expect(result?.label, 'Clamped');
    });
  });
}
