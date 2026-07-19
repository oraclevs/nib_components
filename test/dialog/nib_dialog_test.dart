import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

void main() {
  testWidgets('opens on trigger tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NibDialog(trigger: Text('open'), content: Text('body')),
        ),
      ),
    );

    expect(find.text('body'), findsNothing);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('controller drives open and close', (tester) async {
    final controller = NibDialogController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NibDialog(
            controller: controller,
            trigger: const Text('open'),
            content: const Text('body'),
          ),
        ),
      ),
    );

    controller.open();
    await tester.pumpAndSettle();
    expect(find.text('body'), findsOneWidget);

    controller.close();
    await tester.pumpAndSettle();
    expect(find.text('body'), findsNothing);
  });

  testWidgets('dismissing via Escape syncs the controller back to closed', (
    tester,
  ) async {
    final controller = NibDialogController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NibDialog(
            controller: controller,
            trigger: const Text('open'),
            content: const Text('body'),
          ),
        ),
      ),
    );

    controller.open();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('body'), findsNothing);
    expect(controller.isOpen, isFalse);
  });

  testWidgets('onClose fires when dismissed', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NibDialog(
            trigger: const Text('open'),
            content: const Text('body'),
            onClose: () => closed++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(closed, 1);
  });

  testWidgets('unmounting while open removes the overlay without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NibDialog(trigger: Text('open'), content: Text('body')),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('body'), findsOneWidget);

    // Replace the subtree — disposes NibDialog (which owns its controller).
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pumpAndSettle();
    expect(find.text('body'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
