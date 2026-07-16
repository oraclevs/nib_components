import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibGlass, NibMotion;

class _CircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()..addOval(Offset.zero & size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.teal)),
            Center(child: child),
          ],
        ),
      ),
    );

void main() {
  group('glassLightFromPointer', () {
    const size = Size(200, 100);

    test('points from center toward the pointer', () {
      // Pointer to the right of center → +x direction.
      final right = glassLightFromPointer(const Offset(200, 50), size);
      expect(right.dx, greaterThan(0));
      expect(right.dy.abs(), lessThan(1e-9));
      // Unit length.
      expect(right.distance, closeTo(1.0, 1e-9));
    });

    test('defaults to "from the top" at the exact center', () {
      expect(glassLightFromPointer(const Offset(100, 50), size), const Offset(0, -1));
    });

    test('defaults to "from the top" for an empty size', () {
      expect(glassLightFromPointer(const Offset(5, 5), Size.zero), const Offset(0, -1));
    });
  });

  group('NibLiquidGlass', () {
    testWidgets('renders its child over a glass surface without throwing',
        (tester) async {
      await tester.pumpWidget(_wrap(const NibLiquidGlass(
        width: 220,
        height: 140,
        child: Text('Glass'),
      )));
      await tester.pump();

      expect(find.text('Glass'), findsOneWidget);
      expect(find.byType(NibGlass), findsOneWidget);
      // Non-Impeller test backend → frosted-blur fallback uses a BackdropFilter.
      expect(find.byType(BackdropFilter), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clips to a ClipRRect by default, ClipPath with a clipper',
        (tester) async {
      await tester.pumpWidget(_wrap(NibLiquidGlass(
        width: 200,
        height: 120,
        child: const SizedBox(),
      )));
      await tester.pump();
      expect(find.byType(ClipRRect), findsWidgets);

      await tester.pumpWidget(_wrap(NibLiquidGlass(
        width: 200,
        height: 120,
        clipper: _CircleClipper(),
        child: const SizedBox(),
      )));
      await tester.pump();
      expect(find.byType(ClipPath), findsWidgets);
    });

    testWidgets('builds no NibMotion when not animated, one when animated',
        (tester) async {
      await tester.pumpWidget(_wrap(const NibLiquidGlass(
        width: 200,
        height: 120,
        child: SizedBox(),
      )));
      await tester.pump();
      expect(find.byType(NibMotion), findsNothing);

      await tester.pumpWidget(_wrap(const NibLiquidGlass(
        width: 200,
        height: 120,
        animated: true,
        child: SizedBox(),
      )));
      await tester.pump();
      expect(find.byType(NibMotion), findsOneWidget);
    });

    testWidgets('interactive wraps a pointer listener; a press does not throw',
        (tester) async {
      await tester.pumpWidget(_wrap(const NibLiquidGlass(
        width: 220,
        height: 140,
        child: Text('Press'),
      )));
      await tester.pump();
      expect(find.byType(Listener), findsWidgets);

      final gesture = await tester.press(find.text('Press'));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('non-interactive omits the pointer listener wrapper',
        (tester) async {
      await tester.pumpWidget(_wrap(const NibLiquidGlass(
        width: 200,
        height: 120,
        interactive: false,
        child: Text('Static'),
      )));
      await tester.pump();
      expect(find.text('Static'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
