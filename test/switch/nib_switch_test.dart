import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('NibSwitch — render', () {
    testWidgets('renders with no label (bare track)', (tester) async {
      await tester.pumpWidget(_wrap(
        NibSwitch(value: false, onChanged: (_) {}),
      ));
      expect(find.byType(NibSwitch), findsOneWidget);
      expect(find.text('Wi-Fi'), findsNothing);
    });

    testWidgets('renders label and description when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        NibSwitch(
          value: true,
          onChanged: (_) {},
          label: 'Wi-Fi',
          description: 'Connect automatically',
        ),
      ));
      expect(find.text('Wi-Fi'), findsOneWidget);
      expect(find.text('Connect automatically'), findsOneWidget);
    });
  });

  group('NibSwitch — semantics', () {
    testWidgets('toggled reflects value: true', (tester) async {
      await tester.pumpWidget(_wrap(
        NibSwitch(value: true, onChanged: (_) {}),
      ));
      final node = tester.getSemantics(find.byType(NibSwitch));
      expect(node.hasFlag(SemanticsFlag.isToggled), isTrue);
    });

    testWidgets('toggled reflects value: false', (tester) async {
      await tester.pumpWidget(_wrap(
        NibSwitch(value: false, onChanged: (_) {}),
      ));
      final node = tester.getSemantics(find.byType(NibSwitch));
      expect(node.hasFlag(SemanticsFlag.isToggled), isFalse);
    });
  });

  group('NibSwitch — toggling', () {
    testWidgets('tapping a false switch fires onChanged(true)', (tester) async {
      bool? got;
      await tester.pumpWidget(_wrap(
        NibSwitch(value: false, onChanged: (v) => got = v),
      ));
      await tester.tap(find.byType(NibSwitch));
      expect(got, isTrue);
    });

    testWidgets('tapping a true switch fires onChanged(false)', (tester) async {
      bool? got;
      await tester.pumpWidget(_wrap(
        NibSwitch(value: true, onChanged: (v) => got = v),
      ));
      await tester.tap(find.byType(NibSwitch));
      expect(got, isFalse);
    });

    testWidgets('null onChanged renders disabled (no crash on tap)',
        (tester) async {
      await tester.pumpWidget(_wrap(const NibSwitch(value: false)));
      await tester.tap(find.byType(NibSwitch));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disabled: true blocks onChanged', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(
        NibSwitch(value: false, disabled: true, onChanged: (_) => calls++),
      ));
      await tester.tap(find.byType(NibSwitch));
      expect(calls, 0);
    });

    testWidgets('loading: true blocks onChanged', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(
        NibSwitch(value: false, loading: true, onChanged: (_) => calls++),
      ));
      await tester.tap(find.byType(NibSwitch));
      expect(calls, 0);
    });
  });

  group('NibSwitch — loading', () {
    testWidgets('shows a NibCircularLoader in the thumb while loading',
        (tester) async {
      await tester.pumpWidget(_wrap(
        NibSwitch(value: true, loading: true, onChanged: (_) {}),
      ));
      expect(find.byType(NibCircularLoader), findsOneWidget);
    });

    testWidgets('no loader when loading is false', (tester) async {
      await tester.pumpWidget(_wrap(
        NibSwitch(value: true, onChanged: (_) {}),
      ));
      expect(find.byType(NibCircularLoader), findsNothing);
    });

    testWidgets('loading spinner shows even with animated: false',
        (tester) async {
      await tester.pumpWidget(_wrap(
        NibSwitch(value: true, loading: true, onChanged: (_) {}),
      ));
      expect(find.byType(NibCircularLoader), findsOneWidget);
      expect(find.byType(NibMotion), findsNothing);
    });
  });

  group('NibSwitch — keyboard', () {
    testWidgets('space activates a focused switch', (tester) async {
      bool? got;
      await tester.pumpWidget(_wrap(
        NibSwitch(value: false, autofocus: true, onChanged: (v) => got = v),
      ));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(got, isTrue);
    });
  });

  group('NibSwitch — animation continuity', () {
    testWidgets(
        'thumb NibMotion survives a loading -> resolved transition '
        '(no remount/hop)', (tester) async {
      var value = false;
      var loading = false;
      late StateSetter setState;
      await tester.pumpWidget(_wrap(StatefulBuilder(
        builder: (context, setter) {
          setState = setter;
          return NibSwitch(
            value: value,
            loading: loading,
            animated: true,
            onChanged: (v) => setter(() => value = v),
          );
        },
      )));

      final beforeState = tester.state(find.byType(NibMotion));

      setState(() => loading = true);
      await tester.pump();
      setState(() {
        loading = false;
        value = true;
      });
      await tester.pump();

      final afterState = tester.state(find.byType(NibMotion));
      expect(identical(beforeState, afterState), isTrue);
    });

    testWidgets('thumb NibMotion survives a disabled -> enabled transition',
        (tester) async {
      var disabled = true;
      late StateSetter setState;
      await tester.pumpWidget(_wrap(StatefulBuilder(
        builder: (context, setter) {
          setState = setter;
          return NibSwitch(
            value: false,
            disabled: disabled,
            animated: true,
            onChanged: (_) {},
          );
        },
      )));

      final beforeState = tester.state(find.byType(NibMotion));
      setState(() => disabled = false);
      await tester.pump();
      final afterState = tester.state(find.byType(NibMotion));
      expect(identical(beforeState, afterState), isTrue);
    });
  });

  group('NibSwitch — thumb customization', () {
    testWidgets('thumbShape overrides the built-in circle', (tester) async {
      await tester.pumpWidget(_wrap(
        NibSwitch(
          value: false,
          onChanged: (_) {},
          thumbShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
      ));
      final found = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final decoration = w.decoration;
        return decoration is ShapeDecoration &&
            decoration.shape is RoundedRectangleBorder;
      });
      expect(found, findsOneWidget);
    });

    testWidgets('onThumbIcon/offThumbIcon swap with value', (tester) async {
      await tester.pumpWidget(_wrap(
        NibSwitch(
          value: false,
          onChanged: (_) {},
          onThumbIcon: const Icon(Icons.dark_mode, key: Key('moon')),
          offThumbIcon: const Icon(Icons.wb_sunny, key: Key('sun')),
        ),
      ));
      expect(find.byKey(const Key('sun')), findsOneWidget);
      expect(find.byKey(const Key('moon')), findsNothing);

      await tester.pumpWidget(_wrap(
        NibSwitch(
          value: true,
          onChanged: (_) {},
          onThumbIcon: const Icon(Icons.dark_mode, key: Key('moon')),
          offThumbIcon: const Icon(Icons.wb_sunny, key: Key('sun')),
        ),
      ));
      expect(find.byKey(const Key('sun')), findsNothing);
      expect(find.byKey(const Key('moon')), findsOneWidget);
    });

    testWidgets('loading spinner takes precedence over a thumb icon',
        (tester) async {
      await tester.pumpWidget(_wrap(
        NibSwitch(
          value: true,
          loading: true,
          onChanged: (_) {},
          onThumbIcon: const Icon(Icons.dark_mode, key: Key('moon')),
        ),
      ));
      expect(find.byType(NibCircularLoader), findsOneWidget);
      expect(find.byKey(const Key('moon')), findsNothing);
    });

    testWidgets('thumbBuilder fully replaces the built-in thumb',
        (tester) async {
      await tester.pumpWidget(_wrap(
        NibSwitch(
          value: true,
          onChanged: (_) {},
          thumbBuilder: (context, state) =>
              Text('custom:${state.value}:${state.enabled}'),
        ),
      ));
      expect(find.text('custom:true:true'), findsOneWidget);
    });
  });

  group('NibSwitch — animated', () {
    testWidgets('animated: false builds zero NibMotion', (tester) async {
      await tester.pumpWidget(_wrap(
        NibSwitch(value: true, onChanged: (_) {}),
      ));
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('animated: true builds a NibMotion for the thumb',
        (tester) async {
      await tester.pumpWidget(_wrap(
        NibSwitch(value: true, animated: true, onChanged: (_) {}),
      ));
      expect(find.byType(NibMotion), findsOneWidget);
    });
  });
}
