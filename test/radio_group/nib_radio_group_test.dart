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
  NibRadioOption(value: 'a', label: 'Alpha'),
  NibRadioOption(value: 'b', label: 'Beta'),
  NibRadioOption(value: 'c', label: 'Gamma'),
];

void main() {
  group('NibRadioGroup — render', () {
    testWidgets('renders every option label', (tester) async {
      await tester.pumpWidget(_wrap(
        NibRadioGroup<String>(
          options: _options,
          value: 'a',
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
    });

    testWidgets('renders description when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        NibRadioGroup<String>(
          options: const [
            NibRadioOption(
              value: 'a',
              label: 'Alpha',
              description: 'First letter',
            ),
          ],
          value: 'a',
          onChanged: (_) {},
        ),
      ));
      expect(find.text('First letter'), findsOneWidget);
    });

    testWidgets('no option selected when value is null', (tester) async {
      await tester.pumpWidget(_wrap(
        NibRadioGroup<String>(
          options: _options,
          value: null,
          onChanged: (_) {},
        ),
      ));
      final semantics = tester.getSemantics(find.text('Alpha').first);
      expect(semantics.hasFlag(SemanticsFlag.isChecked), isFalse);
    });
  });

  group('NibRadioGroup — selection', () {
    testWidgets('tapping an option fires onChanged with its value',
        (tester) async {
      String? got;
      await tester.pumpWidget(_wrap(
        NibRadioGroup<String>(
          options: _options,
          value: 'a',
          onChanged: (v) => got = v,
        ),
      ));
      await tester.tap(find.text('Beta'));
      expect(got, 'b');
    });

    testWidgets('tapping the already-selected option does not fire onChanged',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(
        NibRadioGroup<String>(
          options: _options,
          value: 'a',
          onChanged: (_) => calls++,
        ),
      ));
      await tester.tap(find.text('Alpha'));
      expect(calls, 0);
    });

    testWidgets('tapping a disabled option does not fire onChanged',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(
        NibRadioGroup<String>(
          options: const [
            NibRadioOption(value: 'a', label: 'Alpha'),
            NibRadioOption(value: 'b', label: 'Beta', disabled: true),
          ],
          value: 'a',
          onChanged: (_) => calls++,
        ),
      ));
      await tester.tap(find.text('Beta'));
      expect(calls, 0);
    });

    testWidgets('null onChanged renders disabled (no crash on tap)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        NibRadioGroup<String>(options: _options, value: 'a'),
      ));
      await tester.tap(find.text('Beta'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disabled: true on the group blocks every option',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(
        NibRadioGroup<String>(
          options: _options,
          value: 'a',
          disabled: true,
          onChanged: (_) => calls++,
        ),
      ));
      await tester.tap(find.text('Beta'));
      expect(calls, 0);
    });
  });

  group('NibRadioGroup — keyboard', () {
    testWidgets('arrow down/right moves selection to the next option',
        (tester) async {
      String? got;
      await tester.pumpWidget(_wrap(
        NibRadioGroup<String>(
          options: _options,
          value: 'a',
          autofocus: true,
          onChanged: (v) => got = v,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(got, 'b');
    });

    testWidgets('arrow up/left moves selection to the previous option, '
        'wrapping past the first', (tester) async {
      String? got;
      await tester.pumpWidget(_wrap(
        NibRadioGroup<String>(
          options: _options,
          value: 'a',
          autofocus: true,
          onChanged: (v) => got = v,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(got, 'c'); // wraps to the last option
    });

    testWidgets('arrow navigation skips disabled options', (tester) async {
      String? got;
      await tester.pumpWidget(_wrap(
        NibRadioGroup<String>(
          options: const [
            NibRadioOption(value: 'a', label: 'Alpha'),
            NibRadioOption(value: 'b', label: 'Beta', disabled: true),
            NibRadioOption(value: 'c', label: 'Gamma'),
          ],
          value: 'a',
          autofocus: true,
          onChanged: (v) => got = v,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(got, 'c');
    });
  });

  group('NibRadioGroup — animated', () {
    testWidgets('animated: false builds zero NibMotion', (tester) async {
      await tester.pumpWidget(_wrap(
        NibRadioGroup<String>(
          options: _options,
          value: 'a',
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('animated: true builds a NibMotion for the selected dot',
        (tester) async {
      await tester.pumpWidget(_wrap(
        NibRadioGroup<String>(
          options: _options,
          value: 'a',
          animated: true,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(NibMotion), findsOneWidget);
    });
  });

  group('NibRadioGroup — layout', () {
    testWidgets('horizontal direction wraps instead of overflowing at a '
        'narrow width', (tester) async {
      await tester.pumpWidget(_wrap(
        NibRadioGroup<String>(
          options: const [
            NibRadioOption(value: 'a', label: 'A very long option label'),
            NibRadioOption(value: 'b', label: 'Another long option label'),
            NibRadioOption(value: 'c', label: 'Yet another option label'),
          ],
          value: 'a',
          direction: Axis.horizontal,
          onChanged: (_) {},
        ),
        width: 200,
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('NibRadioGroup — custom option builder', () {
    testWidgets('optionBuilder replaces the default row content',
        (tester) async {
      await tester.pumpWidget(_wrap(
        NibRadioGroup<String>(
          options: _options,
          value: 'a',
          onChanged: (_) {},
          optionBuilder: (context, option, selected, disabled) =>
              Text('custom:${option.value}:$selected'),
        ),
      ));
      expect(find.text('custom:a:true'), findsOneWidget);
      expect(find.text('custom:b:false'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
    });
  });
}
