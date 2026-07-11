# Resizable Panels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Repo override (see this repo's `CLAUDE.md`):** solo sessions in `nib_components` write code directly in the main session using TDD — no fresh-implementer/fresh-reviewer subagent pattern by default. Default to `superpowers:executing-plans` (inline execution) unless the user explicitly asks for subagent-driven execution.

**Goal:** Ship `NibResizablePanels` — a horizontal/vertical panel group with draggable, keyboard-resizable, min/max-constrained dividers — as component #3 in the Tier A build order.

**Architecture:** A custom multi-child `RenderObject` (`NibResizablePanelsRenderObject`) does pure layout only: given a list of panel-size fractions, a direction, and bounded incoming constraints, it positions an interleaved `[panel, handle, panel, handle, ..., panel]` child list, reserving a fixed-width hit slot for each handle. All interaction (drag, hover, keyboard, double-tap reset) lives in an ordinary `NibResizablePanelsHandle` widget built by `NibResizablePanels` and passed in as one of those children — this reuses Flutter's own well-tested `GestureDetector`/`Focus`/`MouseRegion`/`Semantics` machinery instead of reinventing pointer routing inside the render object, while the render object still owns 100% of the layout math that plain `Row`/`Expanded`/`Flexible` composition cannot get right (the actual "why this is hard" per the master prompt). Constraint-solving (fraction clamping, stop-at-limit, reset-to-initial-ratio) is pure, render-object-agnostic Dart in its own file, driven by `NibResizablePanelsController`.

**Tech Stack:** Flutter (`RenderBox` + `ContainerRenderObjectMixin`), `nib_motion` (`NibMotion`/`NibAnim`/`NibTransition`) for the `animated: true` handle affordance, no new pub dependencies.

## Global Constraints

- Widget/type names: `NibResizablePanels`, `NibResizablePanel`, `NibResizablePanelsController` — `Nib`-prefixed per the repo's naming convention.
- All colors/radii read from `NibTheme.of(context)` — no hardcoded hex (master prompt §2).
- Must render correctly in light and dark mode with zero extra consumer configuration (master prompt §2).
- `animated: bool = false` default; when `true` and no explicit `transition` is given, fall back to a built-in default `NibTransition`. Zero `NibMotion`/`MotionValue` allocation when `false` (master prompt §1.4). Uses the established codebase convention `animated: bool` + `transition: NibTransition?` (see `NibNavigationMenu`), not the design spec's placeholder `NibAnimationPreset` wording.
- Stateful-by-default: internal state lives in `NibResizablePanels`'s `State`; the optional `NibResizablePanelsController` is never required for basic use — created, owned, and disposed internally when the caller doesn't supply one (master prompt §1.3), following the exact `_bindController`/`_unbindController`/`_ownsController` pattern already established by `NibDataTable`.
- Zero required pub dependencies beyond the Flutter SDK and the existing `nib_motion` path dependency.
- Responsive by default (master prompt §1.7): below `panels.length * 160.0` logical pixels along the main axis, falls back to a non-resizable, scrollable stacked layout instead of squishing panels below a usable size.
- Panel sizes are fractions (`0.0`–`1.0`) of the group's own main-axis extent, not pixels — the full `sizes` list always sums to `1.0`.
- Drag/keyboard resize is "stop at limit, no cascade": a handle only ever trades size between its two immediately-adjacent panels; hitting one panel's min/max stops the drag there without affecting any other panel.
- `NibResizablePanels` must be given bounded constraints in both axes (e.g. wrapped in a sized ancestor) — same requirement `NibDataTable`'s examples already follow via `SizedBox(height: ...)`.
- Evidence requirement: run `flutter test` and `flutter analyze` yourself and report actual output before claiming a task works — no "tests added" claims without a shown pass (master prompt §1.6).

---

### Task 1: Data model + constraint-solving math

**Files:**
- Create: `lib/src/resizable_panels/nib_resizable_panel.dart`
- Create: `lib/src/resizable_panels/nib_resizable_panels_math.dart`
- Test: `test/resizable_panels/nib_resizable_panels_math_test.dart`

**Interfaces:**
- Consumes: nothing (foundational).
- Produces: `NibResizablePanel({required Widget child, double minSize = 0.1, double maxSize = 1.0, double? initialSize})`; `List<double> normalizedInitialSizes(List<NibResizablePanel> panels)`; `List<double> applyHandleDelta({required List<double> sizes, required List<NibResizablePanel> panels, required int handleIndex, required double deltaFraction})`; `List<double> resetHandlePair({required List<double> sizes, required List<double> initialSizes, required int handleIndex})`. Every later task depends on these four signatures exactly.

- [ ] **Step 1: Write the failing tests**

Create `test/resizable_panels/nib_resizable_panels_math_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/resizable_panels/nib_resizable_panels_math_test.dart`
Expected: FAIL — `package:nib_components/src/resizable_panels/nib_resizable_panel.dart` and `nib_resizable_panels_math.dart` don't exist yet.

- [ ] **Step 3: Implement the data model**

Create `lib/src/resizable_panels/nib_resizable_panel.dart`:

```dart
import 'package:flutter/widgets.dart';

/// One panel in a `NibResizablePanels` group.
///
/// [minSize]/[maxSize]/[initialSize] are fractions (`0.0`–`1.0`) of the
/// group's own main-axis extent, not pixels — this keeps the layout correct
/// across window/viewport resizes without reconciling absolute pixel bounds
/// against a shrinking or growing container.
@immutable
class NibResizablePanel {
  /// Creates a panel. If [initialSize] is omitted, this panel shares the
  /// fraction left over after every panel with an explicit [initialSize] is
  /// accounted for, split evenly among the other omitted panels.
  const NibResizablePanel({
    required this.child,
    this.minSize = 0.1,
    this.maxSize = 1.0,
    this.initialSize,
  }) : assert(minSize >= 0.0 && minSize <= 1.0, 'minSize must be within 0.0-1.0.'),
       assert(maxSize >= 0.0 && maxSize <= 1.0, 'maxSize must be within 0.0-1.0.'),
       assert(minSize <= maxSize, 'minSize must be <= maxSize.'),
       assert(
         initialSize == null || (initialSize >= 0.0 && initialSize <= 1.0),
         'initialSize must be within 0.0-1.0.',
       );

  /// The panel's content.
  final Widget child;

  /// The minimum fraction (of the group's main-axis extent) this panel can
  /// be resized to. Defaults to `0.1` (10%).
  final double minSize;

  /// The maximum fraction this panel can be resized to. Defaults to `1.0`
  /// (100%) — effectively unbounded, since the other panels' own minimums
  /// prevent any single panel from actually reaching it.
  final double maxSize;

  /// This panel's starting fraction of the group. `null` shares the
  /// remaining space evenly with every other panel that also omits it.
  final double? initialSize;
}
```

- [ ] **Step 4: Implement the constraint-solving math**

Create `lib/src/resizable_panels/nib_resizable_panels_math.dart`:

```dart
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

  final raw = <double>[for (var i = 0; i < panels.length; i++) explicit[i] ?? implicitShare];

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

  var newI = (sizes[i] + deltaFraction).clamp(panels[i].minSize, panels[i].maxSize);
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/resizable_panels/nib_resizable_panels_math_test.dart`
Expected: PASS (12 tests)

- [ ] **Step 6: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/src/resizable_panels/nib_resizable_panel.dart lib/src/resizable_panels/nib_resizable_panels_math.dart test/resizable_panels/nib_resizable_panels_math_test.dart
git commit -m "feat(resizable-panels): panel data model + constraint-solving math"
```

---

### Task 2: `NibResizablePanelsController`

**Files:**
- Create: `lib/src/resizable_panels/nib_resizable_panels_controller.dart`
- Test: `test/resizable_panels/nib_resizable_panels_controller_test.dart`

**Interfaces:**
- Consumes: `NibResizablePanel`, `normalizedInitialSizes`, `applyHandleDelta`, `resetHandlePair` (Task 1).
- Produces: `NibResizablePanelsController({List<double>? initialSizes})` extends `ChangeNotifier`, with `List<double> get sizes`, `void attach(List<NibResizablePanel> panels)`, `void setSizes(List<double> sizes)`, `void applyDelta(List<NibResizablePanel> panels, int handleIndex, double deltaFraction)`, `void resetPanelPair(int handleIndex)`, `void resetAll()`. Task 4's `NibResizablePanels` widget calls all five non-constructor methods; later tasks read `.sizes`.

- [ ] **Step 1: Write the failing tests**

Create `test/resizable_panels/nib_resizable_panels_controller_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/resizable_panels/nib_resizable_panel.dart';
import 'package:nib_components/src/resizable_panels/nib_resizable_panels_controller.dart';

List<NibResizablePanel> _panels(List<double?> initialSizes) {
  return [for (final size in initialSizes) NibResizablePanel(child: const SizedBox(), initialSize: size)];
}

void main() {
  test('sizes is empty before attach', () {
    final controller = NibResizablePanelsController();
    expect(controller.sizes, isEmpty);
  });

  test('attach seeds sizes from normalizedInitialSizes on first call', () {
    final controller = NibResizablePanelsController();
    controller.attach(_panels([0.25, 0.75]));
    expect(controller.sizes, [closeTo(0.25, 1e-9), closeTo(0.75, 1e-9)]);
  });

  test('attach is a no-op once already seeded with the same panel count', () {
    final controller = NibResizablePanelsController();
    controller.attach(_panels([0.25, 0.75]));
    controller.applyDelta(_panels([0.25, 0.75]), 0, 0.1);
    final afterDrag = controller.sizes;
    // A second attach call with a different (but same-length) initial split
    // must not reseed and discard the drag.
    controller.attach(_panels([0.5, 0.5]));
    expect(controller.sizes, afterDrag);
  });

  test('constructing with initialSizes seeds sizes immediately, without attach', () {
    final controller = NibResizablePanelsController(initialSizes: [0.4, 0.6]);
    expect(controller.sizes, [0.4, 0.6]);
  });

  test('setSizes normalizes to sum 1.0 and notifies listeners', () {
    final controller = NibResizablePanelsController(initialSizes: [0.5, 0.5]);
    var notified = 0;
    controller.addListener(() => notified++);
    controller.setSizes([0.6, 0.6]);
    expect(controller.sizes, [closeTo(0.5, 1e-9), closeTo(0.5, 1e-9)]);
    expect(notified, 1);
  });

  test('applyDelta updates the adjacent pair and notifies listeners', () {
    final controller = NibResizablePanelsController(initialSizes: [0.5, 0.5]);
    var notified = 0;
    controller.addListener(() => notified++);
    controller.applyDelta(_panels([null, null]), 0, 0.1);
    expect(controller.sizes, [closeTo(0.6, 1e-9), closeTo(0.4, 1e-9)]);
    expect(notified, 1);
  });

  test('resetPanelPair restores the pair to its initial ratio and notifies', () {
    final controller = NibResizablePanelsController();
    controller.attach(_panels([0.5, 0.5]));
    controller.applyDelta(_panels([null, null]), 0, 0.2);
    var notified = 0;
    controller.addListener(() => notified++);
    controller.resetPanelPair(0);
    expect(controller.sizes, [closeTo(0.5, 1e-9), closeTo(0.5, 1e-9)]);
    expect(notified, 1);
  });

  test('resetAll restores every panel to its initial fraction and notifies', () {
    final controller = NibResizablePanelsController();
    controller.attach(_panels([0.2, 0.3, 0.5]));
    controller.applyDelta(_panels([null, null, null]), 1, 0.1);
    var notified = 0;
    controller.addListener(() => notified++);
    controller.resetAll();
    expect(controller.sizes, [closeTo(0.2, 1e-9), closeTo(0.3, 1e-9), closeTo(0.5, 1e-9)]);
    expect(notified, 1);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/resizable_panels/nib_resizable_panels_controller_test.dart`
Expected: FAIL — `nib_resizable_panels_controller.dart` doesn't exist yet.

- [ ] **Step 3: Implement the controller**

Create `lib/src/resizable_panels/nib_resizable_panels_controller.dart`:

```dart
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
      _initialSizes = initialSizes == null ? null : List<double>.of(initialSizes);

  List<double>? _sizes;
  List<double>? _initialSizes;

  /// The current per-panel size fractions, always summing to `1.0` once
  /// seeded. Empty until [attach] has run (or [initialSizes] was passed to
  /// the constructor).
  List<double> get sizes => List<double>.unmodifiable(_sizes ?? const <double>[]);

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
    _sizes = total > 0.0 ? [for (final v in sizes) v / total] : List<double>.of(sizes);
    notifyListeners();
  }

  /// Applies a drag/keyboard delta to the panel pair adjacent to
  /// [handleIndex]. See [applyHandleDelta].
  void applyDelta(List<NibResizablePanel> panels, int handleIndex, double deltaFraction) {
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
    _sizes = resetHandlePair(sizes: _sizes!, initialSizes: _initialSizes!, handleIndex: handleIndex);
    notifyListeners();
  }

  /// Resets every panel to its original initial-size fraction.
  void resetAll() {
    if (_initialSizes == null) return;
    _sizes = List<double>.of(_initialSizes!);
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/resizable_panels/nib_resizable_panels_controller_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 5: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/resizable_panels/nib_resizable_panels_controller.dart test/resizable_panels/nib_resizable_panels_controller_test.dart
git commit -m "feat(resizable-panels): add NibResizablePanelsController"
```

---

### Task 3: Custom RenderObject — pure layout

**Files:**
- Create: `lib/src/resizable_panels/render_resizable_panels.dart`
- Test: `test/resizable_panels/render_resizable_panels_test.dart`

**Interfaces:**
- Consumes: nothing from Tasks 1–2 (this file only needs `Axis`/`List<double>`, not the panel/controller types) — it's a pure layout primitive.
- Produces: `const double kNibResizablePanelsHandleHitWidth = 12.0`; `NibResizablePanelsLayout({Key? key, required Axis direction, required List<double> sizes, required List<Widget> children})` (a `MultiChildRenderObjectWidget` — `children` must alternate panel/handle/panel/.../panel, i.e. `2 * sizes.length - 1` children). Task 4 builds this widget with real panel/handle children.

- [ ] **Step 1: Write the failing tests**

Create `test/resizable_panels/render_resizable_panels_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/resizable_panels/render_resizable_panels.dart';

Widget _slot(Key key) => SizedBox.expand(key: key);

void main() {
  testWidgets('horizontal: lays out panels at their given fractions with fixed handle slots between them', (
    tester,
  ) async {
    final panel0 = GlobalKey();
    final handle0 = GlobalKey();
    final panel1 = GlobalKey();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 100,
          child: NibResizablePanelsLayout(
            direction: Axis.horizontal,
            sizes: const [0.5, 0.5],
            children: [_slot(panel0), _slot(handle0), _slot(panel1)],
          ),
        ),
      ),
    );

    final panelsMain = 400 - kNibResizablePanelsHandleHitWidth;
    expect(tester.getSize(find.byKey(panel0)), Size(panelsMain * 0.5, 100));
    expect(tester.getTopLeft(find.byKey(panel0)), Offset.zero);

    expect(tester.getSize(find.byKey(handle0)), const Size(kNibResizablePanelsHandleHitWidth, 100));
    expect(tester.getTopLeft(find.byKey(handle0)), Offset(panelsMain * 0.5, 0));

    expect(tester.getSize(find.byKey(panel1)), Size(panelsMain * 0.5, 100));
    expect(
      tester.getTopLeft(find.byKey(panel1)),
      Offset(panelsMain * 0.5 + kNibResizablePanelsHandleHitWidth, 0),
    );
  });

  testWidgets('vertical: lays out panels stacked top-to-bottom with fixed handle slots between them', (
    tester,
  ) async {
    final panel0 = GlobalKey();
    final handle0 = GlobalKey();
    final panel1 = GlobalKey();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 100,
          height: 300,
          child: NibResizablePanelsLayout(
            direction: Axis.vertical,
            sizes: const [0.5, 0.5],
            children: [_slot(panel0), _slot(handle0), _slot(panel1)],
          ),
        ),
      ),
    );

    final panelsMain = 300 - kNibResizablePanelsHandleHitWidth;
    expect(tester.getSize(find.byKey(panel0)), Size(100, panelsMain * 0.5));
    expect(tester.getSize(find.byKey(handle0)), const Size(100, kNibResizablePanelsHandleHitWidth));
    expect(tester.getTopLeft(find.byKey(handle0)), Offset(0, panelsMain * 0.5));
  });

  testWidgets('uneven sizes produce proportionally uneven extents; the last panel absorbs any rounding remainder', (
    tester,
  ) async {
    final panel0 = GlobalKey();
    final panel1 = GlobalKey();
    final panel2 = GlobalKey();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 50,
          child: NibResizablePanelsLayout(
            direction: Axis.horizontal,
            sizes: const [0.2, 0.3, 0.5],
            children: [_slot(panel0), _slot(GlobalKey()), _slot(panel1), _slot(GlobalKey()), _slot(panel2)],
          ),
        ),
      ),
    );

    final panelsMain = 300 - (2 * kNibResizablePanelsHandleHitWidth);
    expect(tester.getSize(find.byKey(panel0)).width, closeTo(panelsMain * 0.2, 0.01));
    expect(tester.getSize(find.byKey(panel1)).width, closeTo(panelsMain * 0.3, 0.01));
    expect(tester.getSize(find.byKey(panel2)).width, closeTo(panelsMain * 0.5, 0.01));

    final totalWidth =
        tester.getSize(find.byKey(panel0)).width +
        tester.getSize(find.byKey(panel1)).width +
        tester.getSize(find.byKey(panel2)).width +
        (2 * kNibResizablePanelsHandleHitWidth);
    expect(totalWidth, closeTo(300, 0.01));
  });

  testWidgets('every child (panel and handle) fills the full cross extent', (tester) async {
    final panel0 = GlobalKey();
    final handle0 = GlobalKey();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 200,
          height: 80,
          child: NibResizablePanelsLayout(
            direction: Axis.horizontal,
            sizes: const [0.5, 0.5],
            children: [_slot(panel0), _slot(handle0), _slot(GlobalKey())],
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(panel0)).height, 80);
    expect(tester.getSize(find.byKey(handle0)).height, 80);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/resizable_panels/render_resizable_panels_test.dart`
Expected: FAIL — `render_resizable_panels.dart` doesn't exist yet.

- [ ] **Step 3: Implement the RenderObject and its widget**

Create `lib/src/resizable_panels/render_resizable_panels.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Fixed hit/paint width reserved for each handle slot between panels, in
/// logical pixels. Wider than the thin visual line `NibResizablePanelsHandle`
/// paints inside it, so the handle stays draggable without pixel-perfect
/// precision (the same touch-target concern already raised for Data Table).
const double kNibResizablePanelsHandleHitWidth = 12.0;

class _PanelsParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays out an interleaved `[panel, handle, panel, handle, ..., panel]`
/// child list along [direction]: each panel child gets a tight main-axis
/// extent of `sizes[i] * panelsMainExtent` (the group's main extent minus
/// every handle slot), each handle child gets a fixed
/// [kNibResizablePanelsHandleHitWidth]. Every child is tight to the incoming
/// constraints' cross extent.
///
/// This is a pure function of `(sizes, direction, constraints)` — it owns no
/// gesture/interaction state. `NibResizablePanelsHandle` children (built by
/// `NibResizablePanels`) own hover/drag/keyboard interaction themselves and
/// report changes back up via callbacks; this render object only answers
/// "given these fractions, where does everything go."
class NibResizablePanelsRenderObject extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PanelsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PanelsParentData> {
  NibResizablePanelsRenderObject({required List<double> sizes, required Axis direction})
    : _sizes = sizes,
      _direction = direction;

  List<double> _sizes;
  List<double> get sizes => _sizes;
  set sizes(List<double> value) {
    if (listEquals(_sizes, value)) return;
    _sizes = value;
    markNeedsLayout();
  }

  Axis _direction;
  Axis get direction => _direction;
  set direction(Axis value) {
    if (_direction == value) return;
    _direction = value;
    markNeedsLayout();
  }

  int get _panelCount => (childCount + 1) ~/ 2;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PanelsParentData) {
      child.parentData = _PanelsParentData();
    }
  }

  @override
  void performLayout() {
    assert(
      constraints.maxWidth.isFinite && constraints.maxHeight.isFinite,
      'NibResizablePanels must be given bounded constraints in both axes '
      '(e.g. wrap it in a SizedBox or Expanded within a bounded parent).',
    );

    final horizontal = _direction == Axis.horizontal;
    final totalMain = horizontal ? constraints.maxWidth : constraints.maxHeight;
    final crossExtent = horizontal ? constraints.maxHeight : constraints.maxWidth;
    final handleCount = _panelCount - 1;
    final panelsMain = totalMain - (handleCount * kNibResizablePanelsHandleHitWidth);

    var child = firstChild;
    var index = 0;
    var panelIndex = 0;
    var cursor = 0.0;
    var panelMainSum = 0.0;

    while (child != null) {
      final parentData = child.parentData! as _PanelsParentData;
      final isHandle = index.isOdd;

      final double mainExtent;
      if (isHandle) {
        mainExtent = kNibResizablePanelsHandleHitWidth;
      } else {
        final isLastPanel = panelIndex == _panelCount - 1;
        mainExtent = isLastPanel ? panelsMain - panelMainSum : panelsMain * _sizes[panelIndex];
        panelMainSum += mainExtent;
        panelIndex++;
      }

      final childConstraints = horizontal
          ? BoxConstraints.tightFor(width: mainExtent, height: crossExtent)
          : BoxConstraints.tightFor(width: crossExtent, height: mainExtent);
      child.layout(childConstraints);
      parentData.offset = horizontal ? Offset(cursor, 0) : Offset(0, cursor);
      cursor += mainExtent;

      index++;
      child = parentData.nextSibling;
    }

    size = constraints.constrain(horizontal ? Size(totalMain, crossExtent) : Size(crossExtent, totalMain));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

/// Widget wrapper for [NibResizablePanelsRenderObject]. [children] must
/// alternate panel/handle/panel/.../panel — `2 * sizes.length - 1` widgets
/// total. Not part of the public API; `NibResizablePanels` (Task 4) is the
/// consumer-facing widget.
class NibResizablePanelsLayout extends MultiChildRenderObjectWidget {
  const NibResizablePanelsLayout({super.key, required this.direction, required this.sizes, required super.children});

  final Axis direction;
  final List<double> sizes;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return NibResizablePanelsRenderObject(sizes: sizes, direction: direction);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as NibResizablePanelsRenderObject)
      ..sizes = sizes
      ..direction = direction;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/resizable_panels/render_resizable_panels_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/resizable_panels/render_resizable_panels.dart test/resizable_panels/render_resizable_panels_test.dart
git commit -m "feat(resizable-panels): add custom RenderObject for panel/handle layout"
```

---

### Task 4: `NibResizablePanels` public widget — composition, default render, controller-driven resize

**Files:**
- Create: `lib/src/resizable_panels/nib_resizable_panels_handle.dart` (non-interactive base: renders the line + hover color only)
- Create: `lib/src/resizable_panels/nib_resizable_panels.dart`
- Modify: `lib/nib_components.dart` (barrel exports)
- Test: `test/resizable_panels/nib_resizable_panels_test.dart`

**Interfaces:**
- Consumes: `NibResizablePanel` (Task 1), `NibResizablePanelsController` (Task 2), `NibResizablePanelsLayout`/`kNibResizablePanelsHandleHitWidth` (Task 3), `NibTheme` (existing).
- Produces: `NibResizablePanelsHandle({Key? key, required Axis direction, required double groupMainExtent, required double handleThickness, required double sizeFraction, required bool animated, required NibTransition? transition, required ValueChanged<double> onDeltaFraction, required VoidCallback onDragEnd, required VoidCallback onReset})`; `NibResizablePanels({Key? key, required Axis direction, required List<NibResizablePanel> panels, NibResizablePanelsController? controller, ValueChanged<List<double>>? onLayoutChanged, double handleThickness = 1.0, bool animated = false, NibTransition? transition})`. Tasks 5–8 modify `nib_resizable_panels_handle.dart` in place to add interactivity; every constructor parameter listed here is final for the rest of the plan.

- [ ] **Step 1: Write the failing tests**

Create `test/resizable_panels/nib_resizable_panels_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

Widget _wrap(Widget child, {double width = 400, double height = 300}) {
  return MaterialApp(
    theme: ThemeData(extensions: const [NibTheme.light]),
    home: Scaffold(body: SizedBox(width: width, height: height, child: child)),
  );
}

void main() {
  testWidgets('renders every panel child and (panels.length - 1) handles', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NibResizablePanels(
          direction: Axis.horizontal,
          panels: [
            NibResizablePanel(child: const Text('A')),
            NibResizablePanel(child: const Text('B')),
            NibResizablePanel(child: const Text('C')),
          ],
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.byType(NibResizablePanelsHandle), findsNWidgets(2));
  });

  testWidgets('default (no initialSize) splits panels evenly', (tester) async {
    final keyA = GlobalKey();
    final keyB = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        NibResizablePanels(
          direction: Axis.horizontal,
          panels: [
            NibResizablePanel(child: SizedBox.expand(key: keyA)),
            NibResizablePanel(child: SizedBox.expand(key: keyB)),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.byKey(keyA)).width, closeTo(tester.getSize(find.byKey(keyB)).width, 0.01));
  });

  testWidgets('an externally-supplied controller with initialSizes drives the initial layout', (tester) async {
    final keyA = GlobalKey();
    final keyB = GlobalKey();
    final controller = NibResizablePanelsController(initialSizes: [0.75, 0.25]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        NibResizablePanels(
          direction: Axis.horizontal,
          controller: controller,
          panels: [
            NibResizablePanel(child: SizedBox.expand(key: keyA)),
            NibResizablePanel(child: SizedBox.expand(key: keyB)),
          ],
        ),
      ),
    );

    final widthA = tester.getSize(find.byKey(keyA)).width;
    final widthB = tester.getSize(find.byKey(keyB)).width;
    expect(widthA / (widthA + widthB), closeTo(0.75, 0.01));
  });

  testWidgets('calling controller.setSizes relayouts the group', (tester) async {
    final keyA = GlobalKey();
    final keyB = GlobalKey();
    final controller = NibResizablePanelsController(initialSizes: [0.5, 0.5]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        NibResizablePanels(
          direction: Axis.horizontal,
          controller: controller,
          panels: [
            NibResizablePanel(child: SizedBox.expand(key: keyA)),
            NibResizablePanel(child: SizedBox.expand(key: keyB)),
          ],
        ),
      ),
    );

    controller.setSizes([0.2, 0.8]);
    await tester.pump();

    final widthA = tester.getSize(find.byKey(keyA)).width;
    final widthB = tester.getSize(find.byKey(keyB)).width;
    expect(widthA / (widthA + widthB), closeTo(0.2, 0.01));
  });

  testWidgets('swapping from an internal to an externally-supplied controller does not throw', (tester) async {
    final panels = [NibResizablePanel(child: const Text('A')), NibResizablePanel(child: const Text('B'))];
    await tester.pumpWidget(_wrap(NibResizablePanels(direction: Axis.horizontal, panels: panels)));

    final controller = NibResizablePanelsController(initialSizes: [0.3, 0.7]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(NibResizablePanels(direction: Axis.horizontal, controller: controller, panels: panels)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('A'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/resizable_panels/nib_resizable_panels_test.dart`
Expected: FAIL — `NibResizablePanels`/`NibResizablePanelsHandle` aren't exported/don't exist yet.

- [ ] **Step 3: Implement the (non-interactive) handle widget**

Create `lib/src/resizable_panels/nib_resizable_panels_handle.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:nib_motion/nib_motion.dart' show NibTransition;

import '../theme/nib_theme.dart';

/// The divider between two adjacent panels in a `NibResizablePanels` group.
/// Built and positioned by `NibResizablePanels`/`NibResizablePanelsLayout` —
/// not part of the public API.
///
/// This task only wires up static appearance (theme-colored line, sized to
/// [handleThickness]). Hover, drag, keyboard, and `animated` support are
/// added on top of this same widget in later tasks.
class NibResizablePanelsHandle extends StatefulWidget {
  const NibResizablePanelsHandle({
    super.key,
    required this.direction,
    required this.groupMainExtent,
    required this.handleThickness,
    required this.sizeFraction,
    required this.animated,
    required this.transition,
    required this.onDeltaFraction,
    required this.onDragEnd,
    required this.onReset,
  });

  /// The group's layout direction. Determines whether this handle paints a
  /// vertical line (horizontal group) or a horizontal line (vertical group).
  final Axis direction;

  /// The group's current main-axis extent in logical pixels — used by later
  /// tasks to convert a drag's pixel delta into a size-fraction delta.
  final double groupMainExtent;

  /// The visual thickness of the painted line, in logical pixels. The
  /// handle's hit/paint slot itself is always [kNibResizablePanelsHandleHitWidth]-wide;
  /// this is only the visible line inside it.
  final double handleThickness;

  /// The current size fraction of the panel immediately before this handle —
  /// used by later tasks for the handle's accessibility value.
  final double sizeFraction;

  /// Whether hover/active color changes animate via `NibMotion`.
  final bool animated;

  /// The transition used for the animated hover/active color change, when
  /// [animated] is `true`. `null` falls back to a short default fade.
  final NibTransition? transition;

  /// Called with a size-fraction delta while this handle is being
  /// dragged/keyboard-nudged. Wired up in Task 5/6.
  final ValueChanged<double> onDeltaFraction;

  /// Called once a drag/keyboard-nudge interaction ends. Wired up in Task
  /// 5/6.
  final VoidCallback onDragEnd;

  /// Called on double-click/tap to reset this handle's adjacent pair to
  /// their initial sizes. Wired up in Task 5.
  final VoidCallback onReset;

  @override
  State<NibResizablePanelsHandle> createState() => _NibResizablePanelsHandleState();
}

class _NibResizablePanelsHandleState extends State<NibResizablePanelsHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final horizontal = widget.direction == Axis.horizontal;
    final color = _hovered ? theme.ring : theme.border;

    final line = SizedBox(
      width: horizontal ? widget.handleThickness : double.infinity,
      height: horizontal ? double.infinity : widget.handleThickness,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Center(child: ColoredBox(color: color, child: line)),
    );
  }
}
```

- [ ] **Step 4: Implement the public widget**

Create `lib/src/resizable_panels/nib_resizable_panels.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:nib_motion/nib_motion.dart' show NibTransition;

import 'nib_resizable_panel.dart';
import 'nib_resizable_panels_controller.dart';
import 'nib_resizable_panels_handle.dart';
import 'render_resizable_panels.dart';

/// A horizontal or vertical group of resizable panels with draggable,
/// keyboard-resizable, min/max-constrained dividers between them.
///
/// ```dart
/// NibResizablePanels(
///   direction: Axis.horizontal,
///   panels: [
///     NibResizablePanel(child: Sidebar()),
///     NibResizablePanel(child: MainContent()),
///   ],
/// )
/// ```
///
/// Must be given bounded constraints in both axes (e.g. wrap it in a
/// `SizedBox` or `Expanded` within a bounded parent).
class NibResizablePanels extends StatefulWidget {
  const NibResizablePanels({
    super.key,
    required this.direction,
    required this.panels,
    this.controller,
    this.onLayoutChanged,
    this.handleThickness = 1.0,
    this.animated = false,
    this.transition,
  }) : assert(panels.length >= 2, 'NibResizablePanels requires at least 2 panels.');

  /// Whether panels are arranged left-to-right ([Axis.horizontal]) or
  /// top-to-bottom ([Axis.vertical]).
  final Axis direction;

  /// The panels in this group, in order. Must have at least 2 entries.
  final List<NibResizablePanel> panels;

  /// Optional external controller for reading/driving panel sizes
  /// programmatically. Never required for basic use — a controller is
  /// created and owned internally when this is `null`.
  final NibResizablePanelsController? controller;

  /// Called with the full sizes list whenever a drag, keyboard nudge, or
  /// double-tap reset finishes changing the layout (not on every frame of a
  /// drag) — the host app's hook for persisting the layout.
  final ValueChanged<List<double>>? onLayoutChanged;

  /// The visual thickness of each divider line, in logical pixels.
  final double handleThickness;

  /// Whether a handle's hover/active color change animates via `NibMotion`.
  final bool animated;

  /// The transition used for the animated hover/active color change, when
  /// [animated] is `true`. `null` falls back to a short default fade.
  final NibTransition? transition;

  @override
  State<NibResizablePanels> createState() => _NibResizablePanelsState();
}

class _NibResizablePanelsState extends State<NibResizablePanels> {
  late NibResizablePanelsController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant NibResizablePanels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _unbindController();
      _bindController(widget.controller);
    } else {
      _controller.attach(widget.panels);
    }
  }

  @override
  void dispose() {
    _unbindController();
    super.dispose();
  }

  void _bindController(NibResizablePanelsController? external) {
    _controller = external ?? NibResizablePanelsController();
    _ownsController = external == null;
    _controller.attach(widget.panels);
    _controller.addListener(_handleControllerChanged);
  }

  void _unbindController() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
  }

  void _handleControllerChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final sizes = _controller.sizes;
    return LayoutBuilder(
      builder: (context, constraints) {
        final groupMainExtent = widget.direction == Axis.horizontal ? constraints.maxWidth : constraints.maxHeight;

        final children = <Widget>[];
        for (var i = 0; i < widget.panels.length; i++) {
          children.add(widget.panels[i].child);
          if (i < widget.panels.length - 1) {
            final handleIndex = i;
            children.add(
              NibResizablePanelsHandle(
                key: ValueKey('nib-resizable-handle-$handleIndex'),
                direction: widget.direction,
                groupMainExtent: groupMainExtent,
                handleThickness: widget.handleThickness,
                sizeFraction: sizes[handleIndex],
                animated: widget.animated,
                transition: widget.transition,
                onDeltaFraction: (delta) => _controller.applyDelta(widget.panels, handleIndex, delta),
                onDragEnd: () => widget.onLayoutChanged?.call(_controller.sizes),
                onReset: () {
                  _controller.resetPanelPair(handleIndex);
                  widget.onLayoutChanged?.call(_controller.sizes);
                },
              ),
            );
          }
        }

        return NibResizablePanelsLayout(direction: widget.direction, sizes: sizes, children: children);
      },
    );
  }
}
```

- [ ] **Step 5: Export from the package barrel**

In `lib/nib_components.dart`, add (keep the list alphabetically grouped by directory, matching the existing style):

```dart
export 'src/resizable_panels/nib_resizable_panel.dart';
export 'src/resizable_panels/nib_resizable_panels.dart';
export 'src/resizable_panels/nib_resizable_panels_controller.dart';
export 'src/resizable_panels/nib_resizable_panels_handle.dart';
```

(`nib_resizable_panels_handle.dart` is exported because Task 4's own test asserts `find.byType(NibResizablePanelsHandle)` from `package:nib_components/nib_components.dart` — matching how `NibDataTableController`/etc. are all exported even though a consumer would rarely construct a handle directly. `render_resizable_panels.dart` and `nib_resizable_panels_math.dart` are **not** exported — they stay internal, matching the existing `nib_anchored_overlay.dart` precedent, reachable in tests only via their `package:nib_components/src/...` path.)

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/resizable_panels/nib_resizable_panels_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 7: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/src/resizable_panels/nib_resizable_panels_handle.dart lib/src/resizable_panels/nib_resizable_panels.dart lib/nib_components.dart test/resizable_panels/nib_resizable_panels_test.dart
git commit -m "feat(resizable-panels): add NibResizablePanels public widget"
```

---

### Task 5: Drag-to-resize + double-tap reset

**Files:**
- Modify: `lib/src/resizable_panels/nib_resizable_panels_handle.dart`
- Modify: `test/resizable_panels/nib_resizable_panels_test.dart` (append tests)

**Interfaces:**
- Consumes: `widget.onDeltaFraction`/`onDragEnd`/`onReset`/`groupMainExtent` (Task 4, unchanged signatures).
- Produces: dragging a handle now calls `onDeltaFraction` continuously and `onDragEnd` once on release; double-tap calls `onReset`. No new public signatures.

- [ ] **Step 1: Write the failing tests**

Append to `test/resizable_panels/nib_resizable_panels_test.dart`:

```dart
testWidgets('dragging a handle resizes its two adjacent panels only', (tester) async {
  final controller = NibResizablePanelsController(initialSizes: [1 / 3, 1 / 3, 1 / 3]);
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    _wrap(
      NibResizablePanels(
        direction: Axis.horizontal,
        controller: controller,
        panels: [
          NibResizablePanel(child: const SizedBox.expand()),
          NibResizablePanel(child: const SizedBox.expand()),
          NibResizablePanel(child: const SizedBox.expand()),
        ],
      ),
    ),
  );

  final before = controller.sizes;
  await tester.drag(find.byKey(const ValueKey('nib-resizable-handle-0')), const Offset(40, 0));
  await tester.pumpAndSettle();

  expect(controller.sizes[0], greaterThan(before[0]));
  expect(controller.sizes[1], lessThan(before[1]));
  expect(controller.sizes[2], closeTo(before[2], 1e-9)); // untouched
});

testWidgets('dragging past a minSize stops at the limit instead of cascading into the next panel', (tester) async {
  final controller = NibResizablePanelsController(initialSizes: [1 / 3, 1 / 3, 1 / 3]);
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    _wrap(
      NibResizablePanels(
        direction: Axis.horizontal,
        controller: controller,
        panels: [
          NibResizablePanel(child: const SizedBox.expand(), minSize: 0.3),
          NibResizablePanel(child: const SizedBox.expand(), minSize: 0.3),
          NibResizablePanel(child: const SizedBox.expand(), minSize: 0.3),
        ],
      ),
    ),
  );

  // Drag handle 0 far enough left that panel 0 would go well under 0.3 if uncapped.
  await tester.drag(find.byKey(const ValueKey('nib-resizable-handle-0')), const Offset(-300, 0));
  await tester.pumpAndSettle();

  expect(controller.sizes[0], closeTo(0.3, 0.01));
  expect(controller.sizes[2], closeTo(1 / 3, 1e-9)); // untouched
});

testWidgets('onLayoutChanged fires once when the drag ends, not per frame', (tester) async {
  var callCount = 0;
  List<double>? lastLayout;

  await tester.pumpWidget(
    _wrap(
      NibResizablePanels(
        direction: Axis.horizontal,
        panels: [NibResizablePanel(child: const SizedBox.expand()), NibResizablePanel(child: const SizedBox.expand())],
        onLayoutChanged: (sizes) {
          callCount++;
          lastLayout = sizes;
        },
      ),
    ),
  );

  await tester.drag(find.byKey(const ValueKey('nib-resizable-handle-0')), const Offset(40, 0));
  await tester.pumpAndSettle();

  expect(callCount, 1);
  expect(lastLayout, isNotNull);
});

testWidgets('double-tap a handle resets its adjacent pair, leaving other panels untouched', (tester) async {
  final controller = NibResizablePanelsController(initialSizes: [0.2, 0.3, 0.5]);
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    _wrap(
      NibResizablePanels(
        direction: Axis.horizontal,
        controller: controller,
        panels: [
          NibResizablePanel(child: const SizedBox.expand(), initialSize: 0.2),
          NibResizablePanel(child: const SizedBox.expand(), initialSize: 0.3),
          NibResizablePanel(child: const SizedBox.expand(), initialSize: 0.5),
        ],
      ),
    ),
  );

  await tester.drag(find.byKey(const ValueKey('nib-resizable-handle-0')), const Offset(40, 0));
  await tester.pumpAndSettle();
  expect(controller.sizes[0], isNot(closeTo(0.2, 1e-9)));

  await tester.tap(find.byKey(const ValueKey('nib-resizable-handle-0')));
  await tester.pump(kDoubleTapMinTime);
  await tester.tap(find.byKey(const ValueKey('nib-resizable-handle-0')));
  await tester.pumpAndSettle();

  expect(controller.sizes[0], closeTo(0.2, 0.01));
  expect(controller.sizes[1], closeTo(0.3, 0.01));
  expect(controller.sizes[2], closeTo(0.5, 1e-9)); // untouched
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/resizable_panels/nib_resizable_panels_test.dart`
Expected: FAIL — handles don't respond to drag/double-tap yet.

- [ ] **Step 3: Add drag + double-tap interaction**

In `lib/src/resizable_panels/nib_resizable_panels_handle.dart`, add the import and replace `_NibResizablePanelsHandleState`'s `build` method:

```dart
import 'package:flutter/gestures.dart' show DragUpdateDetails;
```

```dart
class _NibResizablePanelsHandleState extends State<NibResizablePanelsHandle> {
  bool _hovered = false;

  void _handleDragUpdate(double primaryDelta) {
    if (widget.groupMainExtent <= 0) return;
    widget.onDeltaFraction(primaryDelta / widget.groupMainExtent);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final horizontal = widget.direction == Axis.horizontal;
    final color = _hovered ? theme.ring : theme.border;

    final line = SizedBox(
      width: horizontal ? widget.handleThickness : double.infinity,
      height: horizontal ? double.infinity : widget.handleThickness,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: horizontal ? (DragUpdateDetails d) => _handleDragUpdate(d.delta.dx) : null,
        onHorizontalDragEnd: horizontal ? (_) => widget.onDragEnd() : null,
        onVerticalDragUpdate: horizontal ? null : (DragUpdateDetails d) => _handleDragUpdate(d.delta.dy),
        onVerticalDragEnd: horizontal ? null : (_) => widget.onDragEnd(),
        onDoubleTap: widget.onReset,
        child: Center(child: ColoredBox(color: color, child: line)),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/resizable_panels/nib_resizable_panels_test.dart`
Expected: PASS (9 tests)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/resizable_panels/nib_resizable_panels_handle.dart test/resizable_panels/nib_resizable_panels_test.dart
git commit -m "feat(resizable-panels): drag-to-resize and double-tap reset"
```

---

### Task 6: Keyboard nudge + Semantics

**Files:**
- Modify: `lib/src/resizable_panels/nib_resizable_panels_handle.dart`
- Modify: `test/resizable_panels/nib_resizable_panels_test.dart` (append tests)

**Interfaces:**
- Consumes: `widget.onDeltaFraction`/`onDragEnd` (unchanged).
- Produces: `const double kNibResizablePanelsKeyboardStep = 0.02` (new public constant, exported alongside the handle). Each handle is independently focusable; arrow keys / Home / End nudge it; `Semantics` exposes increase/decrease actions doing the same.

- [ ] **Step 1: Write the failing tests**

Append to `test/resizable_panels/nib_resizable_panels_test.dart`:

```dart
testWidgets('arrow-key nudge on a focused handle resizes the adjacent pair by the fixed step', (tester) async {
  final controller = NibResizablePanelsController(initialSizes: [0.5, 0.5]);
  addTearDown(controller.dispose);
  List<double>? lastLayout;

  await tester.pumpWidget(
    _wrap(
      NibResizablePanels(
        direction: Axis.horizontal,
        controller: controller,
        panels: [NibResizablePanel(child: const SizedBox.expand()), NibResizablePanel(child: const SizedBox.expand())],
        onLayoutChanged: (sizes) => lastLayout = sizes,
      ),
    ),
  );

  final handleFinder = find.byKey(const ValueKey('nib-resizable-handle-0'));
  await tester.tap(handleFinder);
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await tester.pumpAndSettle();

  expect(controller.sizes[0], closeTo(0.5 + kNibResizablePanelsKeyboardStep, 1e-9));
  expect(lastLayout, isNotNull);
});

testWidgets('Home/End jump the focused handle to its adjacent pair extremes', (tester) async {
  final controller = NibResizablePanelsController(initialSizes: [0.5, 0.5]);
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    _wrap(
      NibResizablePanels(
        direction: Axis.horizontal,
        controller: controller,
        panels: [
          NibResizablePanel(child: const SizedBox.expand(), minSize: 0.2, maxSize: 0.8),
          NibResizablePanel(child: const SizedBox.expand(), minSize: 0.2, maxSize: 0.8),
        ],
      ),
    ),
  );

  final handleFinder = find.byKey(const ValueKey('nib-resizable-handle-0'));
  await tester.tap(handleFinder);
  await tester.pump();

  await tester.sendKeyEvent(LogicalKeyboardKey.end);
  await tester.pumpAndSettle();
  expect(controller.sizes[0], closeTo(0.8, 0.01));

  await tester.sendKeyEvent(LogicalKeyboardKey.home);
  await tester.pumpAndSettle();
  expect(controller.sizes[0], closeTo(0.2, 0.01));
});

testWidgets('the handle exposes resize-handle semantics with a percentage value', (tester) async {
  final handle = tester.ensureSemantics();
  addTearDown(handle.dispose);

  await tester.pumpWidget(
    _wrap(
      NibResizablePanels(
        direction: Axis.horizontal,
        controller: NibResizablePanelsController(initialSizes: [0.5, 0.5]),
        panels: [NibResizablePanel(child: const SizedBox.expand()), NibResizablePanel(child: const SizedBox.expand())],
      ),
    ),
  );

  expect(
    tester.getSemantics(find.byKey(const ValueKey('nib-resizable-handle-0'))),
    matchesSemantics(label: 'Resize handle', value: '50%', hasIncreaseAction: true, hasDecreaseAction: true),
  );
});
```

Add the required import at the top of `test/resizable_panels/nib_resizable_panels_test.dart`:

```dart
import 'package:flutter/services.dart';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/resizable_panels/nib_resizable_panels_test.dart`
Expected: FAIL — handles aren't focusable/keyboard-responsive and expose no semantics yet.

- [ ] **Step 3: Add keyboard + Semantics support**

In `lib/src/resizable_panels/nib_resizable_panels_handle.dart`, add the import:

```dart
import 'package:flutter/services.dart';
```

Add the step constant above the class, and replace `_NibResizablePanelsHandleState` with:

```dart
/// The fraction (of the group's main-axis extent) a keyboard arrow-key
/// nudge moves a handle by.
const double kNibResizablePanelsKeyboardStep = 0.02;

class _NibResizablePanelsHandleState extends State<NibResizablePanelsHandle> {
  bool _hovered = false;

  void _handleDragUpdate(double primaryDelta) {
    if (widget.groupMainExtent <= 0) return;
    widget.onDeltaFraction(primaryDelta / widget.groupMainExtent);
  }

  void _nudge(double delta) {
    widget.onDeltaFraction(delta);
    widget.onDragEnd();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final horizontal = widget.direction == Axis.horizontal;
    final key = event.logicalKey;

    double? delta;
    if (key == LogicalKeyboardKey.home) {
      delta = -1.0;
    } else if (key == LogicalKeyboardKey.end) {
      delta = 1.0;
    } else if (horizontal && key == LogicalKeyboardKey.arrowLeft) {
      delta = -kNibResizablePanelsKeyboardStep;
    } else if (horizontal && key == LogicalKeyboardKey.arrowRight) {
      delta = kNibResizablePanelsKeyboardStep;
    } else if (!horizontal && key == LogicalKeyboardKey.arrowUp) {
      delta = -kNibResizablePanelsKeyboardStep;
    } else if (!horizontal && key == LogicalKeyboardKey.arrowDown) {
      delta = kNibResizablePanelsKeyboardStep;
    }

    if (delta == null) return KeyEventResult.ignored;
    _nudge(delta);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final horizontal = widget.direction == Axis.horizontal;
    final color = _hovered ? theme.ring : theme.border;
    final percent = (widget.sizeFraction * 100).round();

    final line = SizedBox(
      width: horizontal ? widget.handleThickness : double.infinity,
      height: horizontal ? double.infinity : widget.handleThickness,
    );

    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: Semantics(
        label: 'Resize handle',
        value: '$percent%',
        increasedValue: '${((widget.sizeFraction + kNibResizablePanelsKeyboardStep) * 100).round()}%',
        decreasedValue: '${((widget.sizeFraction - kNibResizablePanelsKeyboardStep) * 100).round()}%',
        onIncrease: () => _nudge(kNibResizablePanelsKeyboardStep),
        onDecrease: () => _nudge(-kNibResizablePanelsKeyboardStep),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: horizontal ? (DragUpdateDetails d) => _handleDragUpdate(d.delta.dx) : null,
            onHorizontalDragEnd: horizontal ? (_) => widget.onDragEnd() : null,
            onVerticalDragUpdate: horizontal ? null : (DragUpdateDetails d) => _handleDragUpdate(d.delta.dy),
            onVerticalDragEnd: horizontal ? null : (_) => widget.onDragEnd(),
            onDoubleTap: widget.onReset,
            child: Center(child: ColoredBox(color: color, child: line)),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/resizable_panels/nib_resizable_panels_test.dart`
Expected: PASS (12 tests)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/resizable_panels/nib_resizable_panels_handle.dart test/resizable_panels/nib_resizable_panels_test.dart
git commit -m "feat(resizable-panels): keyboard nudge (arrow/Home/End) + Semantics"
```

---

### Task 7: `animated: bool` — NibMotion hover/active color transition

**Files:**
- Modify: `lib/src/resizable_panels/nib_resizable_panels_handle.dart`
- Modify: `test/resizable_panels/nib_resizable_panels_test.dart` (append tests)

**Interfaces:**
- Consumes: `widget.animated`, `widget.transition` (Task 4, unchanged).
- Produces: when `animated: true`, the handle's line is wrapped in `NibMotion`; when `false`, zero `NibMotion` widgets are built. No new public signatures.

- [ ] **Step 1: Write the failing tests**

Append to `test/resizable_panels/nib_resizable_panels_test.dart`:

```dart
testWidgets('animated: false builds zero NibMotion widgets', (tester) async {
  await tester.pumpWidget(
    _wrap(
      NibResizablePanels(
        direction: Axis.horizontal,
        panels: [NibResizablePanel(child: const SizedBox.expand()), NibResizablePanel(child: const SizedBox.expand())],
      ),
    ),
  );

  expect(find.byType(NibMotion), findsNothing);
});

testWidgets('animated: true wraps each handle line in NibMotion', (tester) async {
  await tester.pumpWidget(
    _wrap(
      NibResizablePanels(
        direction: Axis.horizontal,
        animated: true,
        panels: [
          NibResizablePanel(child: const SizedBox.expand()),
          NibResizablePanel(child: const SizedBox.expand()),
          NibResizablePanel(child: const SizedBox.expand()),
        ],
      ),
    ),
  );

  expect(find.byType(NibMotion), findsNWidgets(2));
});
```

Add the required import at the top of `test/resizable_panels/nib_resizable_panels_test.dart`:

```dart
import 'package:nib_motion/nib_motion.dart';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/resizable_panels/nib_resizable_panels_test.dart`
Expected: FAIL — `animated: true` doesn't build any `NibMotion` widgets yet.

- [ ] **Step 3: Wire in NibMotion for the animated hover/active color**

In `lib/src/resizable_panels/nib_resizable_panels_handle.dart`, add the import:

```dart
import 'package:nib_motion/nib_motion.dart' show NibAnim, NibMotion, NibTransition;
```

(replace the existing `show NibTransition` import with the wider `show NibAnim, NibMotion, NibTransition` above), then replace the `line`-building lines inside `build`:

```dart
    final baseLine = SizedBox(
      width: horizontal ? widget.handleThickness : double.infinity,
      height: horizontal ? double.infinity : widget.handleThickness,
    );

    final line = widget.animated
        ? NibMotion(
            animate: NibAnim(color: color),
            transition: widget.transition ?? const NibTransition(duration: Duration(milliseconds: 120)),
            child: baseLine,
          )
        : ColoredBox(color: color, child: baseLine);
```

and update the final `child: Center(...)` line to use `line` directly instead of re-wrapping it in `ColoredBox`:

```dart
            child: Center(child: line),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/resizable_panels/nib_resizable_panels_test.dart`
Expected: PASS (14 tests)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/resizable_panels/nib_resizable_panels_handle.dart test/resizable_panels/nib_resizable_panels_test.dart
git commit -m "feat(resizable-panels): animated hover/active handle color via NibMotion"
```

---

### Task 8: Narrow-viewport fallback + nested-groups verification

**Files:**
- Modify: `lib/src/resizable_panels/nib_resizable_panels.dart`
- Modify: `test/resizable_panels/nib_resizable_panels_test.dart` (append tests)

**Interfaces:**
- Consumes: nothing new.
- Produces: `const double kNibResizablePanelsNarrowFallbackPanelExtent = 160.0` (new public constant, exported from `nib_resizable_panels.dart`). Below `panels.length * kNibResizablePanelsNarrowFallbackPanelExtent` along the main axis, `NibResizablePanels` renders a scrollable, handle-less stack instead.

- [ ] **Step 1: Write the failing tests**

Append to `test/resizable_panels/nib_resizable_panels_test.dart`:

```dart
testWidgets('narrow viewport falls back to a scrollable stack with no handles, no overflow', (tester) async {
  await tester.pumpWidget(
    _wrap(
      NibResizablePanels(
        direction: Axis.horizontal,
        panels: [
          NibResizablePanel(child: const SizedBox(height: 40, child: Text('A'))),
          NibResizablePanel(child: const SizedBox(height: 40, child: Text('B'))),
          NibResizablePanel(child: const SizedBox(height: 40, child: Text('C'))),
        ],
      ),
      width: 300, // below 3 * 160
      height: 200,
    ),
  );

  expect(tester.takeException(), isNull);
  expect(find.byType(NibResizablePanelsHandle), findsNothing);
  expect(find.byType(SingleChildScrollView), findsOneWidget);
  expect(find.text('A'), findsOneWidget);
  expect(find.text('B'), findsOneWidget);
  expect(find.text('C'), findsOneWidget);
});

testWidgets('wide viewport keeps normal resizable behavior with handles present', (tester) async {
  await tester.pumpWidget(
    _wrap(
      NibResizablePanels(
        direction: Axis.horizontal,
        panels: [NibResizablePanel(child: const SizedBox.expand()), NibResizablePanel(child: const SizedBox.expand())],
      ),
      width: 400, // above 2 * 160
    ),
  );

  expect(find.byType(NibResizablePanelsHandle), findsOneWidget);
  expect(find.byType(SingleChildScrollView), findsNothing);
});

testWidgets('a NibResizablePanels nested inside another panel lays out and drags independently at both levels', (
  tester,
) async {
  final outerController = NibResizablePanelsController(initialSizes: [0.5, 0.5]);
  final innerController = NibResizablePanelsController(initialSizes: [0.5, 0.5]);
  addTearDown(outerController.dispose);
  addTearDown(innerController.dispose);

  await tester.pumpWidget(
    _wrap(
      NibResizablePanels(
        direction: Axis.vertical,
        controller: outerController,
        panels: [
          NibResizablePanel(
            child: NibResizablePanels(
              direction: Axis.horizontal,
              controller: innerController,
              panels: [
                NibResizablePanel(child: const SizedBox.expand()),
                NibResizablePanel(child: const SizedBox.expand()),
              ],
            ),
          ),
          NibResizablePanel(child: const SizedBox.expand()),
        ],
      ),
      width: 400,
      height: 400,
    ),
  );

  expect(tester.takeException(), isNull);
  await tester.drag(find.byKey(const ValueKey('nib-resizable-handle-0')).last, const Offset(40, 0));
  await tester.pumpAndSettle();

  expect(innerController.sizes[0], isNot(closeTo(0.5, 1e-9)));
  expect(outerController.sizes, [closeTo(0.5, 1e-9), closeTo(0.5, 1e-9)]); // outer untouched
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/resizable_panels/nib_resizable_panels_test.dart`
Expected: FAIL — no narrow-viewport fallback exists yet (the first two new tests fail; the nesting test likely already passes since it's just composition, confirming no special-case code is needed for nesting itself).

- [ ] **Step 3: Add the narrow-viewport fallback**

In `lib/src/resizable_panels/nib_resizable_panels.dart`, add the constant near the top of the file (after the imports):

```dart
/// Below `panels.length * kNibResizablePanelsNarrowFallbackPanelExtent`
/// logical pixels along the main axis, `NibResizablePanels` renders a
/// scrollable, handle-less stack of full-size panels instead of squishing
/// them below a usable size (master prompt §1.7).
///
/// The fallback always stacks **vertically** and scrolls vertically,
/// regardless of `direction` — for a `vertical` group this is the same axis
/// it already uses (it just gains scrolling instead of squishing); for a
/// `horizontal` group this is a deliberate axis pivot, collapsing
/// side-by-side panels into a single scrollable column (the locked
/// brainstorming decision — see the design doc's "Narrow-viewport fallback"
/// section — not merely making the horizontal row scroll sideways).
const double kNibResizablePanelsNarrowFallbackPanelExtent = 160.0;
```

Replace the `build` method's `LayoutBuilder` body:

```dart
  @override
  Widget build(BuildContext context) {
    final sizes = _controller.sizes;
    return LayoutBuilder(
      builder: (context, constraints) {
        final groupMainExtent = widget.direction == Axis.horizontal ? constraints.maxWidth : constraints.maxHeight;
        final narrowThreshold = widget.panels.length * kNibResizablePanelsNarrowFallbackPanelExtent;

        if (groupMainExtent < narrowThreshold) {
          // Always a vertical stack + vertical scroll, regardless of
          // `direction` — a horizontal group pivots from side-by-side to
          // stacked; a vertical group was already stacked and just gains
          // scrolling. See the constant's doc comment above.
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [for (final panel in widget.panels) panel.child],
            ),
          );
        }

        final children = <Widget>[];
        for (var i = 0; i < widget.panels.length; i++) {
          children.add(widget.panels[i].child);
          if (i < widget.panels.length - 1) {
            final handleIndex = i;
            children.add(
              NibResizablePanelsHandle(
                key: ValueKey('nib-resizable-handle-$handleIndex'),
                direction: widget.direction,
                groupMainExtent: groupMainExtent,
                handleThickness: widget.handleThickness,
                sizeFraction: sizes[handleIndex],
                animated: widget.animated,
                transition: widget.transition,
                onDeltaFraction: (delta) => _controller.applyDelta(widget.panels, handleIndex, delta),
                onDragEnd: () => widget.onLayoutChanged?.call(_controller.sizes),
                onReset: () {
                  _controller.resetPanelPair(handleIndex);
                  widget.onLayoutChanged?.call(_controller.sizes);
                },
              ),
            );
          }
        }

        return NibResizablePanelsLayout(direction: widget.direction, sizes: sizes, children: children);
      },
    );
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/resizable_panels/nib_resizable_panels_test.dart`
Expected: PASS (17 tests)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/resizable_panels/nib_resizable_panels.dart test/resizable_panels/nib_resizable_panels_test.dart
git commit -m "feat(resizable-panels): narrow-viewport scrollable fallback; verify nested groups"
```

---

### Task 9: 3 usage examples + example-app wiring + progress tracker

**Files:**
- Create: `example/lib/examples/resizable_panels_examples.dart`
- Modify: `example/lib/catalog.dart`
- Modify: `NIB_COMPONENTS_PROGRESS.md`

**Interfaces:**
- Consumes: `NibResizablePanels`, `NibResizablePanel`, `NibResizablePanelsController` (Tasks 1–8); `CatalogEntry` (existing, `example/lib/catalog.dart`).
- Produces: `nibCatalog` gains four `CatalogEntry` entries (minimal, common, advanced, plus a narrow-fallback demo mirroring Data Table's `DataTableWideExample` precedent). No new public library API.

- [ ] **Step 1: Write the four usage examples**

Create `example/lib/examples/resizable_panels_examples.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal/default usage — two panels, even split.
class ResizablePanelsMinimalExample extends StatelessWidget {
  const ResizablePanelsMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: NibResizablePanels(
        direction: Axis.horizontal,
        panels: [
          NibResizablePanel(child: ColoredBox(color: Colors.blue.shade50, child: const Center(child: Text('Left')))),
          NibResizablePanel(
            child: ColoredBox(color: Colors.blue.shade100, child: const Center(child: Text('Right'))),
          ),
        ],
      ),
    );
  }
}

/// 2. Common variant — a 3-panel IDE-style layout (sidebar / content /
/// inspector) with fixed initial ratios and per-panel min sizes.
class ResizablePanelsIdeLayoutExample extends StatelessWidget {
  const ResizablePanelsIdeLayoutExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: NibResizablePanels(
        direction: Axis.horizontal,
        panels: [
          NibResizablePanel(
            initialSize: 0.2,
            minSize: 0.12,
            child: ColoredBox(color: Colors.grey.shade100, child: const Center(child: Text('Sidebar'))),
          ),
          NibResizablePanel(
            initialSize: 0.6,
            minSize: 0.3,
            child: ColoredBox(color: Colors.white, child: const Center(child: Text('Editor'))),
          ),
          NibResizablePanel(
            initialSize: 0.2,
            minSize: 0.12,
            child: ColoredBox(color: Colors.grey.shade100, child: const Center(child: Text('Inspector'))),
          ),
        ],
      ),
    );
  }
}

/// 3. Advanced — nested vertical + horizontal groups, an external
/// controller with a "Reset layout" button, animated handle affordance, and
/// persisted-layout callback wired to a snackbar.
class ResizablePanelsAdvancedExample extends StatefulWidget {
  const ResizablePanelsAdvancedExample({super.key});

  @override
  State<ResizablePanelsAdvancedExample> createState() => _ResizablePanelsAdvancedExampleState();
}

class _ResizablePanelsAdvancedExampleState extends State<ResizablePanelsAdvancedExample> {
  final _controller = NibResizablePanelsController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(onPressed: _controller.resetAll, child: const Text('Reset layout')),
        const SizedBox(height: 8),
        SizedBox(
          height: 360,
          child: NibResizablePanels(
            direction: Axis.vertical,
            controller: _controller,
            animated: true,
            onLayoutChanged: (sizes) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Layout changed: $sizes'), duration: const Duration(milliseconds: 800)),
              );
            },
            panels: [
              NibResizablePanel(
                initialSize: 0.65,
                child: NibResizablePanels(
                  direction: Axis.horizontal,
                  animated: true,
                  panels: [
                    NibResizablePanel(
                      child: ColoredBox(color: Colors.teal.shade50, child: const Center(child: Text('Top left'))),
                    ),
                    NibResizablePanel(
                      child: ColoredBox(color: Colors.teal.shade100, child: const Center(child: Text('Top right'))),
                    ),
                  ],
                ),
              ),
              NibResizablePanel(
                initialSize: 0.35,
                child: ColoredBox(color: Colors.teal.shade200, child: const Center(child: Text('Bottom'))),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 4. Narrow-viewport demo — a fixed narrow container deterministically
/// triggers the scrollable, handle-less fallback (mirrors Data Table's
/// `DataTableWideExample` pattern for reliably demonstrating a responsive
/// breakpoint rather than relying on the host window being narrow).
class ResizablePanelsNarrowExample extends StatelessWidget {
  const ResizablePanelsNarrowExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 240,
      child: NibResizablePanels(
        direction: Axis.horizontal,
        panels: [
          NibResizablePanel(child: ColoredBox(color: Colors.orange.shade50, child: const Center(child: Text('A')))),
          NibResizablePanel(child: ColoredBox(color: Colors.orange.shade100, child: const Center(child: Text('B')))),
          NibResizablePanel(child: ColoredBox(color: Colors.orange.shade200, child: const Center(child: Text('C')))),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Register the examples in the catalog**

Read `example/lib/catalog.dart` first, then add the import and four entries (after the existing Navigation Menu entries, matching build order):

```dart
import 'examples/resizable_panels_examples.dart';
```

```dart
  CatalogEntry(
    name: 'Resizable Panels — minimal',
    builder: (context) => const ResizablePanelsMinimalExample(),
  ),
  CatalogEntry(
    name: 'Resizable Panels — IDE layout (3 panels, min sizes)',
    builder: (context) => const ResizablePanelsIdeLayoutExample(),
  ),
  CatalogEntry(
    name: 'Resizable Panels — advanced (nested, controller, animated)',
    builder: (context) => const ResizablePanelsAdvancedExample(),
  ),
  CatalogEntry(
    name: 'Resizable Panels — narrow (scrollable fallback)',
    builder: (context) => const ResizablePanelsNarrowExample(),
  ),
```

- [ ] **Step 3: Verify the example app builds and analyzes clean**

Run: `cd example && flutter analyze && flutter build linux --debug`
Expected: `No issues found!`, `✓ Built build/linux/x64/debug/bundle/nib_components_example`

- [ ] **Step 4: Update the progress tracker**

In `NIB_COMPONENTS_PROGRESS.md`, change the Resizable Panels row from:

```
| 3 | Resizable Panels | not started | |
```

to:

```
| 3 | Resizable Panels | built — awaiting visual confirm | 2026-07-11 |
```

- [ ] **Step 5: Run the full test suite one last time**

Run: `flutter test`
Expected: PASS (all `resizable_panels` tests plus every prior suite — no regressions)

- [ ] **Step 6: Commit**

```bash
git add example/lib/examples/resizable_panels_examples.dart example/lib/catalog.dart NIB_COMPONENTS_PROGRESS.md
git commit -m "feat(resizable-panels): add 4 usage examples, wire into example app catalog"
```

- [ ] **Step 7: Hand off for visual confirmation**

Do not proceed to the next component (Command Palette, Tier A #4) until the user has run/reloaded `example/` (`flutter run -d linux`, hit `r` to hot reload) and confirmed all four Resizable Panels examples look and behave correctly — including dragging, double-tap reset, keyboard resize (Tab to a handle, arrow keys), light/dark mode, and the narrow-viewport fallback. On confirmation, update `NIB_COMPONENTS_PROGRESS.md`'s Resizable Panels row status to `verified` with today's date and commit that alone before starting Command Palette.

---

## Self-review notes

- **Spec coverage:** every design-doc requirement maps to a task — fraction sizing + normalization (Task 1), stop-at-limit no-cascade drag math (Task 1/5), controller with `setSizes`/`resetPanelPair`/`resetAll` (Task 2), genuine custom `RenderObject` layout (Task 3), drag + double-tap reset (Task 5), keyboard + Semantics (Task 6), `animated`/`NibMotion` (Task 7), narrow-viewport fallback + implicit nesting (Task 8), 3+ examples and example-app wiring (Task 9, shipped as 4 to also cover the narrow-fallback demo).
- **Type consistency:** `NibResizablePanel`, `NibResizablePanelsController`, `NibResizablePanelsHandle`, `NibResizablePanels` constructor signatures are introduced once (Tasks 1/2/4) and never renamed in later tasks; every later task's code samples were checked to call them with matching parameter names.
- **Known deviation from the design doc (flagged, not silent):** the design doc's RenderObject section described handles as "not separate child widgets — painted and hit-tested by the render object itself" with drag handled via raw `RenderObject.handleEvent`. This plan instead makes each handle an ordinary `NibResizablePanelsHandle` widget positioned as an interleaved child slot by the render object (Task 3), with interaction via standard `GestureDetector`/`Focus`/`MouseRegion`/`Semantics` (Tasks 5–6). This still requires the render object to do 100% of the genuine layout/constraint math the master prompt calls out as the hard part — it changes only *how the divider paints and is hit-tested*, not who owns sizing logic. The reasons: (1) it lets `animated: true` use a real `NibMotion` widget around the handle's line, satisfying this repo's established `find.byType(NibMotion)` test convention for animated components, which raw-RenderObject painting cannot do; (2) it reuses Flutter's own well-tested gesture/focus/semantics primitives instead of hand-rolling pointer routing and a `TickerProvider`-driven color animation inside the render object, which is less code and lower risk for a component that's already the hardest one in the build order on layout grounds alone.
