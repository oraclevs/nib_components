import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// Adds a mouse pointer and hovers it over the center of [finder].
Future<TestGesture> _hoverOver(WidgetTester tester, Finder finder) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pump();
  return gesture;
}

void main() {
  group('NibHoverCard', () {
    testWidgets('renders nothing but its trigger while closed', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibHoverCard(trigger: Text('trigger'), content: Text('body')),
        ),
      );
      expect(find.text('trigger'), findsOneWidget);
      expect(find.text('body'), findsNothing);
    });

    testWidgets('hovering the trigger opens the card after showDelay', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const NibHoverCard(
            showDelay: Duration(milliseconds: 40),
            trigger: Text('hover me'),
            content: Text('card body'),
          ),
        ),
      );

      await _hoverOver(tester, find.text('hover me'));
      expect(find.text('card body'), findsNothing); // delay not elapsed yet

      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(find.text('card body'), findsOneWidget);
    });

    testWidgets('moving the pointer off the trigger closes after hideDelay', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const NibHoverCard(
            showDelay: Duration(milliseconds: 10),
            hideDelay: Duration(milliseconds: 40),
            trigger: Text('t'),
            content: Text('bye'),
          ),
        ),
      );

      final gesture = await _hoverOver(tester, find.text('t'));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('bye'), findsOneWidget);

      await gesture.moveTo(const Offset(5, 5)); // off the trigger
      await tester.pump();
      expect(find.text('bye'), findsOneWidget); // hideDelay not elapsed yet

      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(find.text('bye'), findsNothing);
    });

    testWidgets('moving the pointer onto the card keeps it open', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const NibHoverCard(
            showDelay: Duration(milliseconds: 10),
            hideDelay: Duration(milliseconds: 40),
            trigger: Text('t'),
            content: SizedBox(width: 200, height: 80, child: Text('stay open')),
          ),
        ),
      );

      final gesture = await _hoverOver(tester, find.text('t'));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('stay open'), findsOneWidget);

      // Leave the trigger (schedules close) but land on the card before it fires.
      await gesture.moveTo(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveTo(tester.getCenter(find.text('stay open')));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(find.text('stay open'), findsOneWidget); // cancelled the close
    });

    testWidgets('tapping the trigger opens it (touch fallback)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const NibHoverCard(
            trigger: Text('tap me'),
            content: Text('tapped open'),
          ),
        ),
      );

      await tester.tap(find.text('tap me'));
      await tester.pumpAndSettle();
      expect(find.text('tapped open'), findsOneWidget);
    });

    testWidgets('an outside tap dismisses a tap-opened card', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibHoverCard(trigger: Text('t'), content: Text('dismiss me')),
        ),
      );
      await tester.tap(find.text('t'));
      await tester.pumpAndSettle();
      expect(find.text('dismiss me'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('dismiss me'), findsNothing);
    });

    testWidgets('openOnTap: false ignores taps', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibHoverCard(
            openOnTap: false,
            trigger: Text('t'),
            content: Text('no tap'),
          ),
        ),
      );
      await tester.tap(find.text('t'));
      await tester.pumpAndSettle();
      expect(find.text('no tap'), findsNothing);
    });

    testWidgets('an external controller opens and closes it', (tester) async {
      final controller = NibHoverCardController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          NibHoverCard(
            controller: controller,
            trigger: const Text('t'),
            content: const Text('controlled'),
          ),
        ),
      );
      expect(find.text('controlled'), findsNothing);

      controller.open();
      await tester.pumpAndSettle();
      expect(find.text('controlled'), findsOneWidget);

      controller.close();
      await tester.pumpAndSettle();
      expect(find.text('controlled'), findsNothing);
    });

    testWidgets('builds no NibMotion when animated is false', (tester) async {
      final controller = NibHoverCardController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          NibHoverCard(
            controller: controller,
            trigger: const Text('t'),
            content: const Text('plain'),
          ),
        ),
      );
      controller.open();
      await tester.pumpAndSettle();
      expect(find.text('plain'), findsOneWidget);
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('wraps the panel in NibMotion when animated', (tester) async {
      final controller = NibHoverCardController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          NibHoverCard(
            controller: controller,
            animated: true,
            trigger: const Text('t'),
            content: const Text('animated'),
          ),
        ),
      );
      controller.open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(NibMotion), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text('animated'), findsOneWidget);
    });

    testWidgets('flips above the trigger when there is no room below', (
      tester,
    ) async {
      final controller = NibHoverCardController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: NibHoverCard(
                controller: controller,
                placement: NibHoverCardPlacement.bottom,
                trigger: const SizedBox(
                  width: 80,
                  height: 40,
                  child: Text('t'),
                ),
                content: const SizedBox(height: 120, child: Text('flip me')),
              ),
            ),
          ),
        ),
      );
      controller.open();
      await tester.pumpAndSettle();

      final triggerTop = tester.getTopLeft(find.text('t'));
      final contentBottom = tester.getBottomLeft(find.text('flip me'));
      expect(contentBottom.dy, lessThanOrEqualTo(triggerTop.dy));
    });

    testWidgets(
      'clamps inside the safe area on a phone viewport (status bar / nav bar)',
      (tester) async {
        // Simulate a phone with a 44px status bar and a 34px gesture nav bar.
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
        addTearDown(tester.view.reset);

        final controller = NibHoverCardController();
        addTearDown(controller.dispose);

        // Trigger pinned to the very top with placement: top — a naive overlay
        // would draw the card up into (or through) the status bar. It must flip
        // down / clamp so the whole card stays within the safe region.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: NibHoverCard(
                  controller: controller,
                  placement: NibHoverCardPlacement.top,
                  trigger: const SizedBox(
                    width: 80,
                    height: 32,
                    child: Text('t'),
                  ),
                  content: const SizedBox(
                    key: Key('hc-body'),
                    width: 260,
                    height: 300,
                    child: Text('viewport body'),
                  ),
                ),
              ),
            ),
          ),
        );

        controller.open();
        await tester.pumpAndSettle();
        expect(find.text('viewport body'), findsOneWidget);

        final card = find
            .ancestor(
              of: find.byKey(const Key('hc-body')),
              matching: find.byType(Material),
            )
            .first;
        final rect = tester.getRect(card);
        expect(rect.top, greaterThanOrEqualTo(44), reason: 'under status bar');
        expect(
          rect.bottom,
          lessThanOrEqualTo(640 - 34),
          reason: 'under nav bar',
        );
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
      },
    );

    testWidgets('does not steal focus from a focused sibling', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final controller = NibHoverCardController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(focusNode: focusNode),
              NibHoverCard(
                controller: controller,
                trigger: const Text('t'),
                content: const Text('body'),
              ),
            ],
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      controller.open();
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget);
      expect(focusNode.hasFocus, isTrue); // card didn't grab focus
    });
  });
}
