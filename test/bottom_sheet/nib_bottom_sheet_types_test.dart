import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/bottom_sheet/nib_bottom_sheet_types.dart';

void main() {
  group('normalizeSnapExtents', () {
    test('returns null for null or empty input', () {
      expect(normalizeSnapExtents(null), isNull);
      expect(normalizeSnapExtents(<double>[]), isNull);
    });

    test('sorts, de-duplicates, and clamps into range', () {
      expect(
        normalizeSnapExtents([0.9, 0.25, 0.5, 0.25]),
        [0.25, 0.5, 0.9],
      );
      expect(normalizeSnapExtents([1.5, -0.2]), [kNibSheetMinExtent, 1.0]);
    });
  });

  group('clampInitialSnapIndex', () {
    test('defaults to the most-open (last) snap when null', () {
      expect(clampInitialSnapIndex(3, null), 2);
    });

    test('clamps out-of-range requests', () {
      expect(clampInitialSnapIndex(3, -1), 0);
      expect(clampInitialSnapIndex(3, 9), 2);
      expect(clampInitialSnapIndex(3, 1), 1);
    });

    test('is safe for an empty snap set', () {
      expect(clampInitialSnapIndex(0, null), 0);
    });
  });

  group('resolveSnapTarget', () {
    const extents = [0.25, 0.5, 0.9];

    test('slow release settles to the nearest snap', () {
      expect(
        resolveSnapTarget(
          currentExtent: 0.55,
          extents: extents,
          velocity: 0,
          dismissible: true,
        ),
        1,
      );
      expect(
        resolveSnapTarget(
          currentExtent: 0.8,
          extents: extents,
          velocity: 0,
          dismissible: true,
        ),
        2,
      );
    });

    test('fast downward flick steps to the next lower snap', () {
      expect(
        resolveSnapTarget(
          currentExtent: 0.9,
          extents: extents,
          velocity: -5,
          dismissible: true,
        ),
        1,
      );
    });

    test('fast upward flick steps to the next higher snap', () {
      expect(
        resolveSnapTarget(
          currentExtent: 0.25,
          extents: extents,
          velocity: 5,
          dismissible: true,
        ),
        1,
      );
    });

    test('fast upward flick clamps at the top snap', () {
      expect(
        resolveSnapTarget(
          currentExtent: 0.9,
          extents: extents,
          velocity: 5,
          dismissible: true,
        ),
        2,
      );
    });

    test('fast downward flick past the lowest snap dismisses when allowed', () {
      expect(
        resolveSnapTarget(
          currentExtent: 0.25,
          extents: extents,
          velocity: -5,
          dismissible: true,
        ),
        isNull,
      );
    });

    test('fast downward flick clamps to lowest when not dismissible', () {
      expect(
        resolveSnapTarget(
          currentExtent: 0.25,
          extents: extents,
          velocity: -5,
          dismissible: false,
        ),
        0,
      );
    });

    test('slow collapse below half the lowest snap dismisses when allowed', () {
      expect(
        resolveSnapTarget(
          currentExtent: 0.1,
          extents: extents,
          velocity: 0,
          dismissible: true,
        ),
        isNull,
      );
    });

    test('slow collapse never dismisses when not dismissible', () {
      expect(
        resolveSnapTarget(
          currentExtent: 0.1,
          extents: extents,
          velocity: 0,
          dismissible: false,
        ),
        0,
      );
    });

    test('single content-sized snap: fling down dismisses, slow settles', () {
      const one = [0.6];
      expect(
        resolveSnapTarget(
          currentExtent: 0.6,
          extents: one,
          velocity: -5,
          dismissible: true,
        ),
        isNull,
      );
      expect(
        resolveSnapTarget(
          currentExtent: 0.55,
          extents: one,
          velocity: 0,
          dismissible: true,
        ),
        0,
      );
    });
  });
}
