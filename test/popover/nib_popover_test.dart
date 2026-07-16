import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('NibPopover', () {
    testWidgets('tapping the trigger toggles the content open and closed',
        (tester) async {
      await tester.pumpWidget(_wrap(const NibPopover(
        trigger: Text('open me'),
        content: Text('popover body'),
      )));

      expect(find.text('popover body'), findsNothing);

      await tester.tap(find.text('open me'));
      await tester.pumpAndSettle();
      expect(find.text('popover body'), findsOneWidget);

      await tester.tap(find.text('open me'));
      await tester.pumpAndSettle();
      expect(find.text('popover body'), findsNothing);
    });

    testWidgets('renders nothing but its trigger while closed', (tester) async {
      await tester.pumpWidget(_wrap(const NibPopover(
        trigger: Text('trigger'),
        content: Text('body'),
      )));
      expect(find.text('trigger'), findsOneWidget);
      expect(find.text('body'), findsNothing);
    });

    testWidgets('an outside tap dismisses by default', (tester) async {
      await tester.pumpWidget(_wrap(const NibPopover(
        trigger: Text('t'),
        content: Text('dismiss me'),
      )));
      await tester.tap(find.text('t'));
      await tester.pumpAndSettle();
      expect(find.text('dismiss me'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('dismiss me'), findsNothing);
    });

    testWidgets('dismissOnOutsideTap: false keeps it open on an outside tap',
        (tester) async {
      final controller = NibPopoverController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(NibPopover(
        controller: controller,
        dismissOnOutsideTap: false,
        trigger: const Text('t'),
        content: const Text('sticky'),
      )));

      controller.open();
      await tester.pumpAndSettle();
      expect(find.text('sticky'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('sticky'), findsOneWidget); // still open

      controller.close();
      await tester.pumpAndSettle();
      expect(find.text('sticky'), findsNothing);
    });

    testWidgets('Escape closes the popover', (tester) async {
      await tester.pumpWidget(_wrap(const NibPopover(
        trigger: Text('t'),
        content: Text('esc me'),
      )));
      await tester.tap(find.text('t'));
      await tester.pumpAndSettle();
      expect(find.text('esc me'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('esc me'), findsNothing);
    });

    testWidgets('NibPopoverScope.close closes from inside the content',
        (tester) async {
      await tester.pumpWidget(_wrap(NibPopover(
        trigger: const Text('t'),
        content: Builder(
          builder: (pctx) => TextButton(
            onPressed: () => NibPopoverScope.of(pctx).close(),
            child: const Text('close inside'),
          ),
        ),
      )));
      await tester.tap(find.text('t'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('close inside'));
      await tester.pumpAndSettle();
      expect(find.text('close inside'), findsNothing);
    });

    testWidgets('an external controller opens and closes it', (tester) async {
      final controller = NibPopoverController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(NibPopover(
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

    testWidgets('builds no NibMotion when animated is false', (tester) async {
      await tester.pumpWidget(_wrap(const NibPopover(
        trigger: Text('t'),
        content: Text('plain'),
      )));
      await tester.tap(find.text('t'));
      await tester.pumpAndSettle();
      expect(find.text('plain'), findsOneWidget);
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('wraps the panel in NibMotion when animated', (tester) async {
      await tester.pumpWidget(_wrap(const NibPopover(
        trigger: Text('t'),
        animated: true,
        showArrow: true,
        content: Text('animated'),
      )));
      await tester.tap(find.text('t'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(NibMotion), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text('animated'), findsOneWidget);
    });

    testWidgets('flips above the trigger when there is no room below',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: NibPopover(
              trigger: const SizedBox(width: 80, height: 40, child: Text('t')),
              content: const SizedBox(height: 120, child: Text('flip me')),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('t'));
      await tester.pumpAndSettle();

      final triggerTop = tester.getTopLeft(find.text('t'));
      final contentBottom = tester.getBottomLeft(find.text('flip me'));
      expect(contentBottom.dy, lessThanOrEqualTo(triggerTop.dy));
    });
  });
}
