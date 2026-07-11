import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

Widget _wrap(Widget child) {
  return MaterialApp(theme: ThemeData(extensions: const [NibTheme.light]), home: Scaffold(body: child));
}

const _actions = [
  NibCommandAction(id: 'new-file', label: 'New File'),
  NibCommandAction(id: 'open-file', label: 'Open File'),
  NibCommandAction(id: 'go-to-line', label: 'Go to Line', disabled: true),
  NibCommandAction(
    id: 'change-theme',
    label: 'Change Theme',
    children: [
      NibCommandAction(id: 'theme-light', label: 'Light'),
      NibCommandAction(id: 'theme-dark', label: 'Dark'),
    ],
  ),
];

Future<void> _pressControlK(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

void main() {
  testWidgets('closed by default: no search field in the tree', (tester) async {
    await tester.pumpWidget(
      _wrap(const NibCommandPalette(actions: _actions, child: SizedBox())),
    );
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('opens on the default shortcut (Ctrl+K off-macOS)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(
      _wrap(const NibCommandPalette(actions: _actions, child: SizedBox())),
    );
    await _pressControlK(tester);
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('opens on Cmd+K when the default target platform is macOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(
      _wrap(const NibCommandPalette(actions: _actions, child: SizedBox())),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('opens programmatically via controller.open(), no key events', (tester) async {
    final controller = NibCommandPaletteController();
    await tester.pumpWidget(
      _wrap(NibCommandPalette(actions: _actions, controller: controller, child: const SizedBox())),
    );
    controller.open();
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('typing filters the visible action list', (tester) async {
    final controller = NibCommandPaletteController();
    await tester.pumpWidget(
      _wrap(NibCommandPalette(actions: _actions, controller: controller, child: const SizedBox())),
    );
    controller.open();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'theme');
    await tester.pump();

    expect(find.text('Change Theme'), findsOneWidget);
    expect(find.text('New File'), findsNothing);
    expect(find.text('Open File'), findsNothing);
  });

  testWidgets('enter on the highlighted leaf action selects it and closes', (tester) async {
    NibCommandAction? selected;
    final controller = NibCommandPaletteController();
    await tester.pumpWidget(
      _wrap(
        NibCommandPalette(
          actions: _actions,
          controller: controller,
          onActionSelected: (a) => selected = a,
          child: const SizedBox(),
        ),
      ),
    );
    controller.open();
    await tester.pump();

    // Default highlight is the first enabled action: 'New File'.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected?.id, 'new-file');
    expect(controller.isOpen, isFalse);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('arrow down moves highlight to the next enabled action, skipping disabled', (
    tester,
  ) async {
    NibCommandAction? selected;
    final controller = NibCommandPaletteController();
    await tester.pumpWidget(
      _wrap(
        NibCommandPalette(
          actions: _actions,
          controller: controller,
          onActionSelected: (a) => selected = a,
          child: const SizedBox(),
        ),
      ),
    );
    controller.open();
    await tester.pump();

    // New File -> Open File -> (skip disabled Go to Line) -> Change Theme.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    // Change Theme has children -> drills in rather than firing selection.
    expect(selected, isNull);
    expect(controller.isOpen, isTrue);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('arrow up from the first item wraps to the last enabled action', (tester) async {
    NibCommandAction? selected;
    final controller = NibCommandPaletteController();
    await tester.pumpWidget(
      _wrap(
        NibCommandPalette(
          actions: _actions,
          controller: controller,
          onActionSelected: (a) => selected = a,
          child: const SizedBox(),
        ),
      ),
    );
    controller.open();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    // Wraps past disabled 'Go to Line' straight to 'Change Theme' (a branch).
    expect(selected, isNull);
    expect(controller.isOpen, isTrue);
    expect(find.text('Light'), findsOneWidget);
  });

  testWidgets('a disabled action is inert on tap', (tester) async {
    NibCommandAction? selected;
    final controller = NibCommandPaletteController();
    await tester.pumpWidget(
      _wrap(
        NibCommandPalette(
          actions: _actions,
          controller: controller,
          onActionSelected: (a) => selected = a,
          child: const SizedBox(),
        ),
      ),
    );
    controller.open();
    await tester.pump();

    await tester.tap(find.text('Go to Line'));
    await tester.pump();

    expect(selected, isNull);
    expect(controller.isOpen, isTrue);
  });

  testWidgets('escape pops one drill-down level, then closes on a second press', (tester) async {
    final controller = NibCommandPaletteController();
    await tester.pumpWidget(
      _wrap(NibCommandPalette(actions: _actions, controller: controller, child: const SizedBox())),
    );
    controller.open();
    await tester.pump();

    await tester.tap(find.text('Change Theme'));
    await tester.pump();
    expect(find.text('Light'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(controller.isOpen, isTrue);
    expect(find.text('Light'), findsNothing);
    expect(find.text('Change Theme'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(controller.isOpen, isFalse);
  });

  testWidgets('tapping the barrier closes the palette', (tester) async {
    final controller = NibCommandPaletteController();
    await tester.pumpWidget(
      _wrap(NibCommandPalette(actions: _actions, controller: controller, child: const SizedBox())),
    );
    controller.open();
    await tester.pump();

    // Tap far outside the centered content (top-left corner).
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    expect(controller.isOpen, isFalse);
  });

  testWidgets('animated: false builds zero NibMotion widgets', (tester) async {
    final controller = NibCommandPaletteController();
    await tester.pumpWidget(
      _wrap(NibCommandPalette(actions: _actions, controller: controller, child: const SizedBox())),
    );
    controller.open();
    await tester.pump();
    expect(find.byType(NibMotion), findsNothing);
  });

  testWidgets('animated: true builds a NibMotion wrapper', (tester) async {
    final controller = NibCommandPaletteController();
    await tester.pumpWidget(
      _wrap(
        NibCommandPalette(
          actions: _actions,
          controller: controller,
          animated: true,
          child: const SizedBox(),
        ),
      ),
    );
    controller.open();
    await tester.pump();
    expect(find.byType(NibMotion), findsOneWidget);
  });

  testWidgets('recent section shows a previously-selected action on reopen', (tester) async {
    final controller = NibCommandPaletteController();
    await tester.pumpWidget(
      _wrap(NibCommandPalette(actions: _actions, controller: controller, child: const SizedBox())),
    );
    controller.open();
    await tester.pump();
    await tester.tap(find.text('Open File'));
    await tester.pump();
    expect(controller.isOpen, isFalse);

    controller.open();
    await tester.pump();

    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Open File'), findsWidgets); // recent bucket + root list
  });

  testWidgets('narrow viewport does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = NibCommandPaletteController();
    await tester.pumpWidget(
      _wrap(
        NibCommandPalette(
          actions: const [
            NibCommandAction(id: 'a', label: 'Alpha', subtitle: 'A long descriptive subtitle here'),
            NibCommandAction(id: 'b', label: 'Beta'),
          ],
          controller: controller,
          child: const SizedBox(),
        ),
      ),
    );
    controller.open();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
