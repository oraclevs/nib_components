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
  group('NibInput — basic render', () {
    testWidgets(
      'renders a single-line field with an internal controller, no NibMotion',
      (tester) async {
        await tester.pumpWidget(_wrap(NibInput()));
        expect(tester.takeException(), isNull);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.maxLines, 1);
        expect(find.byType(NibMotion), findsNothing);
      },
    );

    testWidgets('shows label above the field and placeholder as hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NibInput(label: 'Email', placeholder: 'you@example.com')),
      );
      expect(find.text('Email'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintText, 'you@example.com');
    });

    testWidgets('does not overflow in a narrow width with icons + clearable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibInput(
            label: 'Search',
            prefixIcon: Icon(Icons.search),
            suffixIcon: Icon(Icons.mic),
            clearable: true,
            initialValue: 'query',
          ),
          width: 140,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('NibInput — value & controller', () {
    testWidgets('onChanged fires as the user types', (tester) async {
      String? got;
      await tester.pumpWidget(_wrap(NibInput(onChanged: (v) => got = v)));
      await tester.enterText(find.byType(TextField), 'hi');
      expect(got, 'hi');
    });

    testWidgets('initialValue seeds the internal controller', (tester) async {
      await tester.pumpWidget(_wrap(NibInput(initialValue: 'seeded')));
      expect(find.text('seeded'), findsOneWidget);
    });

    testWidgets(
      'an external controller drives the field and is not disposed by the widget',
      (tester) async {
        final controller = TextEditingController(text: 'external');
        await tester.pumpWidget(_wrap(NibInput(controller: controller)));
        expect(find.text('external'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        expect(() => controller.text, returnsNormally);
        controller.dispose();
      },
    );

    testWidgets('onSubmitted fires on field submission', (tester) async {
      String? got;
      await tester.pumpWidget(_wrap(NibInput(onSubmitted: (v) => got = v)));
      await tester.enterText(find.byType(TextField), 'go');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(got, 'go');
    });
  });

  group('NibInput — icon slots & clearable', () {
    testWidgets('renders prefixIcon and suffixIcon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibInput(prefixIcon: Icon(Icons.search), suffixIcon: Icon(Icons.mic)),
        ),
      );
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets(
      'clear button is hidden while empty and shown once text is entered',
      (tester) async {
        await tester.pumpWidget(_wrap(NibInput(clearable: true)));
        expect(find.byIcon(Icons.close), findsNothing);

        await tester.enterText(find.byType(TextField), 'abc');
        await tester.pump();
        expect(find.byIcon(Icons.close), findsOneWidget);
      },
    );

    testWidgets('tapping clear empties the field and calls onChanged("")', (
      tester,
    ) async {
      String? got;
      await tester.pumpWidget(
        _wrap(
          NibInput(
            clearable: true,
            initialValue: 'abc',
            onChanged: (v) => got = v,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(got, '');
      expect(find.text('abc'), findsNothing);
    });
  });

  group('NibInput — helper & error text', () {
    testWidgets('shows helperText when there is no error', (tester) async {
      await tester.pumpWidget(
        _wrap(NibInput(helperText: 'We never share this')),
      );
      expect(find.text('We never share this'), findsOneWidget);
    });

    testWidgets('errorText overrides helperText', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibInput(
            helperText: 'We never share this',
            errorText: 'Email is invalid',
          ),
        ),
      );
      expect(find.text('Email is invalid'), findsOneWidget);
      expect(find.text('We never share this'), findsNothing);
    });
  });

  group('NibInput — disabled', () {
    testWidgets('disabled field ignores input', (tester) async {
      String? got;
      await tester.pumpWidget(
        _wrap(NibInput(disabled: true, onChanged: (v) => got = v)),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
      expect(got, isNull);
    });
  });

  group('NibInput — native passthrough', () {
    testWidgets(
      'obscureText/keyboardType/textInputAction reach the native TextField',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            NibInput(
              obscureText: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.search,
            ),
          ),
        );
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.obscureText, isTrue);
        expect(field.keyboardType, TextInputType.emailAddress);
        expect(field.textInputAction, TextInputAction.search);
      },
    );
  });

  group('NibInput — style escape hatches', () {
    testWidgets('labelStyle merges onto the default label style', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibInput(
            label: 'Email',
            labelStyle: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.red,
            ),
          ),
        ),
      );
      final style = tester.widget<Text>(find.text('Email')).style!;
      expect(style.fontStyle, FontStyle.italic);
      expect(style.color, Colors.red);
      expect(style.fontWeight, FontWeight.w600);
    });

    testWidgets('hintStyle merges onto the default hint style', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibInput(
            placeholder: 'you@example.com',
            hintStyle: TextStyle(color: Colors.red),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintStyle?.color, Colors.red);
    });

    testWidgets('style merges onto the default input text style', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibInput(
            style: TextStyle(color: Colors.red, fontFamily: 'Mono'),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style?.color, Colors.red);
      expect(field.style?.fontFamily, 'Mono');
    });

    testWidgets('helperStyle and errorStyle style independently', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibInput(
            helperText: 'Helper',
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

    testWidgets('labelSpacing widens the gap between label and field', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(NibInput(label: 'Email')));
      final defaultGap =
          tester.getTopLeft(find.byType(TextField)).dy -
          tester.getBottomLeft(find.text('Email')).dy;

      await tester.pumpWidget(
        _wrap(NibInput(label: 'Email', labelSpacing: 24)),
      );
      final widenedGap =
          tester.getTopLeft(find.byType(TextField)).dy -
          tester.getBottomLeft(find.text('Email')).dy;

      expect(widenedGap, greaterThan(defaultGap));
    });

    testWidgets('footerSpacing widens the gap between field and helper text', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(NibInput(helperText: 'Helper')));
      final defaultGap =
          tester.getTopLeft(find.text('Helper')).dy -
          tester.getBottomLeft(find.byType(TextField)).dy;

      await tester.pumpWidget(
        _wrap(NibInput(helperText: 'Helper', footerSpacing: 24)),
      );
      final widenedGap =
          tester.getTopLeft(find.text('Helper')).dy -
          tester.getBottomLeft(find.byType(TextField)).dy;

      expect(widenedGap, greaterThan(defaultGap));
    });

    testWidgets('backgroundColor overrides the box fill', (tester) async {
      await tester.pumpWidget(_wrap(NibInput(backgroundColor: Colors.orange)));
      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      expect((box.decoration as BoxDecoration).color, Colors.orange);
    });

    testWidgets('borderColor overrides the box border', (tester) async {
      await tester.pumpWidget(_wrap(NibInput(borderColor: Colors.orange)));
      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      expect(
        (box.decoration as BoxDecoration).border!.top.color,
        Colors.orange,
      );
    });

    testWidgets('borderWidth overrides the default 1px border', (tester) async {
      await tester.pumpWidget(_wrap(NibInput(borderWidth: 3)));
      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      expect((box.decoration as BoxDecoration).border!.top.width, 3);
    });

    testWidgets(
      'backgroundColor is not overridden by an ambient InputDecorationTheme fill',
      (tester) async {
        // Regression: a host app's global ThemeData(inputDecorationTheme:
        // InputDecorationTheme(filled: true, fillColor: ...)) used to bleed
        // through and paint a second, different-colored fill behind just the
        // typed text, because the inner TextField's own InputDecoration
        // didn't explicitly opt out of it.
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              inputDecorationTheme: const InputDecorationTheme(
                filled: true,
                fillColor: Colors.red,
              ),
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: NibInput(backgroundColor: Colors.orange),
                ),
              ),
            ),
          ),
        );
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.decoration?.filled, isFalse);
      },
    );
  });

  group('NibInput — validator', () {
    testWidgets(
      'onUserInteraction (default) hides the error until first interaction',
      (tester) async {
        await tester.pumpWidget(
          _wrap(NibInput(validator: NibValidators.required())),
        );
        expect(find.text('This field is required.'), findsNothing);

        await tester.enterText(find.byType(TextField), 'x');
        await tester.enterText(find.byType(TextField), '');
        await tester.pump();
        expect(find.text('This field is required.'), findsOneWidget);
      },
    );

    testWidgets(
      'AutovalidateMode.onUnfocus validates once the field loses focus, even without typing',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            Column(
              children: [
                NibInput(
                  validator: NibValidators.required(),
                  autovalidateMode: AutovalidateMode.onUnfocus,
                ),
                NibInput(),
              ],
            ),
          ),
        );
        expect(find.text('This field is required.'), findsNothing);

        await tester.tap(find.byType(TextField).first);
        await tester.pump();
        expect(find.text('This field is required.'), findsNothing);

        await tester.tap(find.byType(TextField).last);
        await tester.pump();
        expect(find.text('This field is required.'), findsOneWidget);
      },
    );

    testWidgets('AutovalidateMode.always shows the error immediately', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibInput(
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
          NibInput(
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
          NibInput(
            errorText: 'Server says no',
            autovalidateMode: AutovalidateMode.always,
            validator: NibValidators.required(),
          ),
        ),
      );
      expect(find.text('Server says no'), findsOneWidget);
      expect(find.text('This field is required.'), findsNothing);
    });

    testWidgets('a predefined email validator catches a bad address', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibInput(
            autovalidateMode: AutovalidateMode.always,
            validator: NibValidators.email(),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });
  });

  group('NibInput — Form integration', () {
    testWidgets(
      'Form.validate() shows an untouched field\'s error immediately',
      (tester) async {
        final formKey = GlobalKey<FormState>();
        await tester.pumpWidget(
          _wrap(
            Form(
              key: formKey,
              child: NibInput(
                label: 'Email',
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

    testWidgets('Form.validate() returns true and shows no error once valid', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: NibInput(
              initialValue: 'a@b.com',
              validator: NibValidators.compose([
                NibValidators.required(),
                NibValidators.email(),
              ]),
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('Form.save() calls onSaved with the current text', (
      tester,
    ) async {
      String? saved;
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: NibInput(initialValue: 'ada', onSaved: (v) => saved = v),
          ),
        ),
      );

      formKey.currentState!.save();
      expect(saved, 'ada');
    });

    testWidgets('Form.reset() restores the initial text and clears the error', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: NibInput(
              initialValue: 'ada@example.com',
              validator: NibValidators.email(),
              autovalidateMode: AutovalidateMode.always,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);

      formKey.currentState!.reset();
      await tester.pump();

      expect(find.text('ada@example.com'), findsOneWidget);
      expect(find.text('Enter a valid email address.'), findsNothing);
    });

    testWidgets(
      'a GlobalKey<FormFieldState> can validate a single field directly',
      (tester) async {
        final fieldKey = GlobalKey<FormFieldState<String>>();
        await tester.pumpWidget(
          _wrap(NibInput(key: fieldKey, validator: NibValidators.required())),
        );

        expect(fieldKey.currentState!.validate(), isFalse);
        await tester.pump();
        expect(find.text('This field is required.'), findsOneWidget);
      },
    );
  });

  group('NibInput — animated', () {
    testWidgets('animated:false never builds NibMotion, even with an error', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(NibInput(errorText: 'Required')));
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('animated:true wraps the error/helper row in NibMotion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NibInput(animated: true, errorText: 'Required')),
      );
      expect(find.byType(NibMotion), findsOneWidget);
    });
  });
}
