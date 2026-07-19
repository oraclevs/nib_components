import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/overlay/overlay_positioning.dart';

/// Absolute content rect for a geometry result, given a follower configured with
/// targetAnchor/followerAnchor = topLeft (what every consumer uses).
Rect _contentRect(NibOverlayGeometry geo, Rect target, Size content) =>
    (target.topLeft + geo.offset) & content;

void main() {
  const screen = Size(800, 600);
  // A trigger sitting mid-screen with room on every side.
  const target = Rect.fromLTWH(300, 280, 80, 40);

  group('resolveOverlayGeometry — side selection', () {
    test('keeps the preferred side when it fits', () {
      expect(
        resolveOverlayGeometry(
          placement: NibOverlayPlacement.bottom,
          target: target,
          content: const Size(100, 50),
          screen: screen,
        ).side,
        NibOverlaySide.bottom,
      );
      expect(
        resolveOverlayGeometry(
          placement: NibOverlayPlacement.end,
          target: target,
          content: const Size(100, 50),
          screen: screen,
        ).side,
        NibOverlaySide.end,
      );
    });

    test('flips bottom→top when there is no room below', () {
      const low = Rect.fromLTWH(300, 560, 80, 40);
      expect(
        resolveOverlayGeometry(
          placement: NibOverlayPlacement.bottom,
          target: low,
          content: const Size(100, 120),
          screen: screen,
        ).side,
        NibOverlaySide.top,
      );
    });

    test('flips end→start when there is no room to the right', () {
      const right = Rect.fromLTWH(740, 280, 40, 40);
      expect(
        resolveOverlayGeometry(
          placement: NibOverlayPlacement.end,
          target: right,
          content: const Size(120, 50),
          screen: screen,
        ).side,
        NibOverlaySide.start,
      );
    });

    test(
      'when neither side fits, picks the side with more room (not blind flip)',
      () {
        // Trigger just below vertical centre: more room above than below. Content
        // taller than both gaps → must land on the roomier side (top), not blindly
        // flip to the preferred-opposite.
        const target = Rect.fromLTWH(300, 320, 80, 40);
        final geo = resolveOverlayGeometry(
          placement: NibOverlayPlacement.bottom,
          target: target,
          content: const Size(100, 400),
          screen: screen,
        );
        expect(geo.side, NibOverlaySide.top);
      },
    );
  });

  group('resolveOverlayGeometry — clamping', () {
    test('slides content left when it overflows the right edge', () {
      const nearRight = Rect.fromLTWH(760, 280, 40, 40);
      final geo = resolveOverlayGeometry(
        placement: NibOverlayPlacement.bottom,
        target: nearRight,
        content: const Size(200, 50),
        screen: screen,
        margin: 0,
      );
      final rect = _contentRect(geo, nearRight, const Size(200, 50));
      expect(rect.right, lessThanOrEqualTo(screen.width));
      expect(rect.left, greaterThanOrEqualTo(0));
    });

    test(
      'clamps the MAIN axis so a start-side card never goes off the left edge',
      () {
        // Regression: hover card opening to the start near the left edge used to
        // render off-screen because the main (horizontal) axis was never clamped.
        const nearLeft = Rect.fromLTWH(40, 280, 40, 40);
        final geo = resolveOverlayGeometry(
          placement: NibOverlayPlacement.start,
          target: nearLeft,
          content: const Size(200, 60),
          screen: screen,
          margin: 8,
        );
        final rect = _contentRect(geo, nearLeft, const Size(200, 60));
        expect(rect.left, greaterThanOrEqualTo(8));
      },
    );

    test(
      'respects the top safe-area inset (status bar) — never draws under it',
      () {
        // Regression: profile hover card opened above and drew under the status
        // bar because the top inset was ignored. Trigger low enough that "above"
        // is chosen, content tall enough to reach the top.
        const target = Rect.fromLTWH(100, 300, 80, 40);
        const safe = EdgeInsets.only(top: 44); // status bar
        final geo = resolveOverlayGeometry(
          placement: NibOverlayPlacement.top,
          target: target,
          content: const Size(200, 320),
          screen: screen,
          safeInsets: safe,
          margin: 8,
        );
        final rect = _contentRect(geo, target, const Size(200, 320));
        expect(rect.top, greaterThanOrEqualTo(44 + 8));
      },
    );

    test('respects the bottom safe-area inset (nav bar / keyboard)', () {
      const target = Rect.fromLTWH(100, 200, 80, 40);
      const safe = EdgeInsets.only(bottom: 80);
      final geo = resolveOverlayGeometry(
        placement: NibOverlayPlacement.bottom,
        target: target,
        content: const Size(200, 500),
        screen: screen,
        safeInsets: safe,
        margin: 8,
      );
      final rect = _contentRect(geo, target, const Size(200, 500));
      expect(rect.bottom, lessThanOrEqualTo(screen.height - 80 - 8));
    });

    test('applies the gap between trigger and content on the chosen side', () {
      final geo = resolveOverlayGeometry(
        placement: NibOverlayPlacement.bottom,
        target: target,
        content: const Size(100, 50),
        screen: screen,
        gap: 12,
      );
      final rect = _contentRect(geo, target, const Size(100, 50));
      expect(rect.top, target.bottom + 12);
    });
  });
}
