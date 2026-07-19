import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

/// Puts [child] in a bounded, themed host. [width]/[height] bound the slider's
/// main axis so tap-to-seek math is deterministic.
Widget _wrap(Widget child, {double width = 200, double height = 200}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

void main() {
  group('NibRangeValues', () {
    test('clamp keeps thumbs inside [min,max] and ordered', () {
      const v = NibRangeValues(20, 80);
      expect(v.clamp(0, 100), const NibRangeValues(20, 80));
      expect(v.clamp(30, 70), const NibRangeValues(30, 70));
      expect(v.clamp(90, 100), const NibRangeValues(90, 90));
    });

    test('copyWith + equality', () {
      const v = NibRangeValues(1, 2);
      expect(v.copyWith(end: 5), const NibRangeValues(1, 5));
      expect(v, const NibRangeValues(1, 2));
      expect(v == const NibRangeValues(1, 3), isFalse);
    });
  });

  group('NibSlider — single', () {
    testWidgets('renders without overflow and shows no NibMotion by default', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(NibSlider(value: 0.4, onChanged: (_) {})));
      expect(tester.takeException(), isNull);
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('tap-to-seek at centre yields the midpoint value', (
      tester,
    ) async {
      double? got;
      await tester.pumpWidget(
        _wrap(NibSlider(value: 0, min: 0, max: 100, onChanged: (v) => got = v)),
      );
      await tester.tapAt(tester.getCenter(find.byType(NibSlider)));
      await tester.pump();
      expect(got, closeTo(50, 0.5));
    });

    testWidgets('drag fires start/change/end callbacks with rising value', (
      tester,
    ) async {
      double? start, changed, end;
      await tester.pumpWidget(
        _wrap(
          NibSlider(
            value: 0,
            min: 0,
            max: 100,
            onChangeStart: (v) => start = v,
            onChanged: (v) => changed = v,
            onChangeEnd: (v) => end = v,
          ),
        ),
      );
      final left = tester.getTopLeft(find.byType(NibSlider));
      final centerY = tester.getCenter(find.byType(NibSlider)).dy;
      await tester.dragFrom(
        Offset(left.dx + 20, centerY),
        const Offset(120, 0),
      );
      await tester.pump();
      expect(start, isNotNull);
      expect(changed, isNotNull);
      expect(end, isNotNull);
      expect(changed!, greaterThan(0));
    });

    testWidgets('divisions snap the value to the nearest tick', (tester) async {
      double? got;
      await tester.pumpWidget(
        _wrap(
          NibSlider(
            value: 0,
            min: 0,
            max: 100,
            divisions: 4, // ticks at 0,25,50,75,100
            onChanged: (v) => got = v,
          ),
        ),
      );
      // Track: inset by thumb radius (10) → length 180 across a 200px box.
      // Tap at fraction ~0.7 → raw 70 → nearest tick 75.
      final left = tester.getTopLeft(find.byType(NibSlider)).dx;
      final centerY = tester.getCenter(find.byType(NibSlider)).dy;
      await tester.tapAt(Offset(left + 10 + 0.7 * 180, centerY));
      await tester.pump();
      expect(got, closeTo(75, 0.001));
    });

    testWidgets('disabled slider ignores taps', (tester) async {
      var changed = false;
      await tester.pumpWidget(
        _wrap(
          NibSlider(
            value: 0.5,
            disabled: true,
            onChanged: (_) => changed = true,
          ),
        ),
      );
      await tester.tapAt(tester.getCenter(find.byType(NibSlider)));
      await tester.pump();
      expect(changed, isFalse);
    });

    testWidgets('null onChanged renders disabled (no crash on tap)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const NibSlider(value: 0.5)));
      await tester.tapAt(tester.getCenter(find.byType(NibSlider)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('NibSlider — keyboard', () {
    testWidgets('arrow key nudges by one step; Home/End jump to bounds', (
      tester,
    ) async {
      double? got;
      await tester.pumpWidget(
        _wrap(
          NibSlider(
            value: 50,
            min: 0,
            max: 100,
            autofocus: true,
            onChanged: (v) => got = v,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(got, closeTo(51, 0.001)); // step = (100-0)/100 = 1

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(got, closeTo(0, 0.001));

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(got, closeTo(100, 0.001));
    });
  });

  group('NibSlider — value label', () {
    testWidgets('shows the formatted label while dragging', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibSlider(
            value: 0,
            min: 0,
            max: 100,
            showValueLabel: true,
            valueLabelFormatter: (v) => 'val:${v.round()}',
            onChanged: (_) {},
          ),
        ),
      );
      final center = tester.getCenter(find.byType(NibSlider));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(
        const Offset(24, 0),
      ); // exceed touch slop → drag starts
      await tester.pump();
      expect(find.textContaining('val:'), findsOneWidget);
      await gesture.up();
      await tester.pump();
    });
  });

  group('NibSlider — animation', () {
    testWidgets('animated:true builds NibMotion (thumb pop)', (tester) async {
      await tester.pumpWidget(
        _wrap(NibSlider(value: 0.5, animated: true, onChanged: (_) {})),
      );
      expect(find.byType(NibMotion), findsWidgets);
    });

    testWidgets('animated:false builds zero NibMotion', (tester) async {
      await tester.pumpWidget(
        _wrap(NibSlider(value: 0.5, showValueLabel: true, onChanged: (_) {})),
      );
      expect(find.byType(NibMotion), findsNothing);
    });
  });

  group('NibSlider — range', () {
    testWidgets('renders two thumbs and drives onChanged', (tester) async {
      NibRangeValues? got;
      await tester.pumpWidget(
        _wrap(
          NibSlider.range(
            values: const NibRangeValues(20, 80),
            min: 0,
            max: 100,
            onChanged: (v) => got = v,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final left = tester.getTopLeft(find.byType(NibSlider)).dx;
      final centerY = tester.getCenter(find.byType(NibSlider)).dy;
      // Drag the start thumb (near 20% ≈ x=46) rightward far past the end thumb.
      await tester.dragFrom(Offset(left + 46, centerY), const Offset(300, 0));
      await tester.pump();
      expect(got, isNotNull);
      // Start thumb must clamp at (not cross) the end thumb.
      expect(got!.start, lessThanOrEqualTo(got!.end));
    });
  });

  group('NibSlider — vertical', () {
    testWidgets('min at the bottom: tapping high yields a low value', (
      tester,
    ) async {
      double? topGot, bottomGot;
      await tester.pumpWidget(
        _wrap(
          NibSlider(
            value: 50,
            min: 0,
            max: 100,
            axis: Axis.vertical,
            onChanged: (v) => topGot = v,
          ),
        ),
      );
      final r = tester.getRect(find.byType(NibSlider));
      // Near the top → high value.
      await tester.tapAt(Offset(r.center.dx, r.top + 20));
      await tester.pump();
      expect(topGot, greaterThan(60));
      bottomGot = topGot;
      // Near the bottom → low value.
      await tester.tapAt(Offset(r.center.dx, r.bottom - 20));
      await tester.pump();
      expect(topGot, lessThan(40));
      expect(bottomGot, isNot(topGot));
    });
  });

  group('NibSlider — customization', () {
    testWidgets('narrow width does not overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(NibSlider(value: 0.5, onChanged: (_) {}), width: 30),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
