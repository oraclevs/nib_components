import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('NibOtpInput', () {
    testWidgets('renders one cell per length', (tester) async {
      await tester.pumpWidget(_wrap(const NibOtpInput(length: 4)));
      expect(find.byType(NibOtpCell), findsNWidgets(4));
    });

    testWidgets('typing fills cells and fires onChanged', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(_wrap(NibOtpInput(length: 4, onChanged: changes.add)));
      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(changes.last, '12');
    });

    testWidgets('onCompleted fires when all cells are filled', (tester) async {
      String? completed;
      await tester.pumpWidget(_wrap(NibOtpInput(
        length: 4,
        onCompleted: (v) => completed = v,
      )));
      await tester.enterText(find.byType(TextField), '123');
      await tester.pump();
      expect(completed, isNull);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      expect(completed, '1234');
    });

    testWidgets('pasting a full code splits across all cells (single field)',
        (tester) async {
      String? completed;
      await tester.pumpWidget(_wrap(NibOtpInput(
        length: 6,
        onCompleted: (v) => completed = v,
      )));
      // A paste delivers the whole string at once.
      await tester.enterText(find.byType(TextField), '654321');
      await tester.pump();
      expect(completed, '654321');
      for (final d in ['6', '5', '4', '3', '2', '1']) {
        expect(find.text(d), findsOneWidget);
      }
    });

    testWidgets('rejects non-digits', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(_wrap(NibOtpInput(length: 4, onChanged: changes.add)));
      await tester.enterText(find.byType(TextField), 'a1b2');
      await tester.pump();
      expect(changes.last, '12');
    });

    testWidgets('obscureText hides the digit behind a mask char', (tester) async {
      await tester.pumpWidget(_wrap(const NibOtpInput(length: 4, obscureText: true)));
      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('●'), findsNWidgets(2));
    });

    testWidgets('enabled: false ignores input', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(_wrap(NibOtpInput(
        length: 4,
        enabled: false,
        onChanged: changes.add,
      )));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });

    testWidgets('external controller sets and clears the value', (tester) async {
      final controller = NibOtpController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(NibOtpInput(length: 4, controller: controller)));

      controller.setValue('99');
      await tester.pump();
      expect(find.text('9'), findsNWidgets(2));

      controller.clear();
      await tester.pump();
      expect(find.text('9'), findsNothing);
    });

    testWidgets('controller reflects user typing', (tester) async {
      final controller = NibOtpController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(NibOtpInput(length: 4, controller: controller)));
      await tester.enterText(find.byType(TextField), '77');
      await tester.pump();
      expect(controller.value, '77');
    });

    testWidgets('builds no NibMotion when animated is false', (tester) async {
      await tester.pumpWidget(_wrap(const NibOtpInput(length: 4)));
      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('animates filled cells when animated', (tester) async {
      await tester.pumpWidget(_wrap(const NibOtpInput(length: 4, animated: true)));
      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();
      expect(find.byType(NibMotion), findsWidgets);
    });

    testWidgets('exposes the oneTimeCode autofill hint for SMS autofill',
        (tester) async {
      await tester.pumpWidget(_wrap(const NibOtpInput(length: 4)));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
    });

    testWidgets('system mode has no on-screen keypad', (tester) async {
      await tester.pumpWidget(_wrap(const NibOtpInput(length: 4)));
      expect(find.byType(NibOtpKeypad), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    group('onScreen keyboard', () {
      testWidgets('renders a keypad and no system TextField', (tester) async {
        await tester.pumpWidget(_wrap(const NibOtpInput(
          length: 4,
          keyboard: NibOtpKeyboard.onScreen,
        )));
        expect(find.byType(NibOtpKeypad), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        // Digits 0–9 present as keys.
        for (final d in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) {
          expect(find.widgetWithText(NibOtpKey, d), findsOneWidget);
        }
      });

      testWidgets('tapping keys fills cells and completes', (tester) async {
        String? completed;
        await tester.pumpWidget(_wrap(NibOtpInput(
          length: 4,
          keyboard: NibOtpKeyboard.onScreen,
          onCompleted: (v) => completed = v,
        )));

        for (final d in ['1', '2', '3', '4']) {
          await tester.tap(find.widgetWithText(NibOtpKey, d));
          await tester.pump();
        }
        expect(completed, '1234');
      });

      testWidgets('backspace removes the last digit', (tester) async {
        final controller = NibOtpController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(_wrap(NibOtpInput(
          length: 4,
          keyboard: NibOtpKeyboard.onScreen,
          controller: controller,
        )));

        await tester.tap(find.widgetWithText(NibOtpKey, '7'));
        await tester.tap(find.widgetWithText(NibOtpKey, '8'));
        await tester.pump();
        expect(controller.value, '78');

        await tester.tap(find.widgetWithIcon(NibOtpKey, Icons.backspace_outlined));
        await tester.pump();
        expect(controller.value, '7');
      });

      testWidgets('does not exceed length', (tester) async {
        final controller = NibOtpController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(_wrap(NibOtpInput(
          length: 3,
          keyboard: NibOtpKeyboard.onScreen,
          controller: controller,
        )));
        for (final d in ['1', '2', '3', '4', '5']) {
          await tester.tap(find.widgetWithText(NibOtpKey, d));
          await tester.pump();
        }
        expect(controller.value, '123');
      });

      testWidgets('shows a default confirm key that fires onConfirm',
          (tester) async {
        String? confirmed;
        await tester.pumpWidget(_wrap(NibOtpInput(
          length: 4,
          keyboard: NibOtpKeyboard.onScreen,
          onConfirm: (v) => confirmed = v,
        )));
        await tester.tap(find.widgetWithText(NibOtpKey, '5'));
        await tester.pump();
        await tester.tap(find.widgetWithIcon(NibOtpKey, Icons.check_rounded));
        await tester.pump();
        expect(confirmed, '5');
      });

      testWidgets('a custom confirmButton replaces the default key',
          (tester) async {
        await tester.pumpWidget(_wrap(NibOtpInput(
          length: 4,
          keyboard: NibOtpKeyboard.onScreen,
          confirmButton: const Text('GO'),
        )));
        expect(find.text('GO'), findsOneWidget);
        expect(find.widgetWithIcon(NibOtpKey, Icons.check_rounded), findsNothing);
      });

      testWidgets('showConfirmButton: false hides the confirm slot',
          (tester) async {
        await tester.pumpWidget(_wrap(const NibOtpInput(
          length: 4,
          keyboard: NibOtpKeyboard.onScreen,
          showConfirmButton: false,
        )));
        expect(find.widgetWithIcon(NibOtpKey, Icons.check_rounded), findsNothing);
      });

      testWidgets('loading shows a loader, hides confirm, and blocks keys',
          (tester) async {
        final controller = NibOtpController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(_wrap(NibOtpInput(
          length: 4,
          keyboard: NibOtpKeyboard.onScreen,
          loading: true,
          controller: controller,
        )));
        expect(find.byType(NibCircularLoader), findsOneWidget);
        expect(find.widgetWithIcon(NibOtpKey, Icons.check_rounded), findsNothing);

        // Keys are inert while loading.
        await tester.tap(find.widgetWithText(NibOtpKey, '1'));
        await tester.pump();
        expect(controller.value, '');
      });

      testWidgets('applies keypad style (key colour + size)', (tester) async {
        await tester.pumpWidget(_wrap(const NibOtpInput(
          length: 4,
          keyboard: NibOtpKeyboard.onScreen,
          keypadStyle: NibOtpKeypadStyle(
            keyColor: Color(0xFF123456),
            keyWidth: 80,
            keyHeight: 60,
          ),
        )));
        final key = tester.widget<NibOtpKey>(find.widgetWithText(NibOtpKey, '1'));
        expect(key.color, const Color(0xFF123456));
        expect(key.width, 80);
        expect(key.height, 60);
      });
    });

    testWidgets('loading greys out and disables the system-mode field',
        (tester) async {
      await tester.pumpWidget(_wrap(const NibOtpInput(length: 4, loading: true)));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });
  });

  group('NibCircularLoader', () {
    testWidgets('renders and paints without error', (tester) async {
      await tester.pumpWidget(_wrap(const NibCircularLoader(
        size: 48,
        child: Icon(Icons.lock_outline),
      )));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(NibCircularLoader), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
