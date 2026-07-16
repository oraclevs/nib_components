import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('nibDialogMaxWidth', () {
    test('maps size presets to fixed widths', () {
      expect(nibDialogMaxWidth(NibDialogSize.sm), 380);
      expect(nibDialogMaxWidth(NibDialogSize.md), 512);
      expect(nibDialogMaxWidth(NibDialogSize.lg), 720);
    });

    test('fullscreen has no max width (null)', () {
      expect(nibDialogMaxWidth(NibDialogSize.fullscreen), isNull);
    });
  });

  group('resolveNibDialogEnter', () {
    test('none resolves to identity', () {
      expect(resolveNibDialogEnter(NibDialogAnimation.none), NibAnim.identity);
    });

    test('fade drops opacity only, no transform', () {
      final a = resolveNibDialogEnter(NibDialogAnimation.fade);
      expect(a.opacity, 0);
      expect(a.scale, isNull);
      expect(a.y, isNull);
    });

    test('scale starts slightly small, full opacity', () {
      final a = resolveNibDialogEnter(NibDialogAnimation.scale);
      expect(a.scale, lessThan(1));
      expect(a.opacity, isNull);
    });

    test('fadeScale drops opacity and scale (the default)', () {
      final a = resolveNibDialogEnter(NibDialogAnimation.fadeScale);
      expect(a.opacity, 0);
      expect(a.scale, lessThan(1));
    });

    test('slideUp starts below with zero opacity', () {
      final a = resolveNibDialogEnter(NibDialogAnimation.slideUp);
      expect(a.opacity, 0);
      expect(a.y, greaterThan(0));
    });
  });
}
