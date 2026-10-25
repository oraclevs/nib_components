import 'package:flutter/material.dart';
import 'dart:ui' show CheckedState;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('NibCheckbox — render', () {
    testWidgets('renders with no label (bare box)', (tester) async {
      await tester.pumpWidget(
        _wrap(NibCheckbox(value: false, onChanged: (_) {})),
      );
      expect(find.byType(NibCheckbox), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
    });

    testWidgets('renders label and description when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibCheckbox(
            value: false,
            onChanged: (_) {},
            label: 'Accept terms',
            description: 'Required to continue',
          ),
        ),
      );
      expect(find.text('Accept terms'), findsOneWidget);
      expect(find.text('Required to continue'), findsOneWidget);
    });
  });

  group('NibCheckbox — semantics', () {
    testWidgets('checked reflects value: true', (tester) async {
      await tester.pumpWidget(
        _wrap(NibCheckbox(value: true, onChanged: (_) {})),
      );
      final node = tester.getSemantics(find.byType(NibCheckbox));
      expect(node.flagsCollection.isChecked, CheckedState.isTrue);
    });

    testWidgets('mixed reflects a tristate null value', (tester) async {
      await tester.pumpWidget(
        _wrap(NibCheckbox(value: null, tristate: true, onChanged: (_) {})),
      );
      final node = tester.getSemantics(find.byType(NibCheckbox));
      expect(node.flagsCollection.isChecked, CheckedState.mixed);
    });
  });

  group('NibCheckbox — toggling', () {
    testWidgets('tapping a false checkbox fires onChanged(true)', (
      tester,
    ) async {
      bool? got;
      await tester.pumpWidget(
        _wrap(NibCheckbox(value: false, onChanged: (v) => got = v)),
      );
      await tester.tap(find.byType(NibCheckbox));
      expect(got, isTrue);
    });

    testWidgets('tapping a true checkbox fires onChanged(false) '
        'when not tristate', (tester) async {
      bool? got;
      await tester.pumpWidget(
        _wrap(NibCheckbox(value: true, onChanged: (v) => got = v)),
      );
      await tester.tap(find.byType(NibCheckbox));
      expect(got, isFalse);
    });

    testWidgets('tristate cycles false -> true -> null -> false', (
      tester,
    ) async {
      bool? value = false;
      late StateSetter setState;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setter) {
              setState = setter;
              return NibCheckbox(
                value: value,
                tristate: true,
                onChanged: (v) => setter(() => value = v),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(NibCheckbox));
      await tester.pump();
      expect(value, isTrue);

      await tester.tap(find.byType(NibCheckbox));
      await tester.pump();
      expect(value, isNull);

      await tester.tap(find.byType(NibCheckbox));
      await tester.pump();
      expect(value, isFalse);
      setState(() {});
    });

    testWidgets('null onChanged renders disabled (no crash on tap)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const NibCheckbox(value: false)));
      await tester.tap(find.byType(NibCheckbox));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disabled: true blocks onChanged', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          NibCheckbox(value: false, disabled: true, onChanged: (_) => calls++),
        ),
      );
      await tester.tap(find.byType(NibCheckbox));
      expect(calls, 0);
    });
  });

  group('NibCheckbox — keyboard', () {
    testWidgets('space activates a focused checkbox', (tester) async {
      bool? got;
      await tester.pumpWidget(
        _wrap(
          NibCheckbox(value: false, autofocus: true, onChanged: (v) => got = v),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(got, isTrue);
    });
  });

  group('NibCheckbox — animated', () {
    testWidgets('animated: false builds zero NibMotion', (tester) async {
      await tester.pumpWidget(
        _wrap(NibCheckbox(value: true, onChanged: (_) {})),
      );
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('animated: true builds a NibMotion for the check mark', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NibCheckbox(value: true, animated: true, onChanged: (_) {})),
      );
      expect(find.byType(NibMotion), findsOneWidget);
    });

    testWidgets('animated: true with value:false builds zero NibMotion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NibCheckbox(value: false, animated: true, onChanged: (_) {})),
      );
      expect(find.byType(NibMotion), findsNothing);
    });
  });
}
