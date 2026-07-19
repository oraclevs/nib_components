import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The device intrusions an anchored overlay must stay clear of, read from a
/// [MediaQueryData]: the status bar / notch (`padding.top`), the system nav bar
/// (`padding.bottom`), display cutouts on the sides, and the on-screen keyboard
/// (`viewInsets.bottom`, taken as the larger of it and the nav-bar padding).
///
/// Feed the result to [resolveOverlayGeometry]'s `safeInsets` so the overlay is
/// clamped inside the usable region, not the raw window.
EdgeInsets nibOverlaySafeInsets(MediaQueryData mq) => EdgeInsets.fromLTRB(
  mq.padding.left,
  mq.padding.top,
  mq.padding.right,
  math.max(mq.padding.bottom, mq.viewInsets.bottom),
);

/// Which side of a trigger an anchored overlay's content prefers to open
/// toward. Flips to the opposite side automatically if it doesn't fit in the
/// viewport. Shared positioning vocabulary for `NibAnchoredOverlay` (flyouts,
/// nav submenus), `NibPopover`, `NibHoverCard`, and context-menu submenus.
enum NibOverlayPlacement {
  /// Below the trigger, left-aligned. Flips to [top] if it doesn't fit.
  bottom,

  /// Above the trigger, left-aligned. Flips to [bottom] if it doesn't fit.
  top,

  /// To the right of the trigger, top-aligned. Flips to [start] if it doesn't
  /// fit.
  end,

  /// To the left of the trigger, top-aligned. Flips to [end] if it doesn't fit.
  start,
}

/// The concrete side chosen after flip resolution.
enum NibOverlaySide { bottom, top, end, start }

/// A resolved overlay position: the concrete [side] the content ended up on,
/// and the [offset] to feed a `CompositedTransformFollower` configured with
/// `targetAnchor: Alignment.topLeft, followerAnchor: Alignment.topLeft`. The
/// offset already includes the trigger↔content gap, cross-axis alignment, and
/// full viewport clamping — the follower needs no anchor maths of its own.
typedef NibOverlayGeometry = ({NibOverlaySide side, Offset offset});

bool _isVertical(NibOverlaySide side) =>
    side == NibOverlaySide.bottom || side == NibOverlaySide.top;

/// Resolves where an anchored overlay should render so it stays fully on screen
/// on any viewport — phone, tablet, or desktop.
///
/// Given the trigger's global [target] rect, the [content]'s measured size, the
/// [screen] size, and the device [safeInsets] (status bar, system nav bar,
/// keyboard — pass `MediaQuery` padding/viewInsets), it:
///
/// 1. picks the concrete [NibOverlaySide]: the preferred [placement] if the
///    content fits in the usable space on that side, else the opposite side if
///    *it* fits, else whichever of the two has **more room** (so it's clamped
///    on the roomier side rather than blindly flipped);
/// 2. positions the content [gap] pixels off the trigger on that side, aligning
///    the leading edges on the cross axis;
/// 3. clamps **both** axes inside the usable viewport (`screen` minus
///    [safeInsets] minus a [margin] breathing space) so the content never draws
///    under the status bar, off an edge, or behind the keyboard. Content larger
///    than the usable space is pinned to the leading safe edge.
///
/// Pure and side-effect-free — all inputs in, geometry out.
NibOverlayGeometry resolveOverlayGeometry({
  required NibOverlayPlacement placement,
  required Rect target,
  required Size content,
  required Size screen,
  EdgeInsets safeInsets = EdgeInsets.zero,
  double gap = 0,
  double margin = 8,
}) {
  final minX = safeInsets.left + margin;
  final minY = safeInsets.top + margin;
  final maxX = screen.width - safeInsets.right - margin;
  final maxY = screen.height - safeInsets.bottom - margin;

  final side = _chooseSide(
    placement,
    target,
    content,
    gap,
    minX,
    minY,
    maxX,
    maxY,
  );

  double dx;
  double dy;
  if (_isVertical(side)) {
    dy = side == NibOverlaySide.bottom
        ? target.bottom + gap
        : target.top - gap - content.height;
    dx = target.left; // align leading (left) edges on the cross axis
  } else {
    dx = side == NibOverlaySide.end
        ? target.right + gap
        : target.left - gap - content.width;
    dy = target.top; // align top edges on the cross axis
  }

  dx = _clampAxis(dx, content.width, minX, maxX);
  dy = _clampAxis(dy, content.height, minY, maxY);

  return (side: side, offset: Offset(dx - target.left, dy - target.top));
}

/// Clamps a content edge starting at [start] with [extent] inside `[lo, hi]`.
/// Content larger than the available span is pinned to [lo] (the leading safe
/// edge) rather than overflowing both ends.
double _clampAxis(double start, double extent, double lo, double hi) {
  if (extent >= hi - lo) return lo;
  if (start < lo) return lo;
  if (start + extent > hi) return hi - extent;
  return start;
}

NibOverlaySide _chooseSide(
  NibOverlayPlacement placement,
  Rect target,
  Size content,
  double gap,
  double minX,
  double minY,
  double maxX,
  double maxY,
) {
  final spaceBelow = maxY - (target.bottom + gap);
  final spaceAbove = (target.top - gap) - minY;
  final spaceEnd = maxX - (target.right + gap);
  final spaceStart = (target.left - gap) - minX;

  switch (placement) {
    case NibOverlayPlacement.bottom:
      if (content.height <= spaceBelow) return NibOverlaySide.bottom;
      if (content.height <= spaceAbove) return NibOverlaySide.top;
      return spaceBelow >= spaceAbove
          ? NibOverlaySide.bottom
          : NibOverlaySide.top;
    case NibOverlayPlacement.top:
      if (content.height <= spaceAbove) return NibOverlaySide.top;
      if (content.height <= spaceBelow) return NibOverlaySide.bottom;
      return spaceAbove >= spaceBelow
          ? NibOverlaySide.top
          : NibOverlaySide.bottom;
    case NibOverlayPlacement.end:
      if (content.width <= spaceEnd) return NibOverlaySide.end;
      if (content.width <= spaceStart) return NibOverlaySide.start;
      return spaceEnd >= spaceStart ? NibOverlaySide.end : NibOverlaySide.start;
    case NibOverlayPlacement.start:
      if (content.width <= spaceStart) return NibOverlaySide.start;
      if (content.width <= spaceEnd) return NibOverlaySide.end;
      return spaceStart >= spaceEnd ? NibOverlaySide.start : NibOverlaySide.end;
  }
}
