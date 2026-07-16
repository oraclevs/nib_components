// Pure snap-point math for `NibBottomSheet`. Kept free of any Flutter widget
// dependency so the drag/settle decision logic can be unit-tested in isolation
// (the surface only ever multiplies these fractions by the available height).

/// Smallest snap extent we allow, so a snap point never resolves to a sheet so
/// short it can't be grabbed.
const double kNibSheetMinExtent = 0.05;

/// Default drag-end speed, in extent-fractions per second, past which a flick is
/// treated as a fling (step to the next snap / dismiss) rather than a settle to
/// the nearest snap.
const double kNibSheetFlingVelocity = 2.0;

/// Positions within [kNibSheetMinExtent] of each other are treated as equal when
/// comparing the current extent against a snap.
const double _snapEpsilon = 1e-3;

/// Normalizes user-supplied [snapPoints] (fractions of the available height,
/// `0..1`) into a sorted, de-duplicated, ascending list clamped to
/// `[kNibSheetMinExtent, 1.0]`.
///
/// Returns `null` when [snapPoints] is null or empty — the caller then treats
/// the sheet as content-sized with a single implicit snap and drag-to-dismiss
/// only.
List<double>? normalizeSnapExtents(List<double>? snapPoints) {
  if (snapPoints == null || snapPoints.isEmpty) return null;
  final unique = <double>{};
  for (final p in snapPoints) {
    unique.add(p.clamp(kNibSheetMinExtent, 1.0).toDouble());
  }
  final list = unique.toList()..sort();
  return list;
}

/// Clamps a requested [initialSnap] index into range for a sheet with [count]
/// snaps. A null or out-of-range request defaults to the most-open (last) snap.
int clampInitialSnapIndex(int count, int? initialSnap) {
  if (count <= 0) return 0;
  if (initialSnap == null) return count - 1;
  return initialSnap.clamp(0, count - 1);
}

/// Decides where a sheet should go when a drag ends.
///
/// - [currentExtent] — the fraction of the available height the sheet currently
///   occupies at the moment of release.
/// - [extents] — the ascending snap extents (non-empty). For a content-sized
///   sheet this is a single-element list holding the content's extent.
/// - [velocity] — drag-end velocity in extent-fractions per second, **positive
///   when opening (moving up)** and negative when closing (moving down).
/// - [dismissible] — whether dragging/flinging past the lowest snap may dismiss.
///
/// Returns the target index into [extents], or `null` to dismiss the sheet.
int? resolveSnapTarget({
  required double currentExtent,
  required List<double> extents,
  required double velocity,
  required bool dismissible,
  double flingVelocity = kNibSheetFlingVelocity,
}) {
  assert(extents.isNotEmpty, 'extents must hold at least one snap');

  // Fast downward flick: step to the next lower snap, or dismiss past the last.
  if (velocity <= -flingVelocity) {
    for (var i = extents.length - 1; i >= 0; i--) {
      if (extents[i] < currentExtent - _snapEpsilon) return i;
    }
    return dismissible ? null : 0;
  }

  // Fast upward flick: step to the next higher snap, clamped to the top.
  if (velocity >= flingVelocity) {
    for (var i = 0; i < extents.length; i++) {
      if (extents[i] > currentExtent + _snapEpsilon) return i;
    }
    return extents.length - 1;
  }

  // Slow release collapsed below half the lowest snap → dismiss.
  if (dismissible && currentExtent < extents.first / 2) return null;

  // Otherwise settle to the nearest snap by distance.
  var best = 0;
  var bestDist = double.infinity;
  for (var i = 0; i < extents.length; i++) {
    final dist = (extents[i] - currentExtent).abs();
    if (dist < bestDist) {
      bestDist = dist;
      best = i;
    }
  }
  return best;
}
