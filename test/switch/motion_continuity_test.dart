import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  testWidgets(
    'custom switch thumb traverses intermediate positions and retargets without snapping',
    (tester) async {
      final value = ValueNotifier(false);
      addTearDown(value.dispose);
      const marker = ValueKey('thumb-marker');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: value,
              builder: (context, enabled, _) => NibSwitch(
                value: enabled,
                animated: true,
                transition: const NibTransition(
                  duration: Duration(milliseconds: 400),
                  curve: Curves.linear,
                ),
                onChanged: (next) => value.value = next,
                thumbBuilder: (_, state) => Container(
                  key: marker,
                  color: state.value ? Colors.amber : Colors.blue,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      double x() => tester.getTopLeft(find.byKey(marker)).dx;
      final off = x();
      value.value = true;
      await tester.pump();
      expect(
        x(),
        closeTo(off, .01),
        reason: 'A target update must not jump to its endpoint.',
      );
      await tester.pump(const Duration(milliseconds: 100));
      final outward = x();
      expect(outward, greaterThan(off + .5));
      expect(outward, lessThan(off + 19.5));
      value.value = false;
      await tester.pump();
      expect(
        x(),
        closeTo(outward, .01),
        reason: 'Retarget from the current painted position.',
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(x(), lessThan(outward));
      expect(x(), greaterThan(off));
      await tester.pumpAndSettle();
      expect(x(), closeTo(off, .01));
      value.value = true;
      await tester.pump();
      await tester.pumpAndSettle();
      expect(x(), closeTo(off + 20, .01));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
