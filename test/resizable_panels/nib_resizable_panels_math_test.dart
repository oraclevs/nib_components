import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/resizable_panels/nib_resizable_panel.dart';
import 'package:nib_components/src/resizable_panels/nib_resizable_panels_math.dart';

List<NibResizablePanel> _panels(List<double?> initialSizes, {double minSize = 0.1, double maxSize = 1.0}) {
  return [
    for (final size in initialSizes)
      NibResizablePanel(child: const SizedBox(), minSize: minSize, maxSize: maxSize, initialSize: size),
  ];
}

void main() {
  group('normalizedInitialSizes', () {
    test('all-null initialSize splits evenly', () {
      final sizes = normalizedInitialSizes(_panels([null, null, null]));
      expect(sizes.length, 3);
      for (final size in sizes) {
        expect(size, closeTo(1 / 3, 1e-9));
      }
      expect(sizes.reduce((a, b) => a + b), closeTo(1.0, 1e-9));
    });

    test('explicit sizes already summing to 1.0 are unchanged', () {
      final sizes = normalizedInitialSizes(_panels([0.25, 0.5, 0.25]));
      expect(sizes, [closeTo(0.25, 1e-9), closeTo(0.5, 1e-9), closeTo(0.25, 1e-9)]);
    });

    test('explicit sizes not summing to 1.0 are normalized proportionally', () {
      final sizes = normalizedInitialSizes(_panels([0.6, 0.6]));
      expect(sizes[0], closeTo(0.5, 1e-9));
      expect(sizes[1], closeTo(0.5, 1e-9));
    });

    test('mix of explicit and null: null panels split the remainder evenly', () {
      final sizes = normalizedInitialSizes(_panels([0.5, null, null]));
      expect(sizes[0], closeTo(0.5, 1e-9));
      expect(sizes[1], closeTo(0.25, 1e-9));
      expect(sizes[2], closeTo(0.25, 1e-9));
    });
  });

  group('applyHandleDelta', () {
    test('within-bounds delta trades size only between the adjacent pair', () {
      final panels = _panels([null, null, null]);
      const sizes = [1 / 3, 1 / 3, 1 / 3];
      final result = applyHandleDelta(sizes: sizes, panels: panels, handleIndex: 0, deltaFraction: 0.1);
      expect(result[0], closeTo(1 / 3 + 0.1, 1e-9));
      expect(result[1], closeTo(1 / 3 - 0.1, 1e-9));
      expect(result[2], closeTo(1 / 3, 1e-9)); // untouched
      expect(result.reduce((a, b) => a + b), closeTo(1.0, 1e-9));
    });

    test('delta pushing panel i above its maxSize clamps at maxSize, no cascade', () {
      final panels = _panels([null, null, null], maxSize: 0.5);
      const sizes = [1 / 3, 1 / 3, 1 / 3];
      final result = applyHandleDelta(sizes: sizes, panels: panels, handleIndex: 0, deltaFraction: 0.9);
      expect(result[0], closeTo(0.5, 1e-9));
      expect(result[1], closeTo(2 / 3 - 0.5, 1e-9)); // pair budget minus panel 0's clamped share
      expect(result[2], closeTo(1 / 3, 1e-9)); // untouched
    });

    test('delta pushing panel i below its minSize clamps at minSize, no cascade', () {
      final panels = _panels([null, null, null], minSize: 0.2);
      const sizes = [1 / 3, 1 / 3, 1 / 3];
      final result = applyHandleDelta(sizes: sizes, panels: panels, handleIndex: 0, deltaFraction: -0.9);
      expect(result[0], closeTo(0.2, 1e-9));
      expect(result[2], closeTo(1 / 3, 1e-9)); // untouched
    });

    test("delta pushing panel j (the pair's second panel) below its minSize clamps there instead", () {
      final panels = _panels([null, null, null], minSize: 0.2);
      const sizes = [1 / 3, 1 / 3, 1 / 3];
      // Dragging handle 0 hard to the right shrinks panel 1 (index 1) toward its min.
      final result = applyHandleDelta(sizes: sizes, panels: panels, handleIndex: 0, deltaFraction: 0.9);
      expect(result[1], closeTo(0.2, 1e-9));
      expect(result[0], closeTo(2 / 3 - 0.2, 1e-9));
      expect(result[2], closeTo(1 / 3, 1e-9));
    });

    test('operates on the correct pair for a non-zero handleIndex', () {
      final panels = _panels([null, null, null]);
      const sizes = [0.5, 0.25, 0.25];
      final result = applyHandleDelta(sizes: sizes, panels: panels, handleIndex: 1, deltaFraction: 0.1);
      expect(result[0], closeTo(0.5, 1e-9)); // untouched
      expect(result[1], closeTo(0.35, 1e-9));
      expect(result[2], closeTo(0.15, 1e-9));
    });
  });

  group('resetHandlePair', () {
    test('restores the pair to its original initial-size ratio, scaled to the current budget', () {
      final initial = normalizedInitialSizes(_panels([0.2, 0.2, 0.6]));
      // Simulate a prior drag that changed the pair's combined budget from 0.4 to 0.5,
      // and separately shrank panel 2 to 0.5 (untouched by the reset below).
      const dragged = [0.25, 0.25, 0.5];
      final result = resetHandlePair(sizes: dragged, initialSizes: initial, handleIndex: 0);
      // Original ratio between panel 0 and 1 was 0.2:0.2 == 1:1, so the pair's current
      // 0.5 budget splits back to 0.25/0.25 (already even here) — panel 2 untouched.
      expect(result[0], closeTo(0.25, 1e-9));
      expect(result[1], closeTo(0.25, 1e-9));
      expect(result[2], closeTo(0.5, 1e-9));
    });

    test('an uneven original ratio is preserved when rescaled to a different budget', () {
      final initial = normalizedInitialSizes(_panels([0.1, 0.3, 0.6]));
      const dragged = [0.3, 0.1, 0.6];
      final result = resetHandlePair(sizes: dragged, initialSizes: initial, handleIndex: 0);
      // Original ratio 0.1:0.3 == 1:3; current pair budget is 0.4 -> 0.1/0.3.
      expect(result[0], closeTo(0.1, 1e-9));
      expect(result[1], closeTo(0.3, 1e-9));
      expect(result[2], closeTo(0.6, 1e-9)); // untouched
    });
  });
}
