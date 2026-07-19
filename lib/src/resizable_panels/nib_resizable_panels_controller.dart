import 'package:flutter/foundation.dart';

import 'nib_resizable_panel.dart';
import 'nib_resizable_panels_math.dart';

/// Optional external controller for a `NibResizablePanels`' panel sizes.
/// Never required for basic use — `NibResizablePanels` creates and owns its
/// own controller internally when none is supplied, and disposes it on
/// unmount/controller-swap.
class NibResizablePanelsController extends ChangeNotifier {
  /// Creates a controller. If [initialSizes] is given, [sizes] is seeded
  /// immediately (useful for restoring a previously-persisted layout);
  /// otherwise [sizes] is empty until [attach] runs.
  NibResizablePanelsController({List<double>? initialSizes})
    : _sizes = initialSizes == null ? null : List<double>.of(initialSizes),
      _initialSizes = initialSizes == null
          ? null
          : List<double>.of(initialSizes);

  List<double>? _sizes;
  List<double>? _initialSizes;

  /// The current per-panel size fractions, always summing to `1.0` once
  /// seeded. Empty until [attach] has run (or [initialSizes] was passed to
  /// the constructor).
  List<double> get sizes =>
      List<double>.unmodifiable(_sizes ?? const <double>[]);

  /// Seeds [sizes] from `normalizedInitialSizes(panels)` the first time it's
  /// called (or whenever [panels]' length changes, e.g. a panel was added or
  /// removed). A no-op if [sizes] is already seeded at the same length, so
  /// it's safe to call on every `NibResizablePanels` build without
  /// discarding user-driven resizes.
  void attach(List<NibResizablePanel> panels) {
    if (_sizes != null && _sizes!.length == panels.length) return;
    final normalized = normalizedInitialSizes(panels);
    _sizes = List<double>.of(normalized);
    _initialSizes = List<double>.of(normalized);
  }

  /// Replaces every panel's size, normalized to sum to `1.0`. Trusted as-is
  /// otherwise (not re-clamped to individual panel min/max) — callers
  /// driving this directly are responsible for passing a sane layout.
  void setSizes(List<double> sizes) {
    final total = sizes.fold<double>(0.0, (sum, v) => sum + v);
    _sizes = total > 0.0
        ? [for (final v in sizes) v / total]
        : List<double>.of(sizes);
    notifyListeners();
  }

  /// Applies a drag/keyboard delta to the panel pair adjacent to
  /// [handleIndex]. See [applyHandleDelta].
  void applyDelta(
    List<NibResizablePanel> panels,
    int handleIndex,
    double deltaFraction,
  ) {
    if (_sizes == null) return;
    _sizes = applyHandleDelta(
      sizes: _sizes!,
      panels: panels,
      handleIndex: handleIndex,
      deltaFraction: deltaFraction,
    );
    notifyListeners();
  }

  /// Resets the panel pair adjacent to [handleIndex] to their original
  /// initial-size ratio. See [resetHandlePair].
  void resetPanelPair(int handleIndex) {
    if (_sizes == null || _initialSizes == null) return;
    _sizes = resetHandlePair(
      sizes: _sizes!,
      initialSizes: _initialSizes!,
      handleIndex: handleIndex,
    );
    notifyListeners();
  }

  /// Resets every panel to its original initial-size fraction.
  void resetAll() {
    if (_initialSizes == null) return;
    _sizes = List<double>.of(_initialSizes!);
    notifyListeners();
  }
}
