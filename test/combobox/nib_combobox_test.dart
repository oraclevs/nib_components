import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: const [NibTheme.light]),
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, child: child)),
    ),
  );
}

const _options = [
  NibComboboxOption(value: 'apple', label: 'Apple'),
  NibComboboxOption(value: 'banana', label: 'Banana', disabled: true),
  NibComboboxOption(value: 'cherry', label: 'Cherry'),
];

Future<void> _key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyDownEvent(k);
  await tester.sendKeyUpEvent(k);
  await tester.pump();
}

void main() {
  testWidgets('closed by default: options not shown', (tester) async {
    await tester.pumpWidget(
      _wrap(const NibCombobox<String>(options: _options)),
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Apple'), findsNothing);
    expect(find.text('Cherry'), findsNothing);
  });

  testWidgets('tapping the field opens the dropdown with all options', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const NibCombobox<String>(options: _options)),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Banana'), findsOneWidget);
    expect(find.text('Cherry'), findsOneWidget);
  });

  testWidgets('typing filters the option list', (tester) async {
    await tester.pumpWidget(
      _wrap(const NibCombobox<String>(options: _options)),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'err');
    await tester.pump();
    expect(find.text('Cherry'), findsOneWidget);
    expect(find.text('Apple'), findsNothing);
  });

  testWidgets('tapping an option selects it and closes (single-select)', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(
      _wrap(
        NibCombobox<String>(options: _options, onChanged: (v) => changed = v),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.text('Cherry'));
    await tester.pump();

    expect(changed, 'cherry');
    // dropdown closed: only the field's 'Cherry' remains (banana gone)
    expect(find.text('Banana'), findsNothing);
    expect(find.text('Cherry'), findsOneWidget);
  });

  testWidgets('arrow-down skips the disabled option, enter selects', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(
      _wrap(
        NibCombobox<String>(options: _options, onChanged: (v) => changed = v),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    // highlight starts on Apple; down skips disabled Banana -> Cherry
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.enter);

    expect(changed, 'cherry');
  });

  testWidgets('escape closes without changing selection', (tester) async {
    String? changed;
    await tester.pumpWidget(
      _wrap(
        NibCombobox<String>(options: _options, onChanged: (v) => changed = v),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.text('Apple'), findsOneWidget);

    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.text('Apple'), findsNothing);
    expect(changed, isNull);
  });

  testWidgets('tapping the barrier closes the dropdown', (tester) async {
    await tester.pumpWidget(
      _wrap(const NibCombobox<String>(options: _options)),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.text('Apple'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(find.text('Apple'), findsNothing);
  });

  testWidgets('selection-only mode reverts the field text on escape', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const NibCombobox<String>(options: _options)),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.text('Apple'));
    await tester.pump();
    expect(find.text('Apple'), findsOneWidget); // in the field now

    // reopen, type garbage, escape -> field should revert to 'Apple'
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No results'), findsOneWidget);

    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.text('Apple'), findsOneWidget);
  });

  testWidgets('free-text mode commits typed text via onFreeTextSubmitted', (
    tester,
  ) async {
    String? freeText;
    await tester.pumpWidget(
      _wrap(
        NibCombobox<String>(
          options: _options,
          allowFreeText: true,
          onFreeTextSubmitted: (t) => freeText = t,
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'custom value');
    await tester.pump();
    await _key(tester, LogicalKeyboardKey.enter);

    expect(freeText, 'custom value');
  });

  testWidgets('multi-select toggles chips and keeps the dropdown open', (
    tester,
  ) async {
    List<String>? selection;
    await tester.pumpWidget(
      _wrap(
        NibCombobox<String>(
          options: _options,
          multiSelect: true,
          onSelectionChanged: (s) => selection = s,
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.text('Apple'));
    await tester.pump();
    // still open (Cherry option still visible)
    expect(find.text('Cherry'), findsWidgets);
    await tester.tap(find.text('Cherry').last);
    await tester.pump();

    expect(selection, ['apple', 'cherry']);
  });

  testWidgets('multi-select backspace on empty query removes the last chip', (
    tester,
  ) async {
    List<String>? selection;
    await tester.pumpWidget(
      _wrap(
        NibCombobox<String>(
          options: _options,
          multiSelect: true,
          onSelectionChanged: (s) => selection = s,
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.text('Apple'));
    await tester.pump();
    await tester.tap(find.text('Cherry').last);
    await tester.pump();
    expect(selection, ['apple', 'cherry']);

    await _key(tester, LogicalKeyboardKey.backspace);
    expect(selection, ['apple']);
  });

  testWidgets('clear button clears selection and query', (tester) async {
    String? changed = 'sentinel';
    await tester.pumpWidget(
      _wrap(
        NibCombobox<String>(options: _options, onChanged: (v) => changed = v),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.text('Apple'));
    await tester.pump();
    expect(find.text('Apple'), findsOneWidget);

    // clear button is the ✕ (Icons.close) in the field
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(changed, isNull);
    expect(find.text('Apple'), findsNothing);
  });

  testWidgets('disabled combobox does not open', (tester) async {
    await tester.pumpWidget(
      _wrap(const NibCombobox<String>(options: _options, disabled: true)),
    );
    await tester.tap(find.byType(TextField), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Apple'), findsNothing);
  });

  testWidgets(
    'async loader shows a spinner then results, latest request wins',
    (tester) async {
      final completers = <Completer<List<NibComboboxOption<String>>>>[];
      await tester.pumpWidget(
        _wrap(
          NibCombobox<String>(
            debounceDuration: const Duration(milliseconds: 100),
            asyncOptionsLoader: (query) {
              final c = Completer<List<NibComboboxOption<String>>>();
              completers.add(c);
              return c.future;
            },
          ),
        ),
      );

      // opening triggers an immediate load('')
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(completers, hasLength(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // type -> debounced second load
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 150));
      expect(completers, hasLength(2));

      // stale first response is ignored; only the latest applies
      completers[0].complete(const [
        NibComboboxOption(value: 'stale', label: 'Stale'),
      ]);
      completers[1].complete(const [
        NibComboboxOption(value: 'fresh', label: 'Fresh'),
      ]);
      await tester.pump();

      expect(find.text('Fresh'), findsOneWidget);
      expect(find.text('Stale'), findsNothing);
    },
  );

  testWidgets('animated: false builds zero NibMotion widgets', (tester) async {
    await tester.pumpWidget(
      _wrap(const NibCombobox<String>(options: _options)),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.byType(NibMotion), findsNothing);
  });

  testWidgets('animated: true wraps the dropdown in a NibMotion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const NibCombobox<String>(options: _options, animated: true)),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.byType(NibMotion), findsOneWidget);
  });

  testWidgets('narrow viewport does not overflow', (tester) async {
    tester.view.physicalSize = const Size(280, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        const NibCombobox<String>(
          options: [
            NibComboboxOption(
              value: 'a',
              label:
                  'A very long option label that could overflow a narrow field',
            ),
            NibComboboxOption(value: 'b', label: 'Beta'),
          ],
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  group('style escape hatches', () {
    testWidgets('backgroundColor overrides the field fill', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibCombobox<String>(
            options: _options,
            backgroundColor: Colors.orange,
          ),
        ),
      );
      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      expect((box.decoration as BoxDecoration).color, Colors.orange);
    });

    testWidgets('borderColor overrides the field border', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibCombobox<String>(
            options: _options,
            borderColor: Colors.orange,
          ),
        ),
      );
      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      expect(
        (box.decoration as BoxDecoration).border!.top.color,
        Colors.orange,
      );
    });

    testWidgets('borderWidth overrides the default 1px border', (tester) async {
      await tester.pumpWidget(
        _wrap(const NibCombobox<String>(options: _options, borderWidth: 3)),
      );
      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      expect((box.decoration as BoxDecoration).border!.top.width, 3);
    });

    testWidgets(
      'backgroundColor is not overridden by an ambient InputDecorationTheme fill',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: const [NibTheme.light],
              inputDecorationTheme: const InputDecorationTheme(
                filled: true,
                fillColor: Colors.red,
              ),
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: NibCombobox<String>(
                    options: _options,
                    backgroundColor: Colors.orange,
                  ),
                ),
              ),
            ),
          ),
        );
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.decoration?.filled, isFalse);
      },
    );

    testWidgets('hintStyle merges onto the default hint style', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibCombobox<String>(
            options: _options,
            placeholder: 'Pick one',
            hintStyle: const TextStyle(color: Colors.red),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintStyle?.color, Colors.red);
    });
  });
}
