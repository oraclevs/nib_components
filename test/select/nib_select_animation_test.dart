import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

void main() {
  test('none resolves to identity (no visual change)', () {
    final a = resolveNibSelectEnter(NibSelectAnimation.none, openUp: false);
    expect(a.opacity, 1);
    expect(a.x, 0);
    expect(a.y, 0);
    expect(a.scale, 1);
  });

  test('fade resolves to opacity 0 only', () {
    final a = resolveNibSelectEnter(NibSelectAnimation.fade, openUp: false);
    expect(a.opacity, 0);
    expect(a.y, isNull);
    expect(a.scale, isNull);
  });

  test('scale resolves to a slightly-small scale, no fade', () {
    final a = resolveNibSelectEnter(NibSelectAnimation.scale, openUp: false);
    expect(a.scale, lessThan(1));
    expect(a.opacity, isNull);
  });

  test('fadeScale combines opacity and scale', () {
    final a = resolveNibSelectEnter(
      NibSelectAnimation.fadeScale,
      openUp: false,
    );
    expect(a.opacity, 0);
    expect(a.scale, lessThan(1));
  });

  test('slide travels from above when opening down, below when opening up', () {
    final down = resolveNibSelectEnter(NibSelectAnimation.slide, openUp: false);
    final up = resolveNibSelectEnter(NibSelectAnimation.slide, openUp: true);
    expect(down.y, isNotNull);
    expect(up.y, isNotNull);
    // Direction-aware: the sign flips with placement.
    expect(down.y!.sign, isNot(up.y!.sign));
    // No opacity change for pure slide.
    expect(down.opacity, isNull);
  });

  test('slideFade flips slide direction and also fades', () {
    final down = resolveNibSelectEnter(
      NibSelectAnimation.slideFade,
      openUp: false,
    );
    final up = resolveNibSelectEnter(
      NibSelectAnimation.slideFade,
      openUp: true,
    );
    expect(down.opacity, 0);
    expect(down.y!.sign, isNot(up.y!.sign));
  });
}
