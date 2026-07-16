import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

List<Widget> _slides(int n) => [
      for (var i = 0; i < n; i++)
        SizedBox.expand(
          child: ColoredBox(
            color: Colors.primaries[i % Colors.primaries.length],
            child: Center(child: Text('slide $i')),
          ),
        ),
    ];

void main() {
  group('NibCarousel', () {
    testWidgets('shows the first slide by default', (tester) async {
      await tester.pumpWidget(_wrap(NibCarousel(items: _slides(3))));
      await tester.pumpAndSettle();
      expect(find.text('slide 0'), findsOneWidget);
    });

    testWidgets('renders one indicator dot per slide by default', (tester) async {
      await tester.pumpWidget(_wrap(NibCarousel(items: _slides(4))));
      await tester.pumpAndSettle();
      expect(find.byType(NibCarouselDot), findsNWidgets(4));
    });

    testWidgets('indicatorStyle none renders no dots', (tester) async {
      await tester.pumpWidget(_wrap(NibCarousel(
        items: _slides(4),
        indicatorStyle: NibCarouselIndicatorStyle.none,
      )));
      await tester.pumpAndSettle();
      expect(find.byType(NibCarouselDot), findsNothing);
    });

    testWidgets('controller.nextPage advances the page', (tester) async {
      final controller = NibCarouselController();
      addTearDown(controller.dispose);
      final changes = <int>[];
      await tester.pumpWidget(_wrap(NibCarousel(
        items: _slides(3),
        controller: controller,
        onPageChanged: changes.add,
      )));
      await tester.pumpAndSettle();

      controller.nextPage();
      await tester.pumpAndSettle();
      expect(controller.page, 1);
      expect(changes.last, 1);
    });

    testWidgets('controller.previousPage does not go below 0 when not looping',
        (tester) async {
      final controller = NibCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(NibCarousel(
        items: _slides(3),
        controller: controller,
      )));
      await tester.pumpAndSettle();

      controller.previousPage();
      await tester.pumpAndSettle();
      expect(controller.page, 0);
    });

    testWidgets('loop wraps forward from the last slide back to the first',
        (tester) async {
      final controller = NibCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(NibCarousel(
        items: _slides(3),
        loop: true,
        controller: controller,
      )));
      await tester.pumpAndSettle();

      controller.jumpToPage(2);
      await tester.pumpAndSettle();
      expect(controller.page, 2);

      controller.nextPage();
      await tester.pumpAndSettle();
      expect(controller.page, 0); // wrapped
    });

    testWidgets('autoPlay advances after the interval', (tester) async {
      final changes = <int>[];
      await tester.pumpWidget(_wrap(NibCarousel(
        items: _slides(3),
        autoPlay: true,
        autoPlayInterval: const Duration(milliseconds: 200),
        onPageChanged: changes.add,
      )));
      await tester.pump(); // first layout
      expect(changes, isEmpty);

      // Step the clock until the interval fires and its page animation lands.
      for (var t = 0; t < 1200 && changes.isEmpty; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(changes, isNotEmpty);
      expect(changes.first, 1);

      // Stop the timer so pending frames don't leak into later tests.
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('builds no NibMotion when animated is false', (tester) async {
      await tester.pumpWidget(_wrap(NibCarousel(items: _slides(3))));
      await tester.pumpAndSettle();
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('wraps the active indicator in NibMotion when animated',
        (tester) async {
      await tester.pumpWidget(_wrap(NibCarousel(
        items: _slides(3),
        animated: true,
      )));
      await tester.pumpAndSettle();
      expect(find.byType(NibMotion), findsWidgets);
    });

    testWidgets('peekExtent keeps neighbouring slides mounted', (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(
        width: 300,
        child: NibCarousel(items: _slides(3), peekExtent: 40),
      )));
      await tester.pumpAndSettle();
      // With a peek, the next slide is partially in the viewport.
      expect(find.text('slide 1'), findsOneWidget);
    });

    testWidgets('disposes cleanly when removed mid-autoplay', (tester) async {
      await tester.pumpWidget(_wrap(NibCarousel(
        items: _slides(3),
        autoPlay: true,
        autoPlayInterval: const Duration(milliseconds: 100),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });
}
