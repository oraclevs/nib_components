import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('NibBottomSheet (declarative)', () {
    testWidgets('renders only its trigger until tapped', (tester) async {
      await tester.pumpWidget(_wrap(const NibBottomSheet(
        trigger: Text('tap me'),
        content: Text('content'),
      )));

      expect(find.text('tap me'), findsOneWidget);
      expect(find.text('content'), findsNothing);

      await tester.tap(find.text('tap me'));
      await tester.pumpAndSettle();
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('renders nothing when trigger is null and closed', (tester) async {
      await tester.pumpWidget(_wrap(const NibBottomSheet(content: Text('x'))));
      expect(find.byType(SizedBox), findsWidgets); // the shrink placeholder
      expect(find.text('x'), findsNothing);
    });

    testWidgets('an external controller opens and closes the sheet',
        (tester) async {
      final controller = NibBottomSheetController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(NibBottomSheet(
        controller: controller,
        content: const Text('controlled'),
      )));
      expect(find.text('controlled'), findsNothing);

      controller.open();
      await tester.pumpAndSettle();
      expect(find.text('controlled'), findsOneWidget);

      controller.close();
      await tester.pumpAndSettle();
      expect(find.text('controlled'), findsNothing);
    });

    testWidgets('onClose fires and controller resyncs on barrier dismiss',
        (tester) async {
      final controller = NibBottomSheetController();
      addTearDown(controller.dispose);
      var closed = 0;

      await tester.pumpWidget(_wrap(NibBottomSheet(
        controller: controller,
        onClose: () => closed++,
        content: const Text('resync'),
      )));

      controller.open();
      await tester.pumpAndSettle();
      expect(controller.isOpen, isTrue);

      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();

      expect(find.text('resync'), findsNothing);
      expect(closed, 1);
      expect(controller.isOpen, isFalse);
    });
  });
}
