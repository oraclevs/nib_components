import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibAnim, NibGlass, NibMotion;

Widget _host({
  bool interactive = true,
  bool animated = true,
  Offset rest = const Offset(-.4, -1),
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: NibLiquidGlass(
        width: 240,
        height: 160,
        interactive: interactive,
        animated: animated,
        restLightDirection: rest,
        child: const Text('A native glass surface'),
      ),
    ),
  ),
);

double _scaleTarget(WidgetTester tester) =>
    (tester.widget<NibMotion>(find.byType(NibMotion)).animate as NibAnim)
        .scale!;

void main() {
  testWidgets('disabling interaction during a press clears scale and light', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    final box = tester.getRect(find.byType(NibLiquidGlass));
    final pointer = await tester.startGesture(
      box.topCenter + const Offset(0, 20),
    );
    await tester.pump();
    expect(_scaleTarget(tester), .98);
    expect(
      tester.widget<NibGlass>(find.byType(NibGlass)).lightDirection,
      const Offset(0, -1),
    );

    const changedRest = Offset(.6, -.8);
    await tester.pumpWidget(_host(interactive: false, rest: changedRest));
    expect(_scaleTarget(tester), 1);
    expect(
      tester.widget<NibGlass>(find.byType(NibGlass)).lightDirection,
      changedRest,
    );
    await pointer.cancel();
    await tester.pumpWidget(_host(rest: changedRest));
    expect(_scaleTarget(tester), 1);
    expect(
      tester.widget<NibGlass>(find.byType(NibGlass)).lightDirection,
      changedRest,
    );
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a static press cannot reappear when animation is later enabled',
    (tester) async {
      await tester.pumpWidget(_host(animated: false));
      final box = tester.getRect(find.byType(NibLiquidGlass));
      final pointer = await tester.startGesture(
        box.centerRight - const Offset(20, 0),
      );
      await tester.pump();
      expect(find.byType(NibMotion), findsNothing);
      expect(
        tester.widget<NibGlass>(find.byType(NibGlass)).lightDirection,
        const Offset(1, 0),
      );
      await tester.pumpWidget(_host(interactive: false, animated: false));
      await pointer.up();
      await tester.pumpWidget(_host());
      expect(_scaleTarget(tester), 1);
      expect(
        tester.widget<NibGlass>(find.byType(NibGlass)).lightDirection,
        const Offset(-.4, -1),
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
