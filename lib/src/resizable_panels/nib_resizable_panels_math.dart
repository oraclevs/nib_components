import 'nib_resizable_panel.dart';

/// Resolves every panel's [NibResizablePanel.initialSize] (splitting the
/// leftover fraction evenly across panels that omit it) and normalizes the
/// result so it sums to exactly `1.0`.
List<double> normalizedInitialSizes(List<NibResizablePanel> panels) {
  assert(panels.length >= 2, 'NibResizablePanels requires at least 2 panels.');

  final explicit = <int, double>{};
  var explicitSum = 0.0;
  for (var i = 0; i < panels.length; i++) {
    final size = panels[i].initialSize;
    if (size != null) {
      explicit[i] = size;
      explicitSum += size;
    }
  }

  final implicitCount = panels.length - explicit.length;
  final remainder = (1.0 - explicitSum).clamp(0.0, 1.0);
  final implicitShare = implicitCount > 0 ? remainder / implicitCount : 0.0;

  final raw = <double>[
    for (var i = 0; i < panels.length; i++) explicit[i] ?? implicitShare,
  ];

  final total = raw.fold<double>(0.0, (sum, v) => sum + v);
  if (total <= 0.0) {
    // Degenerate config (e.g. every explicit initialSize is 0) — fall back
    // to an even split rather than dividing by zero.
    return List<double>.filled(panels.length, 1.0 / panels.length);
  }
  return [for (final v in raw) v / total];
}

/// Applies a drag/keyboard-nudge [deltaFraction] to the pair of panels
/// adjacent to [handleIndex] (`panels[handleIndex]` and
/// `panels[handleIndex + 1]`), clamped independently to each panel's own
/// `minSize`/`maxSize`. The pair's combined size never changes — size moves
/// between the two panels only ("stop at limit, no cascade" to any other
/// panel).
List<double> applyHandleDelta({
  required List<double> sizes,
  required List<NibResizablePanel> panels,
  required int handleIndex,
  required double deltaFraction,
}) {
  final i = handleIndex;
  final j = handleIndex + 1;
  final pairBudget = sizes[i] + sizes[j];

  var newI = (sizes[i] + deltaFraction).clamp(
    panels[i].minSize,
    panels[i].maxSize,
  );
  var newJ = pairBudget - newI;

  if (newJ < panels[j].minSize) {
    newJ = panels[j].minSize;
    newI = pairBudget - newJ;
  } else if (newJ > panels[j].maxSize) {
    newJ = panels[j].maxSize;
    newI = pairBudget - newJ;
  }
  // Re-clamp i in case the j-driven correction pushed it back out of its own
  // bounds (only reachable with a conflicting min/max config) — keeps the
  // result safe rather than producing an out-of-bounds size.
  newI = newI.clamp(panels[i].minSize, panels[i].maxSize);
  newJ = pairBudget - newI;

  final result = List<double>.of(sizes);
  result[i] = newI;
  result[j] = newJ;
  return result;
}

/// Resets the pair of panels adjacent to [handleIndex] to their original
/// [initialSizes] ratio, rescaled to the pair's *current* combined budget so
/// every other panel/handle is left untouched and the full list still sums
/// to `1.0`.
List<double> resetHandlePair({
  required List<double> sizes,
  required List<double> initialSizes,
  required int handleIndex,
}) {
  final i = handleIndex;
  final j = handleIndex + 1;
  final pairBudget = sizes[i] + sizes[j];
  final initialPairSum = initialSizes[i] + initialSizes[j];

  final ratio = initialPairSum > 0.0 ? initialSizes[i] / initialPairSum : 0.5;
  final newI = pairBudget * ratio;
  final newJ = pairBudget - newI;

  final result = List<double>.of(sizes);
  result[i] = newI;
  result[j] = newJ;
  return result;
}
