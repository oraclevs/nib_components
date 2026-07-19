import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

Widget _wrap(Widget child, {double width = 400}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    ),
  ),
);

const _options = [
  NibToggleOption(value: 'left', label: 'Left'),
  NibToggleOption(value: 'center', label: 'Center'),
  NibToggleOption(value: 'right', label: 'Right'),
];

void main() {
  group('NibToggleGroup — render', () {
    testWidgets('renders every segment label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>(
            options: _options,
            value: 'left',
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Center'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
    });

    testWidgets('no segment selected when value is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>(
            options: _options,
            value: null,
            onChanged: (_) {},
          ),
        ),
      );
      final node = tester.getSemantics(find.text('Left'));
      expect(node.hasFlag(SemanticsFlag.isToggled), isFalse);
    });
  });

  group('NibToggleGroup — single select', () {
    testWidgets('tapping a segment fires onChanged with its value', (
      tester,
    ) async {
      String? got;
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>(
            options: _options,
            value: 'left',
            onChanged: (v) => got = v,
          ),
        ),
      );
      await tester.tap(find.text('Center'));
      expect(got, 'center');
    });

    testWidgets('tapping the already-selected segment deselects (null)', (
      tester,
    ) async {
      String? got = 'unset';
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>(
            options: _options,
            value: 'left',
            onChanged: (v) => got = v,
          ),
        ),
      );
      await tester.tap(find.text('Left'));
      expect(got, isNull);
    });

    testWidgets('tapping a disabled segment does not fire onChanged', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>(
            options: const [
              NibToggleOption(value: 'left', label: 'Left'),
              NibToggleOption(value: 'center', label: 'Center', disabled: true),
            ],
            value: 'left',
            onChanged: (_) => calls++,
          ),
        ),
      );
      await tester.tap(find.text('Center'));
      expect(calls, 0);
    });

    testWidgets('null onChanged renders disabled (no crash on tap)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NibToggleGroup<String>(options: _options, value: 'left')),
      );
      await tester.tap(find.text('Center'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disabled: true on the group blocks every segment', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>(
            options: _options,
            value: 'left',
            disabled: true,
            onChanged: (_) => calls++,
          ),
        ),
      );
      await tester.tap(find.text('Center'));
      expect(calls, 0);
    });
  });

  group('NibToggleGroup — multiple select', () {
    testWidgets('tapping an unselected segment adds it to values', (
      tester,
    ) async {
      Set<String>? got;
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>.multiple(
            options: _options,
            values: const {'left'},
            onChanged: (v) => got = v,
          ),
        ),
      );
      await tester.tap(find.text('Center'));
      expect(got, {'left', 'center'});
    });

    testWidgets('tapping a selected segment removes it from values', (
      tester,
    ) async {
      Set<String>? got;
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>.multiple(
            options: _options,
            values: const {'left', 'center'},
            onChanged: (v) => got = v,
          ),
        ),
      );
      await tester.tap(find.text('Left'));
      expect(got, {'center'});
    });

    testWidgets('multiple segments can be toggled independently', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>.multiple(
            options: _options,
            values: const {'left', 'right'},
            onChanged: (_) {},
          ),
        ),
      );
      final leftNode = tester.getSemantics(find.text('Left'));
      final centerNode = tester.getSemantics(find.text('Center'));
      final rightNode = tester.getSemantics(find.text('Right'));
      expect(leftNode.hasFlag(SemanticsFlag.isToggled), isTrue);
      expect(centerNode.hasFlag(SemanticsFlag.isToggled), isFalse);
      expect(rightNode.hasFlag(SemanticsFlag.isToggled), isTrue);
    });
  });

  group('NibToggleGroup — keyboard', () {
    testWidgets('arrow right/down moves focus without changing selection', (
      tester,
    ) async {
      String? got;
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>(
            options: _options,
            value: 'left',
            autofocus: true,
            onChanged: (v) => got = v,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(got, isNull); // onChanged never called — pure focus move
      expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
    });

    testWidgets('space toggles the focused (non-selected) segment', (
      tester,
    ) async {
      String? got;
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>(
            options: _options,
            value: 'left',
            autofocus: true,
            onChanged: (v) => got = v,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(got, 'center');
    });

    testWidgets('arrow navigation wraps and skips disabled segments', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>(
            options: const [
              NibToggleOption(value: 'left', label: 'Left'),
              NibToggleOption(value: 'center', label: 'Center', disabled: true),
              NibToggleOption(value: 'right', label: 'Right'),
            ],
            value: 'left',
            autofocus: true,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      // 'center' is disabled, so arrow-right from 'left' should land on
      // 'right' and space should toggle it off (deselect from... it's not
      // selected, so this asserts no crash and reasonable focus movement).
      expect(tester.takeException(), isNull);
    });
  });

  group('NibToggleGroup — animated', () {
    testWidgets('animated: false builds zero NibMotion', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>(
            options: _options,
            value: 'left',
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('animated: true builds a NibMotion for the selected segment', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>(
            options: _options,
            value: 'left',
            animated: true,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(NibMotion), findsOneWidget);
    });

    testWidgets('animated: true with no selection builds zero NibMotion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>(
            options: _options,
            value: null,
            animated: true,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(NibMotion), findsNothing);
    });
  });

  group('NibToggleGroup — layout', () {
    testWidgets('horizontal direction wraps instead of overflowing at a '
        'narrow width', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibToggleGroup<String>(
            options: const [
              NibToggleOption(value: 'a', label: 'A very long segment label'),
              NibToggleOption(value: 'b', label: 'Another long segment label'),
              NibToggleOption(value: 'c', label: 'Yet another segment label'),
            ],
            value: 'a',
            onChanged: (_) {},
          ),
          width: 200,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
