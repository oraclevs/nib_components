import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibAnim, NibMotion, NibMotionList, NibPresence;

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: const [NibTheme.light]),
    home: Scaffold(body: Center(child: SizedBox(width: 320, child: child))),
  );
}

const _options = [
  NibSelectOption(value: 'apple', label: 'Apple'),
  NibSelectOption(value: 'banana', label: 'Banana', disabled: true),
  NibSelectOption(value: 'cherry', label: 'Cherry'),
];

const _groups = [
  NibSelectGroup(
    label: 'Citrus',
    options: [
      NibSelectOption(value: 'lemon', label: 'Lemon'),
      NibSelectOption(value: 'lime', label: 'Lime'),
    ],
  ),
  NibSelectGroup(
    label: 'Berries',
    options: [
      NibSelectOption(value: 'straw', label: 'Strawberry'),
    ],
  ),
];

Future<void> _key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pump();
}

Finder _trigger() => find.byType(InkWell).first;

void main() {
  testWidgets('closed by default: placeholder shown, options hidden', (tester) async {
    await tester.pumpWidget(
      _wrap(const NibSelect<String>(options: _options, placeholder: 'Pick fruit')),
    );
    expect(find.text('Pick fruit'), findsOneWidget);
    expect(find.text('Apple'), findsNothing);
  });

  testWidgets('tapping the trigger opens the dropdown with all options', (tester) async {
    await tester.pumpWidget(_wrap(const NibSelect<String>(options: _options)));
    await tester.tap(_trigger());
    await tester.pump();
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Banana'), findsOneWidget);
    expect(find.text('Cherry'), findsOneWidget);
  });

  testWidgets('single-select: tapping an option selects it, closes, fires onChanged', (tester) async {
    String? changed;
    await tester.pumpWidget(
      _wrap(NibSelect<String>(options: _options, onChanged: (v) => changed = v)),
    );
    await tester.tap(_trigger());
    await tester.pump();
    await tester.tap(find.text('Cherry'));
    await tester.pump();
    expect(changed, 'cherry');
    // Dropdown closed: only the trigger's label remains.
    expect(find.text('Apple'), findsNothing);
    expect(find.text('Cherry'), findsOneWidget); // now shown in the trigger
  });

  testWidgets('multi-select: tapping toggles, stays open, fires onSelectionChanged', (tester) async {
    List<String>? selection;
    await tester.pumpWidget(
      _wrap(NibSelect<String>(
        options: _options,
        multiSelect: true,
        onSelectionChanged: (v) => selection = v,
      )),
    );
    await tester.tap(_trigger());
    await tester.pump();
    await tester.tap(find.text('Apple'));
    await tester.pump();
    await tester.tap(find.text('Cherry'));
    await tester.pump();
    expect(selection, ['apple', 'cherry']);
    // Still open after two picks.
    expect(find.text('Banana'), findsOneWidget);
  });

  testWidgets('disabled option cannot be selected', (tester) async {
    String? changed;
    await tester.pumpWidget(
      _wrap(NibSelect<String>(options: _options, onChanged: (v) => changed = v)),
    );
    await tester.tap(_trigger());
    await tester.pump();
    await tester.tap(find.text('Banana')); // disabled
    await tester.pump();
    expect(changed, isNull);
    expect(find.text('Apple'), findsOneWidget); // still open
  });

  testWidgets('disabled select does not open', (tester) async {
    await tester.pumpWidget(_wrap(const NibSelect<String>(options: _options, disabled: true)));
    await tester.tap(_trigger());
    await tester.pump();
    expect(find.text('Apple'), findsNothing);
  });

  testWidgets('grouped options render section headers', (tester) async {
    await tester.pumpWidget(_wrap(const NibSelect<String>(groups: _groups)));
    await tester.tap(_trigger());
    await tester.pump();
    expect(find.text('Citrus'), findsOneWidget);
    expect(find.text('Berries'), findsOneWidget);
    expect(find.text('Lemon'), findsOneWidget);
    expect(find.text('Strawberry'), findsOneWidget);
  });

  testWidgets('searchable: typing filters options (and empties groups)', (tester) async {
    await tester.pumpWidget(_wrap(const NibSelect<String>(groups: _groups, searchable: true)));
    await tester.tap(_trigger());
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'lem');
    await tester.pump();
    expect(find.text('Lemon'), findsOneWidget);
    expect(find.text('Lime'), findsNothing);
    expect(find.text('Strawberry'), findsNothing);
    // The now-empty Berries group's header is gone; Citrus stays.
    expect(find.text('Berries'), findsNothing);
    expect(find.text('Citrus'), findsOneWidget);
  });

  testWidgets('searchable: no matches shows the no-results body', (tester) async {
    await tester.pumpWidget(_wrap(const NibSelect<String>(options: _options, searchable: true)));
    await tester.tap(_trigger());
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No results'), findsOneWidget);
  });

  testWidgets('keyboard: enter activates the pre-highlighted first enabled option', (tester) async {
    String? changed;
    await tester.pumpWidget(
      _wrap(NibSelect<String>(options: _options, onChanged: (v) => changed = v)),
    );
    await tester.tap(_trigger());
    await tester.pump();
    // On open, the first enabled option (Apple) is pre-highlighted.
    await _key(tester, LogicalKeyboardKey.enter);
    expect(changed, 'apple');
  });

  testWidgets('keyboard: arrow-down moves highlight past the disabled option', (tester) async {
    String? changed;
    await tester.pumpWidget(
      _wrap(NibSelect<String>(options: _options, onChanged: (v) => changed = v)),
    );
    await tester.tap(_trigger());
    await tester.pump();
    // Apple(0) pre-highlighted; Banana(1) disabled; arrow-down -> Cherry(2).
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(changed, 'cherry');
  });

  testWidgets('keyboard: escape closes the dropdown', (tester) async {
    await tester.pumpWidget(_wrap(const NibSelect<String>(options: _options)));
    await tester.tap(_trigger());
    await tester.pump();
    expect(find.text('Apple'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.text('Apple'), findsNothing);
  });

  testWidgets('clearable: clears the selection and fires onChanged(null)', (tester) async {
    String? changed = 'seed';
    await tester.pumpWidget(
      _wrap(NibSelect<String>(
        options: _options,
        value: 'apple',
        clearable: true,
        onChanged: (v) => changed = v,
      )),
    );
    expect(find.text('Apple'), findsOneWidget); // initial value in trigger
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(changed, isNull);
    expect(find.text('Apple'), findsNothing);
  });

  testWidgets('initial value is shown in the trigger', (tester) async {
    await tester.pumpWidget(
      _wrap(const NibSelect<String>(options: _options, value: 'cherry')),
    );
    expect(find.text('Cherry'), findsOneWidget);
  });

  testWidgets('animated: false builds no NibMotion', (tester) async {
    await tester.pumpWidget(
      _wrap(const NibSelect<String>(key: ValueKey('a'), options: _options, animated: false)),
    );
    await tester.tap(_trigger());
    await tester.pump();
    expect(find.byType(NibMotion), findsNothing);
  });

  testWidgets('animated: true builds a NibMotion', (tester) async {
    await tester.pumpWidget(
      _wrap(const NibSelect<String>(key: ValueKey('b'), options: _options, animated: true)),
    );
    await tester.tap(_trigger());
    await tester.pump();
    expect(find.byType(NibMotion), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('asserts exactly one of options/groups', (tester) async {
    expect(() => NibSelect<String>(), throwsAssertionError);
    expect(
      () => NibSelect<String>(options: _options, groups: _groups),
      throwsAssertionError,
    );
  });

  testWidgets('external controller drives and reads selection', (tester) async {
    final controller = NibSelectController<String>();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(NibSelect<String>(options: _options, controller: controller)),
    );
    controller.selectOnly('cherry');
    await tester.pump();
    expect(find.text('Cherry'), findsOneWidget);
    expect(controller.selectedValue, 'cherry');
  });

  group('animation', () {
    testWidgets('animated + NibSelectAnimation.none builds no motion', (tester) async {
      await tester.pumpWidget(_wrap(const NibSelect<String>(
        options: _options,
        animated: true,
        animation: NibSelectAnimation.none,
      )));
      await tester.tap(_trigger());
      await tester.pump();
      expect(find.text('Apple'), findsOneWidget); // still opens
      expect(find.byType(NibMotion), findsNothing);
      expect(find.byType(NibPresence), findsNothing);
    });

    testWidgets('animated wraps the dropdown in NibPresence for exit', (tester) async {
      await tester.pumpWidget(_wrap(const NibSelect<String>(
        options: _options,
        animated: true,
        animation: NibSelectAnimation.slide,
      )));
      await tester.tap(_trigger());
      await tester.pump();
      expect(find.byType(NibPresence), findsOneWidget);
      expect(find.byType(NibMotion), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('enterFrom override still builds motion', (tester) async {
      await tester.pumpWidget(_wrap(const NibSelect<String>(
        options: _options,
        animated: true,
        enterFrom: NibAnim(opacity: 0, x: 20),
      )));
      await tester.tap(_trigger());
      await tester.pump();
      expect(find.byType(NibMotion), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('staggerOptions builds a NibMotionList', (tester) async {
      await tester.pumpWidget(_wrap(const NibSelect<String>(
        options: _options,
        animated: true,
        staggerOptions: true,
      )));
      await tester.tap(_trigger());
      await tester.pump();
      expect(find.byType(NibMotionList), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('default (no stagger) uses a plain list, no NibMotionList', (tester) async {
      await tester.pumpWidget(_wrap(const NibSelect<String>(options: _options, animated: true)));
      await tester.tap(_trigger());
      await tester.pump();
      expect(find.byType(NibMotionList), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('animated close defers overlay removal until the exit finishes', (tester) async {
      await tester.pumpWidget(_wrap(const NibSelect<String>(
        options: _options,
        animated: true,
        animation: NibSelectAnimation.fade,
      )));
      await tester.tap(_trigger());
      await tester.pumpAndSettle(); // let the enter animation finish
      expect(find.text('Apple'), findsOneWidget);

      // Close: the dropdown must linger (playing its exit) before unmounting.
      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pump(); // one frame — exit just started
      expect(find.text('Apple'), findsOneWidget); // still animating out

      // Past the exit duration (~140ms tween + buffer) it's gone.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsNothing);
    });

    testWidgets('unanimated close removes the dropdown immediately', (tester) async {
      await tester.pumpWidget(_wrap(const NibSelect<String>(options: _options)));
      await tester.tap(_trigger());
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Apple'), findsNothing);
    });
  });
}
