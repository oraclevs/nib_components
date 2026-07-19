import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

Widget _wrap(Widget child, {double width = 320}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  group('NibTextarea — basic render', () {
    testWidgets(
      'renders with an internal controller and no NibMotion by default',
      (tester) async {
        await tester.pumpWidget(_wrap(NibTextarea()));
        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(NibMotion), findsNothing);
      },
    );

    testWidgets('shows label above the field when set', (tester) async {
      await tester.pumpWidget(_wrap(NibTextarea(label: 'Bio')));
      expect(find.text('Bio'), findsOneWidget);
    });

    testWidgets('shows placeholder as hint text', (tester) async {
      await tester.pumpWidget(_wrap(NibTextarea(placeholder: 'Tell us more')));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintText, 'Tell us more');
    });

    testWidgets('does not overflow in a narrow width', (tester) async {
      await tester.pumpWidget(_wrap(NibTextarea(label: 'Bio'), width: 120));
      expect(tester.takeException(), isNull);
    });
  });

  group('NibTextarea — value & controller', () {
    testWidgets(
      'onChanged fires as the user types with the internal controller',
      (tester) async {
        String? got;
        await tester.pumpWidget(_wrap(NibTextarea(onChanged: (v) => got = v)));
        await tester.enterText(find.byType(TextField), 'hello');
        expect(got, 'hello');
      },
    );

    testWidgets('initialValue seeds the internal controller', (tester) async {
      await tester.pumpWidget(_wrap(NibTextarea(initialValue: 'seeded')));
      expect(find.text('seeded'), findsOneWidget);
    });

    testWidgets(
      'an external controller drives the field and is not disposed by the widget',
      (tester) async {
        final controller = TextEditingController(text: 'external');
        await tester.pumpWidget(_wrap(NibTextarea(controller: controller)));
        expect(find.text('external'), findsOneWidget);

        controller.text = 'changed';
        await tester.pump();
        expect(find.text('changed'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        // Would throw if the widget had disposed an externally-owned controller.
        expect(() => controller.text, returnsNormally);
        controller.dispose();
      },
    );
  });

  group('NibTextarea — auto-grow bounds', () {
    testWidgets('passes minLines/maxLines through to the native TextField', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(NibTextarea(minLines: 2, maxLines: 5)));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.minLines, 2);
      expect(field.maxLines, 5);
    });

    testWidgets('defaults to minLines: 3 and unbounded maxLines', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(NibTextarea()));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.minLines, 3);
      expect(field.maxLines, isNull);
    });

    testWidgets('grows taller with more wrapped lines of text', (tester) async {
      await tester.pumpWidget(_wrap(NibTextarea(minLines: 2), width: 120));
      final shortHeight = tester.getSize(find.byType(NibTextarea)).height;

      await tester.enterText(
        find.byType(TextField),
        'one two three four five six seven eight nine ten eleven twelve',
      );
      await tester.pumpAndSettle();
      final tallHeight = tester.getSize(find.byType(NibTextarea)).height;

      expect(tallHeight, greaterThan(shortHeight));
    });
  });

  group('NibTextarea — maxLength & counter', () {
    testWidgets('limits input to maxLength', (tester) async {
      String? got;
      await tester.pumpWidget(
        _wrap(NibTextarea(maxLength: 5, onChanged: (v) => got = v)),
      );
      await tester.enterText(find.byType(TextField), 'abcdefgh');
      expect(got, 'abcde');
    });

    testWidgets('showCounter renders current/max', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibTextarea(maxLength: 10, showCounter: true, initialValue: 'abc'),
        ),
      );
      expect(find.text('3/10'), findsOneWidget);
    });

    testWidgets('showCounter without maxLength renders just the count', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NibTextarea(showCounter: true, initialValue: 'abc')),
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('counter is absent when showCounter is false', (tester) async {
      await tester.pumpWidget(
        _wrap(NibTextarea(maxLength: 10, initialValue: 'abc')),
      );
      expect(find.text('3/10'), findsNothing);
    });
  });

  group('NibTextarea — helper & error text', () {
    testWidgets('shows helperText when there is no error', (tester) async {
      await tester.pumpWidget(
        _wrap(NibTextarea(helperText: 'Max 500 characters')),
      );
      expect(find.text('Max 500 characters'), findsOneWidget);
    });

    testWidgets('errorText overrides helperText', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibTextarea(
            helperText: 'Max 500 characters',
            errorText: 'Bio is required',
          ),
        ),
      );
      expect(find.text('Bio is required'), findsOneWidget);
      expect(find.text('Max 500 characters'), findsNothing);
    });
  });

  group('NibTextarea — disabled', () {
    testWidgets('disabled field ignores input and is not focusable', (
      tester,
    ) async {
      String? got;
      await tester.pumpWidget(
        _wrap(NibTextarea(disabled: true, onChanged: (v) => got = v)),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
      expect(got, isNull);
    });
  });

  group('NibTextarea — style escape hatches', () {
    testWidgets('labelStyle merges onto the default label style', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibTextarea(
            label: 'Bio',
            labelStyle: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.red,
            ),
          ),
        ),
      );
      final style = tester.widget<Text>(find.text('Bio')).style!;
      expect(style.fontStyle, FontStyle.italic);
      expect(style.color, Colors.red);
      // Untouched default (weight) survives the merge.
      expect(style.fontWeight, FontWeight.w600);
    });

    testWidgets('hintStyle merges onto the default hint style', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibTextarea(
            placeholder: 'Tell us more',
            hintStyle: TextStyle(color: Colors.red),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintStyle?.color, Colors.red);
      expect(field.decoration?.hintStyle?.fontSize, 14);
    });

    testWidgets('style merges onto the default input text style', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibTextarea(
            style: TextStyle(color: Colors.red, fontFamily: 'Mono'),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style?.color, Colors.red);
      expect(field.style?.fontFamily, 'Mono');
      expect(field.style?.fontSize, 14);
    });

    testWidgets('helperStyle and errorStyle style independently', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibTextarea(
            helperText: 'Helper',
            helperStyle: TextStyle(color: Colors.blue),
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('Helper')).style?.color,
        Colors.blue,
      );

      await tester.pumpWidget(
        _wrap(
          NibTextarea(
            helperText: 'Helper',
            helperStyle: TextStyle(color: Colors.blue),
            errorText: 'Oops',
            errorStyle: TextStyle(color: Colors.orange),
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('Oops')).style?.color,
        Colors.orange,
      );
    });

    testWidgets('counterStyle merges onto the default counter style', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibTextarea(
            showCounter: true,
            initialValue: 'abc',
            counterStyle: TextStyle(color: Colors.purple),
          ),
        ),
      );
      expect(tester.widget<Text>(find.text('3')).style?.color, Colors.purple);
    });

    testWidgets('labelSpacing widens the gap between label and field', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(NibTextarea(label: 'Bio')));
      final defaultGap =
          tester.getTopLeft(find.byType(TextField)).dy -
          tester.getBottomLeft(find.text('Bio')).dy;

      await tester.pumpWidget(
        _wrap(NibTextarea(label: 'Bio', labelSpacing: 24)),
      );
      final widenedGap =
          tester.getTopLeft(find.byType(TextField)).dy -
          tester.getBottomLeft(find.text('Bio')).dy;

      expect(widenedGap, greaterThan(defaultGap));
    });

    testWidgets('footerSpacing widens the gap between field and helper text', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(NibTextarea(helperText: 'Helper')));
      final defaultGap =
          tester.getTopLeft(find.text('Helper')).dy -
          tester.getBottomLeft(find.byType(TextField)).dy;

      await tester.pumpWidget(
        _wrap(NibTextarea(helperText: 'Helper', footerSpacing: 24)),
      );
      final widenedGap =
          tester.getTopLeft(find.text('Helper')).dy -
          tester.getBottomLeft(find.byType(TextField)).dy;

      expect(widenedGap, greaterThan(defaultGap));
    });
  });

  group('NibTextarea — validator', () {
    testWidgets(
      'onUserInteraction (default) hides the error until first interaction',
      (tester) async {
        await tester.pumpWidget(
          _wrap(NibTextarea(validator: NibValidators.required())),
        );
        expect(find.text('This field is required.'), findsNothing);

        await tester.enterText(find.byType(TextField), 'x');
        await tester.enterText(find.byType(TextField), '');
        await tester.pump();
        expect(find.text('This field is required.'), findsOneWidget);
      },
    );

    testWidgets('AutovalidateMode.always shows the error immediately', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibTextarea(
            validator: NibValidators.required(),
            autovalidateMode: AutovalidateMode.always,
          ),
        ),
      );
      expect(find.text('This field is required.'), findsOneWidget);
    });

    testWidgets('AutovalidateMode.disabled never shows the error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibTextarea(
            validator: NibValidators.required(),
            autovalidateMode: AutovalidateMode.disabled,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'x');
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('This field is required.'), findsNothing);
    });

    testWidgets('explicit errorText takes precedence over the validator', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibTextarea(
            errorText: 'Server says no',
            autovalidateMode: AutovalidateMode.always,
            validator: NibValidators.required(),
          ),
        ),
      );
      expect(find.text('Server says no'), findsOneWidget);
      expect(find.text('This field is required.'), findsNothing);
    });
  });

  group('NibTextarea — Form integration', () {
    testWidgets(
      'Form.validate() shows an untouched field\'s error immediately',
      (tester) async {
        final formKey = GlobalKey<FormState>();
        await tester.pumpWidget(
          _wrap(
            Form(
              key: formKey,
              child: NibTextarea(
                label: 'Bio',
                validator: NibValidators.required(),
              ),
            ),
          ),
        );
        expect(find.text('This field is required.'), findsNothing);

        final isValid = formKey.currentState!.validate();
        await tester.pump();

        expect(isValid, isFalse);
        expect(find.text('This field is required.'), findsOneWidget);
      },
    );

    testWidgets('Form.save() calls onSaved with the current text', (
      tester,
    ) async {
      String? saved;
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: NibTextarea(
              initialValue: 'hello there',
              onSaved: (v) => saved = v,
            ),
          ),
        ),
      );

      formKey.currentState!.save();
      expect(saved, 'hello there');
    });

    testWidgets('Form.reset() restores the initial text and clears the error', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: NibTextarea(
              initialValue: 'a valid bio',
              validator: NibValidators.minLength(5),
              autovalidateMode: AutovalidateMode.always,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pump();
      expect(find.text('Must be at least 5 characters.'), findsOneWidget);

      formKey.currentState!.reset();
      await tester.pump();

      expect(find.text('a valid bio'), findsOneWidget);
      expect(find.text('Must be at least 5 characters.'), findsNothing);
    });

    testWidgets(
      'a GlobalKey<FormFieldState> can validate a single field directly',
      (tester) async {
        final fieldKey = GlobalKey<FormFieldState<String>>();
        await tester.pumpWidget(
          _wrap(
            NibTextarea(key: fieldKey, validator: NibValidators.required()),
          ),
        );

        expect(fieldKey.currentState!.validate(), isFalse);
        await tester.pump();
        expect(find.text('This field is required.'), findsOneWidget);
      },
    );
  });

  group('NibTextarea — animated', () {
    testWidgets('animated:false never builds NibMotion, even with an error', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(NibTextarea(errorText: 'Required')));
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('animated:true wraps the error/helper row in NibMotion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NibTextarea(animated: true, errorText: 'Required')),
      );
      expect(find.byType(NibMotion), findsOneWidget);
    });

    testWidgets('animated:true with no helper/error text builds no NibMotion', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(NibTextarea(animated: true)));
      expect(find.byType(NibMotion), findsNothing);
    });
  });
}
