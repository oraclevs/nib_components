# NibNavigationMenu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `NibNavigationMenu`, Tier A #2 in `NIB_COMPONENTS_MASTER_PROMPT.md`'s build order — a native, recursive multi-level navigation menu supporting horizontal (cascading flyout) and vertical (inline expand) orientations, keyboard traversal, and responsive overflow collapse.

**Architecture:** A new shared, nav-menu-agnostic primitive (`NibAnchoredOverlay`, backed by `CompositedTransformTarget`/`Follower` + `OverlayEntry`, plus a small `MeasureSize` custom `RenderObject`) is extracted first — this is the flagged one-time reorder from the design spec, pulled forward from Popover (#10) because Navigation Menu needs anchored/flipped overlay positioning now. `NibNavigationMenu` itself is a `StatefulWidget` around a recursive `NibNavItem` tree; horizontal branches open cascading flyouts through the shared primitive, vertical branches expand inline via `Column` reflow. An optional `NibNavMenuController` (`ChangeNotifier`) tracks open-chain/open-id state, owned internally when not supplied. Animation is opt-in via `animated: bool`, routed through `nib_motion`'s `NibMotion` (flyout/inline entrance) and `NibPresence` (inline exit) — zero `NibMotion` allocations when `animated: false`.

**Tech Stack:** Flutter 3.44.1 / Dart 3.12.1 (stable channel), `nib_motion` 0.2.1 (path dependency, already wired), `flutter_lints` ^6.0.0. No new pub dependencies.

## Global Constraints

- Widget class name: `NibNavigationMenu` (public widgets prefixed `Nib`, PascalCase) — per root `CLAUDE.md` Component Naming Convention and master prompt section 1.
- No hardcoded hex colors anywhere — every color comes from `NibTheme.of(context)`. Border radius only from `NibTheme`'s `radiusSm`(4)/`radiusDefault`(8)/`radiusLg`(12)/`radiusPill`(9999).
- Must render correctly in both light and dark mode with zero extra consumer config (master prompt section 2).
- Build native, not wrapped: `CompositedTransformTarget`/`CompositedTransformFollower`/`OverlayEntry`, a custom `RenderObject` for size measurement, `InkWell`/`Material`, `Focus`/`FocusNode` for keyboard traversal — never `AnimatedContainer`/implicit-animation widgets for anything `nib_motion` should own (master prompt sections 1.1, 1.4).
- Simple by default: `NibNavigationMenu(items: [...])` alone must render a finished-looking horizontal menu. Every other parameter is optional with a sensible default (master prompt section 1.2).
- Stateful by default: open-flyout-chain state and open-inline-id state are managed internally; consumer never needs `StatefulBuilder` for basic use. Optional `NibNavMenuController` for external control (master prompt section 1.3).
- `animated: bool = false` default; when `true` and no explicit `transition` given, fall back to a built-in default `NibTransition`. Zero `NibMotion`/`MotionValue` allocation when `false` (master prompt section 1.4). (Note: the design spec's draft wording used a hypothetical `NibAnimationPreset` — this plan uses the actual established codebase convention instead, `animated: bool` + `transition: NibTransition?`, matching `NibDataTable`'s real precedent.)
- Recursive nesting: `NibNavItem.children` is itself `List<NibNavItem>` — arbitrary depth, not fixed at 2 levels (master prompt section 5.2's "multi-level" framing; design spec decision).
- Horizontal flyouts are tap/click-only on every platform (no hover-intent timers) — deferred to Hover Card's (#12) problem space (design spec decision).
- Vertical inline-expand siblings are single-open by default (`allowMultipleOpen: bool = false`), overridable — mirrors the Accordion (#15) precedent (design spec decision).
- Horizontal overflow ("More" menu) uses real dynamic width measurement, not fixed breakpoints (design spec decision) — reuses the same `MeasureSize` helper the anchor primitive uses.
- Output contract (master prompt section 1.5, minus the retired meta.json/CDN registry piece): widget file(s), 3 usage examples (minimal, common variant, advanced) wired into `example/`, widget tests, `flutter analyze` clean.
- Zero required pub dependencies beyond `flutter` and `nib_motion` (already wired).
- Every item ID (`NibNavItem.id`) must be unique across the whole tree passed to one `NibNavigationMenu` — it is used as the key for per-item `LayerLink`/`GlobalKey`/`FocusNode` caches and for controller open-state tracking.

---

### Task 1: Shared anchor primitive — `MeasureSize` + `NibAnchoredOverlay`

**Files:**
- Create: `lib/src/overlay/measure_size.dart`
- Create: `lib/src/overlay/nib_anchored_overlay.dart`
- Create: `test/overlay/nib_anchored_overlay_test.dart`

**Interfaces:**
- Consumes: nothing new (pure Flutter `rendering`/`widgets`).
- Produces:
  - `class MeasureSize extends SingleChildRenderObjectWidget { const MeasureSize({Key? key, required void Function(Size) onChange, required Widget child}); }` — reports `child`'s laid-out size via `onChange` after every layout pass, without affecting constraints/paint.
  - `enum NibOverlayPlacement { bottom, top, end, start }`
  - `class NibAnchoredOverlayHandle { void remove(); }`
  - `class NibAnchoredOverlay { static NibAnchoredOverlayHandle show(BuildContext context, {required LayerLink link, required RenderBox targetRenderBox, required WidgetBuilder contentBuilder, NibOverlayPlacement placement = NibOverlayPlacement.bottom, VoidCallback? onDismissed}); }`

This is the primitive later tasks (4, 5, 9) and eventually Popover (#10, per the design spec's flagged reorder) build on.

- [ ] **Step 1: Write the failing tests**

```dart
// test/overlay/nib_anchored_overlay_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/overlay/nib_anchored_overlay.dart';

Widget _harness({
  required Widget Function(BuildContext context, GlobalKey targetKey) builder,
  Size screenSize = const Size(800, 600),
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: screenSize),
      child: Scaffold(
        body: Builder(
          builder: (context) {
            final targetKey = GlobalKey();
            return builder(context, targetKey);
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows content below the target when it fits', (tester) async {
    final link = LayerLink();
    late BuildContext ctx;
    await tester.pumpWidget(
      _harness(
        builder: (context, targetKey) {
          ctx = context;
          return Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformTarget(
              link: link,
              child: SizedBox(key: targetKey, width: 80, height: 40),
            ),
          );
        },
      ),
    );

    final box = tester.renderObject(find.byType(SizedBox).first) as RenderBox;

    NibAnchoredOverlay.show(
      ctx,
      link: link,
      targetRenderBox: box,
      contentBuilder: (context) => const SizedBox(
        key: ValueKey('content'),
        width: 100,
        height: 50,
        child: Text('flyout'),
      ),
    );
    await tester.pumpAndSettle();

    final targetBottom = tester.getBottomLeft(find.byType(SizedBox).first);
    final contentTop = tester.getTopLeft(find.byKey(const ValueKey('content')));
    expect(contentTop.dy, greaterThanOrEqualTo(targetBottom.dy));
    expect(find.text('flyout'), findsOneWidget);
  });

  testWidgets('flips to top when there is no room below', (tester) async {
    final link = LayerLink();
    late BuildContext ctx;
    await tester.pumpWidget(
      _harness(
        screenSize: const Size(800, 100),
        builder: (context, targetKey) {
          ctx = context;
          return Align(
            alignment: Alignment.bottomLeft,
            child: CompositedTransformTarget(
              link: link,
              child: SizedBox(key: targetKey, width: 80, height: 40),
            ),
          );
        },
      ),
    );

    final box = tester.renderObject(find.byType(SizedBox).first) as RenderBox;
    NibAnchoredOverlay.show(
      ctx,
      link: link,
      targetRenderBox: box,
      contentBuilder: (context) => const SizedBox(
        key: ValueKey('content'),
        width: 100,
        height: 60,
        child: Text('flyout'),
      ),
    );
    await tester.pumpAndSettle();

    final targetTop = tester.getTopLeft(find.byType(SizedBox).first);
    final contentBottom = tester.getBottomLeft(find.byKey(const ValueKey('content')));
    expect(contentBottom.dy, lessThanOrEqualTo(targetTop.dy));
  });

  testWidgets('tapping outside dismisses and removes the content', (tester) async {
    final link = LayerLink();
    late BuildContext ctx;
    await tester.pumpWidget(
      _harness(
        builder: (context, targetKey) {
          ctx = context;
          return Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformTarget(
              link: link,
              child: SizedBox(key: targetKey, width: 80, height: 40),
            ),
          );
        },
      ),
    );

    final box = tester.renderObject(find.byType(SizedBox).first) as RenderBox;
    var dismissed = false;
    NibAnchoredOverlay.show(
      ctx,
      link: link,
      targetRenderBox: box,
      contentBuilder: (context) => const SizedBox(
        key: ValueKey('content'),
        width: 100,
        height: 50,
        child: Text('flyout'),
      ),
      onDismissed: () => dismissed = true,
    );
    await tester.pumpAndSettle();
    expect(find.text('flyout'), findsOneWidget);

    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
    expect(find.text('flyout'), findsNothing);
  });

  testWidgets('handle.remove() removes the content without a tap', (tester) async {
    final link = LayerLink();
    late BuildContext ctx;
    await tester.pumpWidget(
      _harness(
        builder: (context, targetKey) {
          ctx = context;
          return Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformTarget(
              link: link,
              child: SizedBox(key: targetKey, width: 80, height: 40),
            ),
          );
        },
      ),
    );

    final box = tester.renderObject(find.byType(SizedBox).first) as RenderBox;
    final handle = NibAnchoredOverlay.show(
      ctx,
      link: link,
      targetRenderBox: box,
      contentBuilder: (context) => const Text('flyout'),
    );
    await tester.pumpAndSettle();
    expect(find.text('flyout'), findsOneWidget);

    handle.remove();
    await tester.pumpAndSettle();
    expect(find.text('flyout'), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/overlay/nib_anchored_overlay_test.dart`
Expected: FAIL — `package:nib_components/src/overlay/nib_anchored_overlay.dart` doesn't exist.

- [ ] **Step 3: Write `MeasureSize`**

```dart
// lib/src/overlay/measure_size.dart
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports [child]'s laid-out size via [onChange] after every layout pass
/// that changes it, without affecting [child]'s constraints or paint.
///
/// Used to measure content whose final size isn't known until after it's
/// built (an overlay flyout before its flip/clamp position is decided, or
/// off-screen nav items before overflow packing decides what fits).
class MeasureSize extends SingleChildRenderObjectWidget {
  const MeasureSize({super.key, required this.onChange, required Widget super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(BuildContext context, covariant _RenderMeasureSize renderObject) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = child?.size ?? Size.zero;
    if (_oldSize == newSize) return;
    _oldSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(newSize));
  }
}
```

- [ ] **Step 4: Write `NibAnchoredOverlay`**

```dart
// lib/src/overlay/nib_anchored_overlay.dart
import 'package:flutter/widgets.dart';

import 'measure_size.dart';

/// Which side of the trigger a [NibAnchoredOverlay]'s content prefers to
/// open toward. Flips to the opposite side automatically if it doesn't fit
/// in the viewport.
enum NibOverlayPlacement {
  /// Below the trigger, left-aligned. Flips to [top] if it doesn't fit.
  bottom,

  /// Above the trigger, left-aligned. Flips to [bottom] if it doesn't fit.
  top,

  /// To the right of the trigger, top-aligned. Flips to [start] if it
  /// doesn't fit.
  end,

  /// To the left of the trigger, top-aligned. Flips to [end] if it doesn't
  /// fit.
  start,
}

/// A handle to a [NibAnchoredOverlay.show] call. Call [remove] to close it.
class NibAnchoredOverlayHandle {
  NibAnchoredOverlayHandle._(this._entry);
  final OverlayEntry _entry;
  bool _removed = false;

  /// Removes the overlay entry. Safe to call more than once.
  void remove() {
    if (_removed) return;
    _removed = true;
    _entry.remove();
  }
}

/// Generic anchored-overlay primitive: positions [contentBuilder]'s content
/// next to [targetRenderBox] via [link], flipping to the opposite side and
/// clamping to the screen bounds when the preferred [placement] doesn't
/// fit.
///
/// Shared by `NibNavigationMenu`'s flyout/cascade submenus and (per the
/// 2026-07-10 Navigation Menu design doc) intended for `Popover` to reuse
/// rather than reimplement.
class NibAnchoredOverlay {
  NibAnchoredOverlay._();

  static NibAnchoredOverlayHandle show(
    BuildContext context, {
    required LayerLink link,
    required RenderBox targetRenderBox,
    required WidgetBuilder contentBuilder,
    NibOverlayPlacement placement = NibOverlayPlacement.bottom,
    VoidCallback? onDismissed,
  }) {
    final overlayState = Overlay.of(context);
    final targetGlobalTopLeft = targetRenderBox.localToGlobal(Offset.zero);
    final targetSize = targetRenderBox.size;

    late OverlayEntry entry;
    void dismiss() {
      entry.remove();
      onDismissed?.call();
    }

    entry = OverlayEntry(
      builder: (overlayContext) => _NibAnchoredOverlayContent(
        link: link,
        targetSize: targetSize,
        targetGlobalTopLeft: targetGlobalTopLeft,
        placement: placement,
        onDismissed: dismiss,
        contentBuilder: contentBuilder,
      ),
    );
    overlayState.insert(entry);
    return NibAnchoredOverlayHandle._(entry);
  }
}

class _Anchors {
  const _Anchors(this.target, this.follower);
  final Alignment target;
  final Alignment follower;
}

enum _ResolvedSide { bottom, top, end, start }

class _NibAnchoredOverlayContent extends StatefulWidget {
  const _NibAnchoredOverlayContent({
    required this.link,
    required this.targetSize,
    required this.targetGlobalTopLeft,
    required this.placement,
    required this.onDismissed,
    required this.contentBuilder,
  });

  final LayerLink link;
  final Size targetSize;
  final Offset targetGlobalTopLeft;
  final NibOverlayPlacement placement;
  final VoidCallback onDismissed;
  final WidgetBuilder contentBuilder;

  @override
  State<_NibAnchoredOverlayContent> createState() => _NibAnchoredOverlayContentState();
}

class _NibAnchoredOverlayContentState extends State<_NibAnchoredOverlayContent> {
  Size? _contentSize;

  _ResolvedSide _resolveSide(Size contentSize, Size screen) {
    switch (widget.placement) {
      case NibOverlayPlacement.bottom:
        final fits =
            widget.targetGlobalTopLeft.dy + widget.targetSize.height + contentSize.height <=
            screen.height;
        return fits ? _ResolvedSide.bottom : _ResolvedSide.top;
      case NibOverlayPlacement.top:
        final fits = widget.targetGlobalTopLeft.dy - contentSize.height >= 0;
        return fits ? _ResolvedSide.top : _ResolvedSide.bottom;
      case NibOverlayPlacement.end:
        final fits =
            widget.targetGlobalTopLeft.dx + widget.targetSize.width + contentSize.width <=
            screen.width;
        return fits ? _ResolvedSide.end : _ResolvedSide.start;
      case NibOverlayPlacement.start:
        final fits = widget.targetGlobalTopLeft.dx - contentSize.width >= 0;
        return fits ? _ResolvedSide.start : _ResolvedSide.end;
    }
  }

  _Anchors _anchorsFor(_ResolvedSide side) {
    switch (side) {
      case _ResolvedSide.bottom:
        return const _Anchors(Alignment.bottomLeft, Alignment.topLeft);
      case _ResolvedSide.top:
        return const _Anchors(Alignment.topLeft, Alignment.bottomLeft);
      case _ResolvedSide.end:
        return const _Anchors(Alignment.topRight, Alignment.topLeft);
      case _ResolvedSide.start:
        return const _Anchors(Alignment.topLeft, Alignment.topRight);
    }
  }

  Offset _clampOffsetFor(_ResolvedSide side, Size contentSize, Size screen) {
    switch (side) {
      case _ResolvedSide.bottom:
      case _ResolvedSide.top:
        final overflow =
            (widget.targetGlobalTopLeft.dx + contentSize.width) - screen.width;
        if (overflow <= 0) return Offset.zero;
        final dx = -overflow;
        final clamped = widget.targetGlobalTopLeft.dx + dx < 0
            ? -widget.targetGlobalTopLeft.dx
            : dx;
        return Offset(clamped, 0);
      case _ResolvedSide.end:
      case _ResolvedSide.start:
        final overflow =
            (widget.targetGlobalTopLeft.dy + contentSize.height) - screen.height;
        if (overflow <= 0) return Offset.zero;
        final dy = -overflow;
        final clamped = widget.targetGlobalTopLeft.dy + dy < 0
            ? -widget.targetGlobalTopLeft.dy
            : dy;
        return Offset(0, clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = MeasureSize(
      onChange: (size) {
        if (mounted && _contentSize != size) setState(() => _contentSize = size);
      },
      child: widget.contentBuilder(context),
    );

    final barrier = Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onDismissed,
      ),
    );

    if (_contentSize == null) {
      return Stack(children: [barrier, Opacity(opacity: 0, child: content)]);
    }

    final screen = MediaQuery.sizeOf(context);
    final side = _resolveSide(_contentSize!, screen);
    final anchors = _anchorsFor(side);
    final clampOffset = _clampOffsetFor(side, _contentSize!, screen);

    return Stack(
      children: [
        barrier,
        CompositedTransformFollower(
          link: widget.link,
          targetAnchor: anchors.target,
          followerAnchor: anchors.follower,
          offset: clampOffset,
          child: content,
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/overlay/nib_anchored_overlay_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 6: Run analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/src/overlay test/overlay
git commit -m "feat(overlay): add shared NibAnchoredOverlay + MeasureSize primitives"
```

---

### Task 2: Nav item model + `NibNavMenuController`

**Files:**
- Create: `lib/src/navigation_menu/nib_nav_item.dart`
- Create: `lib/src/navigation_menu/nib_navigation_menu_types.dart`
- Create: `lib/src/navigation_menu/nib_navigation_menu_controller.dart`
- Create: `test/navigation_menu/nib_navigation_menu_controller_test.dart`
- Modify: `lib/nib_components.dart`

**Interfaces:**
- Consumes: `ChangeNotifier` (`flutter/foundation.dart`).
- Produces:
  - `class NibNavItem { const NibNavItem({required String id, required String label, Widget? icon, bool disabled = false, Widget? badge, List<NibNavItem> children = const []}); bool get hasChildren; }`
  - `enum NibNavMenuOrientation { horizontal, vertical }`
  - `class NibNavMenuController extends ChangeNotifier { NibNavMenuController({List<String> openChain = const [], Set<String>? openIds}); List<String> get openChain; Set<String> get openIds; void openChainTo(List<String> path); void closeFromDepth(int depth); void closeAll(); void toggleOpenId(String id, {Set<String>? exclusiveSiblings}); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/navigation_menu/nib_navigation_menu_controller_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

void main() {
  group('NibNavItem', () {
    test('hasChildren reflects whether children is non-empty', () {
      const leaf = NibNavItem(id: 'a', label: 'A');
      const branch = NibNavItem(id: 'b', label: 'B', children: [NibNavItem(id: 'c', label: 'C')]);
      expect(leaf.hasChildren, isFalse);
      expect(branch.hasChildren, isTrue);
    });
  });

  group('NibNavMenuController', () {
    test('starts with given openChain/openIds', () {
      final controller = NibNavMenuController(openChain: ['a'], openIds: {'x'});
      expect(controller.openChain, ['a']);
      expect(controller.openIds, {'x'});
    });

    test('openChainTo replaces the chain and notifies', () {
      final controller = NibNavMenuController();
      var notified = 0;
      controller.addListener(() => notified++);
      controller.openChainTo(['a', 'b']);
      expect(controller.openChain, ['a', 'b']);
      expect(notified, 1);
    });

    test('closeFromDepth truncates the chain from the given depth', () {
      final controller = NibNavMenuController(openChain: ['a', 'b', 'c']);
      controller.closeFromDepth(1);
      expect(controller.openChain, ['a']);
    });

    test('closeAll empties the chain, no-op if already empty', () {
      final controller = NibNavMenuController(openChain: ['a']);
      var notified = 0;
      controller.addListener(() => notified++);
      controller.closeAll();
      expect(controller.openChain, isEmpty);
      expect(notified, 1);
      controller.closeAll();
      expect(notified, 1, reason: 'no-op close should not notify again');
    });

    test('toggleOpenId adds then removes, notifying each time', () {
      final controller = NibNavMenuController();
      var notified = 0;
      controller.addListener(() => notified++);
      controller.toggleOpenId('a');
      expect(controller.openIds, {'a'});
      controller.toggleOpenId('a');
      expect(controller.openIds, isEmpty);
      expect(notified, 2);
    });

    test('toggleOpenId with exclusiveSiblings closes siblings when opening', () {
      final controller = NibNavMenuController(openIds: {'sibling'});
      controller.toggleOpenId('a', exclusiveSiblings: {'sibling'});
      expect(controller.openIds, {'a'});
    });

    test('openChain/openIds are unmodifiable', () {
      final controller = NibNavMenuController(openChain: ['a'], openIds: {'x'});
      expect(() => controller.openChain.add('b'), throwsUnsupportedError);
      expect(() => controller.openIds.add('y'), throwsUnsupportedError);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/navigation_menu/nib_navigation_menu_controller_test.dart`
Expected: FAIL — `NibNavItem`/`NibNavMenuController` undefined.

- [ ] **Step 3: Write the implementation**

```dart
// lib/src/navigation_menu/nib_nav_item.dart
import 'package:flutter/widgets.dart';

/// One item in a [NibNavigationMenu]. [children] may itself contain items
/// with further [children], producing cascading (horizontal) or nested
/// (vertical) submenus of arbitrary depth.
///
/// [id] must be unique across the whole tree passed to one
/// `NibNavigationMenu` — it keys per-item overlay/focus/open-state
/// tracking.
class NibNavItem {
  const NibNavItem({
    required this.id,
    required this.label,
    this.icon,
    this.disabled = false,
    this.badge,
    this.children = const [],
  });

  final String id;
  final String label;
  final Widget? icon;
  final bool disabled;
  final Widget? badge;
  final List<NibNavItem> children;

  /// Whether this item has any nested [children].
  bool get hasChildren => children.isNotEmpty;
}
```

```dart
// lib/src/navigation_menu/nib_navigation_menu_types.dart

/// Layout direction for a [NibNavigationMenu]'s top-level items.
enum NibNavMenuOrientation {
  /// Top-level items in a `Row`. Branch items open cascading flyouts.
  horizontal,

  /// Top-level items in a `Column`. Branch items expand inline.
  vertical,
}
```

```dart
// lib/src/navigation_menu/nib_navigation_menu_controller.dart
import 'package:flutter/foundation.dart';

/// Optional external controller for a `NibNavigationMenu`'s open-submenu
/// state. Never required for basic use — `NibNavigationMenu` owns its own
/// controller internally when none is supplied.
///
/// [openChain] tracks horizontal cascading-flyout state (root-to-deepest
/// open item ids). [openIds] tracks vertical inline-expand state (every
/// currently-expanded item id, at any depth).
class NibNavMenuController extends ChangeNotifier {
  NibNavMenuController({List<String> openChain = const [], Set<String>? openIds})
    : _openChain = List<String>.of(openChain),
      _openIds = Set<String>.of(openIds ?? const {});

  final List<String> _openChain;
  final Set<String> _openIds;

  /// Horizontal mode: the chain of open flyout ids, root to deepest.
  List<String> get openChain => List<String>.unmodifiable(_openChain);

  /// Vertical mode: the set of currently-expanded item ids.
  Set<String> get openIds => Set<String>.unmodifiable(_openIds);

  /// Replaces the open chain with [path] (root-to-leaf ids).
  void openChainTo(List<String> path) {
    _openChain
      ..clear()
      ..addAll(path);
    notifyListeners();
  }

  /// Truncates the open chain to length [depth]. No-op if already that
  /// short or shorter.
  void closeFromDepth(int depth) {
    if (_openChain.length <= depth) return;
    _openChain.removeRange(depth, _openChain.length);
    notifyListeners();
  }

  /// Empties the open chain. No-op (does not notify) if already empty.
  void closeAll() {
    if (_openChain.isEmpty) return;
    _openChain.clear();
    notifyListeners();
  }

  /// Vertical mode: toggles [id] open/closed. If [exclusiveSiblings] is
  /// given, every id in it is closed at the same time (single-open
  /// sibling coordination).
  void toggleOpenId(String id, {Set<String>? exclusiveSiblings}) {
    final opening = !_openIds.contains(id);
    if (exclusiveSiblings != null) {
      _openIds.removeAll(exclusiveSiblings);
    }
    if (opening) {
      _openIds.add(id);
    } else {
      _openIds.remove(id);
    }
    notifyListeners();
  }
}
```

```dart
// lib/nib_components.dart — add these three lines (alongside the existing
// data_table/theme exports, alphabetized within the new group):
export 'src/navigation_menu/nib_nav_item.dart';
export 'src/navigation_menu/nib_navigation_menu_controller.dart';
export 'src/navigation_menu/nib_navigation_menu_types.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/navigation_menu/nib_navigation_menu_controller_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/src/navigation_menu lib/nib_components.dart test/navigation_menu
git commit -m "feat(navigation-menu): add NibNavItem model + NibNavMenuController"
```

---

### Task 3: `NibNavigationMenu` core widget — leaf-only render, both orientations

**Files:**
- Create: `lib/src/navigation_menu/nib_navigation_menu.dart`
- Create: `test/navigation_menu/nib_navigation_menu_test.dart`
- Modify: `lib/nib_components.dart`

**Interfaces:**
- Consumes: `NibTheme.of` (existing); `NibNavItem`, `NibNavMenuOrientation`, `NibNavMenuController` (Task 2).
- Produces: `class NibNavigationMenu extends StatefulWidget` with constructor `NibNavigationMenu({Key? key, required List<NibNavItem> items, NibNavMenuOrientation orientation = NibNavMenuOrientation.horizontal, String? activeItemId, ValueChanged<String>? onItemSelected, bool allowMultipleOpen = false, bool animated = false, NibTransition? transition, NibNavMenuController? controller, String? semanticLabel})`. This task renders every item (ignoring `children` entirely — flyout/inline-expand behavior for branch items lands in Tasks 4–7) with tap-to-select, active-item indicator, and disabled dimming.

- [ ] **Step 1: Write the failing tests**

```dart
// test/navigation_menu/nib_navigation_menu_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: const [NibTheme.light]),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders every top-level item label, horizontal by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const NibNavigationMenu(
          items: [
            NibNavItem(id: 'home', label: 'Home'),
            NibNavItem(id: 'about', label: 'About'),
          ],
        ),
      ),
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.byType(Row), findsWidgets);
  });

  testWidgets('vertical orientation lays out items in a Column', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const NibNavigationMenu(
          orientation: NibNavMenuOrientation.vertical,
          items: [
            NibNavItem(id: 'home', label: 'Home'),
            NibNavItem(id: 'about', label: 'About'),
          ],
        ),
      ),
    );
    expect(find.byType(Column), findsWidgets);
  });

  testWidgets('tapping a leaf item calls onItemSelected with its id', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      _wrap(
        NibNavigationMenu(
          items: const [NibNavItem(id: 'home', label: 'Home')],
          onItemSelected: (id) => selected = id,
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(selected, 'home');
  });

  testWidgets('disabled item does not call onItemSelected', (tester) async {
    String? selected;
    await tester.pumpWidget(
      _wrap(
        NibNavigationMenu(
          items: const [NibNavItem(id: 'home', label: 'Home', disabled: true)],
          onItemSelected: (id) => selected = id,
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });

  testWidgets('activeItemId is announced as selected to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        const NibNavigationMenu(
          activeItemId: 'home',
          items: [
            NibNavItem(id: 'home', label: 'Home'),
            NibNavItem(id: 'about', label: 'About'),
          ],
        ),
      ),
    );
    final homeNode = tester.getSemantics(find.text('Home'));
    final aboutNode = tester.getSemantics(find.text('About'));
    // ignore: deprecated_member_use
    expect(homeNode.hasFlag(SemanticsFlag.isSelected), isTrue);
    // ignore: deprecated_member_use
    expect(aboutNode.hasFlag(SemanticsFlag.isSelected), isFalse);
    handle.dispose();
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/navigation_menu/nib_navigation_menu_test.dart`
Expected: FAIL — `NibNavigationMenu` undefined.

- [ ] **Step 3: Write the implementation**

```dart
// lib/src/navigation_menu/nib_navigation_menu.dart
import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import '../theme/nib_theme.dart';
import 'nib_nav_item.dart';
import 'nib_navigation_menu_controller.dart';
import 'nib_navigation_menu_types.dart';

/// A native, recursive, multi-level navigation menu.
///
/// Simplest usage needs only [items]:
///
/// ```dart
/// NibNavigationMenu(
///   items: [
///     NibNavItem(id: 'home', label: 'Home'),
///     NibNavItem(id: 'about', label: 'About'),
///   ],
///   onItemSelected: (id) {},
/// )
/// ```
class NibNavigationMenu extends StatefulWidget {
  const NibNavigationMenu({
    super.key,
    required this.items,
    this.orientation = NibNavMenuOrientation.horizontal,
    this.activeItemId,
    this.onItemSelected,
    this.allowMultipleOpen = false,
    this.animated = false,
    this.transition,
    this.controller,
    this.semanticLabel,
  });

  /// The top-level item tree. Each item may carry further [NibNavItem]
  /// `children` of arbitrary depth.
  final List<NibNavItem> items;

  /// Whether top-level items lay out in a `Row` (cascading flyout
  /// submenus) or a `Column` (inline-expand submenus).
  final NibNavMenuOrientation orientation;

  /// The id of the item to visually mark as the current selection.
  /// Purely a visual indicator — decoupled from open/closed submenu
  /// state.
  final String? activeItemId;

  /// Called when a leaf item (or a branch item's own label, distinct from
  /// its expand/collapse affordance) is tapped.
  final ValueChanged<String>? onItemSelected;

  /// Vertical mode only: whether more than one sibling submenu can be
  /// expanded at once. `false` (default) closes other open siblings at
  /// the same depth when one opens.
  final bool allowMultipleOpen;

  /// Opt-in entrance animation for opened submenus, via `nib_motion`.
  /// `false` allocates zero `NibMotion`/`MotionValue` overhead.
  final bool animated;

  /// The transition used for [animated] submenu entrances/exits. Defaults
  /// to a short fade+scale/slide when `animated` is `true` and this is
  /// `null`.
  final NibTransition? transition;

  /// Drives open-submenu state externally. Never required for basic use —
  /// `NibNavigationMenu` creates and owns its own controller when this is
  /// `null`.
  final NibNavMenuController? controller;

  /// Accessibility label for the menu as a whole.
  final String? semanticLabel;

  @override
  State<NibNavigationMenu> createState() => _NibNavigationMenuState();
}

class _NibNavigationMenuState extends State<NibNavigationMenu> {
  late NibNavMenuController _controller;
  late bool _ownsController;

  final Map<String, LayerLink> _links = {};
  final Map<String, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant NibNavigationMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _unbindController();
      _bindController(widget.controller);
    }
  }

  @override
  void dispose() {
    _unbindController();
    super.dispose();
  }

  void _bindController(NibNavMenuController? external) {
    _controller = external ?? NibNavMenuController();
    _ownsController = external == null;
    _controller.addListener(_handleControllerChanged);
  }

  void _unbindController() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) _controller.dispose();
  }

  void _handleControllerChanged() => setState(() {});

  LayerLink _linkFor(String id) => _links.putIfAbsent(id, LayerLink.new);
  GlobalKey _keyFor(String id) => _itemKeys.putIfAbsent(id, GlobalKey.new);

  void _handleItemTap(NibNavItem item, List<String> path, List<String> siblingIds) {
    if (item.disabled) return;
    if (!item.hasChildren) {
      widget.onItemSelected?.call(item.id);
      return;
    }
    // Branch-item open/close behavior (flyout/inline) lands in Tasks 4-7.
  }

  Widget _buildItem(
    BuildContext context,
    NibTheme theme,
    NibNavItem item,
    List<String> path,
    List<String> siblingIds,
  ) {
    final isActive = item.id == widget.activeItemId;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.icon != null) ...[item.icon!, const SizedBox(width: 8)],
          Text(
            item.label,
            style: TextStyle(
              color: item.disabled
                  ? theme.mutedForeground
                  : (isActive ? theme.primary : theme.foreground),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (item.badge != null) ...[const SizedBox(width: 6), item.badge!],
        ],
      ),
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: isActive
            ? Border(bottom: BorderSide(color: theme.primary, width: 2))
            : null,
      ),
      child: content,
    );

    return Semantics(
      button: true,
      enabled: !item.disabled,
      selected: isActive,
      label: item.label,
      child: CompositedTransformTarget(
        link: _linkFor(item.id),
        child: KeyedSubtree(
          key: _keyFor(item.id),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: item.disabled ? null : () => _handleItemTap(item, path, siblingIds),
              borderRadius: BorderRadius.circular(theme.radiusSm),
              excludeFromSemantics: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: decorated,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final topSiblingIds = [for (final i in widget.items) i.id];
    final nodes = [
      for (final item in widget.items)
        _buildItem(context, theme, item, [item.id], topSiblingIds),
    ];

    return Semantics(
      label: widget.semanticLabel,
      container: true,
      child: widget.orientation == NibNavMenuOrientation.horizontal
          ? Row(mainAxisSize: MainAxisSize.min, children: nodes)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: nodes,
            ),
    );
  }
}
```

```dart
// lib/nib_components.dart — add, alongside the Task 2 exports:
export 'src/navigation_menu/nib_navigation_menu.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/navigation_menu/nib_navigation_menu_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/navigation_menu/nib_navigation_menu.dart lib/nib_components.dart test/navigation_menu/nib_navigation_menu_test.dart
git commit -m "feat(navigation-menu): add NibNavigationMenu core leaf-only render"
```

---

### Task 4: Horizontal top-level flyout (single level)

**Files:**
- Modify: `lib/src/navigation_menu/nib_navigation_menu.dart`
- Modify: `test/navigation_menu/nib_navigation_menu_test.dart`

**Interfaces:**
- Consumes: `NibAnchoredOverlay`, `NibAnchoredOverlayHandle`, `NibOverlayPlacement` (Task 1); `_controller.openChain`/`openChainTo`/`closeFromDepth` (Task 2).
- Produces: in horizontal orientation, tapping a top-level item with `children` opens a flyout (via `NibAnchoredOverlay`, `placement: bottom`) listing its immediate children (rendered leaf-only for now — cascading into a child's own children lands in Task 5). Tapping the same item again, tapping outside, or selecting a leaf inside the flyout closes it.

- [ ] **Step 1: Write the failing tests**

Append to `test/navigation_menu/nib_navigation_menu_test.dart`:

```dart
testWidgets('tapping a horizontal branch item opens a flyout with its children', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [
              NibNavItem(id: 'widgets', label: 'Widgets'),
              NibNavItem(id: 'gadgets', label: 'Gadgets'),
            ],
          ),
        ],
      ),
    ),
  );
  expect(find.text('Widgets'), findsNothing);

  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsOneWidget);
  expect(find.text('Gadgets'), findsOneWidget);
});

testWidgets('tapping the same branch item again closes the flyout', (tester) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [NibNavItem(id: 'widgets', label: 'Widgets')],
          ),
        ],
      ),
    ),
  );
  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsOneWidget);

  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsNothing);
});

testWidgets('selecting a leaf inside a flyout calls onItemSelected and closes it', (
  tester,
) async {
  String? selected;
  await tester.pumpWidget(
    _wrap(
      NibNavigationMenu(
        items: const [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [NibNavItem(id: 'widgets', label: 'Widgets')],
          ),
        ],
        onItemSelected: (id) => selected = id,
      ),
    ),
  );
  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Widgets'));
  await tester.pumpAndSettle();
  expect(selected, 'widgets');
  expect(find.text('Widgets'), findsNothing);
});

testWidgets('tapping outside the flyout closes it', (tester) async {
  await tester.pumpWidget(
    _wrap(
      Column(
        children: [
          const NibNavigationMenu(
            items: [
              NibNavItem(
                id: 'products',
                label: 'Products',
                children: [NibNavItem(id: 'widgets', label: 'Widgets')],
              ),
            ],
          ),
          const SizedBox(height: 40, child: Text('outside')),
        ],
      ),
    ),
  );
  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsOneWidget);

  await tester.tap(find.text('outside'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsNothing);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/navigation_menu/nib_navigation_menu_test.dart`
Expected: FAIL — branch items don't open anything yet.

- [ ] **Step 3: Implement the flyout**

Add the import in `lib/src/navigation_menu/nib_navigation_menu.dart`:

```dart
import '../overlay/nib_anchored_overlay.dart';
```

Add a field and dispose-time cleanup to `_NibNavigationMenuState`:

```dart
final Map<String, NibAnchoredOverlayHandle> _flyoutHandles = {};

@override
void dispose() {
  for (final handle in _flyoutHandles.values) {
    handle.remove();
  }
  _unbindController();
  super.dispose();
}
```

Replace the `_handleItemTap` stub with:

```dart
void _handleItemTap(NibNavItem item, List<String> path, List<String> siblingIds) {
  if (item.disabled) return;
  if (!item.hasChildren) {
    widget.onItemSelected?.call(item.id);
    _closeFlyoutsFrom(0);
    return;
  }
  if (widget.orientation == NibNavMenuOrientation.horizontal) {
    _toggleFlyout(item, path);
  }
  // Vertical inline-expand branch behavior lands in Task 6.
}

void _toggleFlyout(NibNavItem item, List<String> path) {
  final depth = path.length - 1;
  final chain = _controller.openChain;
  final alreadyOpenHere = chain.length > depth && chain[depth] == item.id;
  if (alreadyOpenHere) {
    _closeFlyoutsFrom(depth);
    return;
  }
  _closeFlyoutsFrom(depth);
  final renderBox = _keyFor(item.id).currentContext!.findRenderObject() as RenderBox;
  final handle = NibAnchoredOverlay.show(
    context,
    link: _linkFor(item.id),
    targetRenderBox: renderBox,
    placement: depth == 0 ? NibOverlayPlacement.bottom : NibOverlayPlacement.end,
    contentBuilder: (overlayContext) => _buildFlyoutContent(item.children, path),
    onDismissed: () => _closeFlyoutsFrom(depth),
  );
  _flyoutHandles[item.id] = handle;
  _controller.openChainTo(path);
}

void _closeFlyoutsFrom(int depth) {
  final chain = _controller.openChain;
  for (var i = chain.length - 1; i >= depth && i >= 0; i--) {
    _flyoutHandles.remove(chain[i])?.remove();
  }
  _controller.closeFromDepth(depth);
}

Widget _buildFlyoutContent(List<NibNavItem> items, List<String> parentPath) {
  final theme = NibTheme.of(context);
  final siblingIds = [for (final i in items) i.id];
  return Material(
    color: theme.card,
    elevation: 4,
    borderRadius: BorderRadius.circular(theme.radiusDefault),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final child in items)
            _buildItem(context, theme, child, [...parentPath, child.id], siblingIds),
        ],
      ),
    ),
  );
}
```

Note: `_closeFlyoutsFrom` is called by a leaf's `onItemSelected` path too (depth `0`), which safely no-ops via the `chain.length > depth` guards when nothing is open.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/navigation_menu/nib_navigation_menu_test.dart`
Expected: PASS (9 tests total)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/navigation_menu/nib_navigation_menu.dart test/navigation_menu/nib_navigation_menu_test.dart
git commit -m "feat(navigation-menu): horizontal top-level flyout submenu"
```

---

### Task 5: Horizontal cascading multi-level flyout (recursive)

**Files:**
- Modify: `test/navigation_menu/nib_navigation_menu_test.dart` (tests only — see note below)

**Interfaces:**
- Consumes: `_toggleFlyout`, `_closeFlyoutsFrom`, `_buildFlyoutContent` (Task 4) — already depth-aware (`path`/`depth` threaded through, not hardcoded to depth 0).
- Produces: confirms an item *inside* an already-open flyout that itself has `children` opens a second, cascading flyout anchored to its side (`placement: end`), and that depth-aware close/reopen behavior (closing a shallower item collapses everything deeper; switching to a sibling at the same depth replaces just that depth downward) already works correctly.

**Important:** Task 4's `_toggleFlyout`/`_closeFlyoutsFrom` were written depth-aware from the start (`path`/`depth`, not hardcoded to top-level) specifically so cascading falls out for free — `_buildFlyoutContent` already calls `_buildItem`, which already calls `_handleItemTap`/`_toggleFlyout` for *any* horizontal branch item regardless of depth. **No new production code is expected for this task.** If any test below fails, the bug is in Task 4's depth handling — fix it there rather than adding cascade-specific special-casing.

- [ ] **Step 1: Write the tests**

Append to `test/navigation_menu/nib_navigation_menu_test.dart`:

```dart
testWidgets('an item inside an open flyout with its own children opens a cascading second flyout', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [
              NibNavItem(
                id: 'hardware',
                label: 'Hardware',
                children: [NibNavItem(id: 'widgets', label: 'Widgets')],
              ),
            ],
          ),
        ],
      ),
    ),
  );
  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  expect(find.text('Hardware'), findsOneWidget);
  expect(find.text('Widgets'), findsNothing);

  await tester.tap(find.text('Hardware'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsOneWidget);
});

testWidgets('closing the first-level flyout also closes any open cascade beneath it', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [
              NibNavItem(
                id: 'hardware',
                label: 'Hardware',
                children: [NibNavItem(id: 'widgets', label: 'Widgets')],
              ),
            ],
          ),
        ],
      ),
    ),
  );
  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hardware'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsOneWidget);

  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  expect(find.text('Hardware'), findsNothing);
  expect(find.text('Widgets'), findsNothing);
});

testWidgets('switching to a sibling at the same depth replaces the deeper cascade', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [
              NibNavItem(
                id: 'hardware',
                label: 'Hardware',
                children: [NibNavItem(id: 'widgets', label: 'Widgets')],
              ),
              NibNavItem(id: 'software', label: 'Software'),
            ],
          ),
        ],
      ),
    ),
  );
  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hardware'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsOneWidget);

  await tester.tap(find.text('Software'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsNothing);
  expect(find.text('Hardware'), findsOneWidget);
  expect(find.text('Software'), findsOneWidget);
});
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/navigation_menu/nib_navigation_menu_test.dart`
Expected: PASS (12 tests total) with zero production-code changes. If any fail, fix the depth handling in `_toggleFlyout`/`_closeFlyoutsFrom` from Task 4 — do not add cascade-specific branches.

- [ ] **Step 3: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add test/navigation_menu/nib_navigation_menu_test.dart
git commit -m "test(navigation-menu): verify cascading multi-level flyout recursion"
```

---

### Task 6: Vertical inline expand (single level) + single-open coordination

**Files:**
- Modify: `lib/src/navigation_menu/nib_navigation_menu.dart`
- Modify: `test/navigation_menu/nib_navigation_menu_test.dart`

**Interfaces:**
- Consumes: `_controller.openIds`/`toggleOpenId` (Task 2).
- Produces: in vertical orientation, tapping a branch item expands its immediate children inline below it (`Column` reflow, indented). Tapping it again collapses. `allowMultipleOpen: false` (default) closes other open siblings at the same depth when a new one opens; `true` allows multiple open at once. Cascading into grandchildren (multi-level vertical nesting) lands in Task 7 — this task's children are rendered leaf-only.

- [ ] **Step 1: Write the failing tests**

Append to `test/navigation_menu/nib_navigation_menu_test.dart`:

```dart
testWidgets('vertical: tapping a branch item expands its children inline', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        orientation: NibNavMenuOrientation.vertical,
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [NibNavItem(id: 'widgets', label: 'Widgets')],
          ),
        ],
      ),
    ),
  );
  expect(find.text('Widgets'), findsNothing);

  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsOneWidget);

  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsNothing);
});

testWidgets('vertical: single-open by default closes a sibling when a new one opens', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        orientation: NibNavMenuOrientation.vertical,
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [NibNavItem(id: 'widgets', label: 'Widgets')],
          ),
          NibNavItem(
            id: 'company',
            label: 'Company',
            children: [NibNavItem(id: 'about', label: 'About')],
          ),
        ],
      ),
    ),
  );
  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsOneWidget);

  await tester.tap(find.text('Company'));
  await tester.pumpAndSettle();
  expect(find.text('About'), findsOneWidget);
  expect(find.text('Widgets'), findsNothing);
});

testWidgets('vertical: allowMultipleOpen keeps both siblings expanded', (tester) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        orientation: NibNavMenuOrientation.vertical,
        allowMultipleOpen: true,
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [NibNavItem(id: 'widgets', label: 'Widgets')],
          ),
          NibNavItem(
            id: 'company',
            label: 'Company',
            children: [NibNavItem(id: 'about', label: 'About')],
          ),
        ],
      ),
    ),
  );
  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Company'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsOneWidget);
  expect(find.text('About'), findsOneWidget);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/navigation_menu/nib_navigation_menu_test.dart`
Expected: FAIL — vertical branch items don't expand anything yet.

- [ ] **Step 3: Implement inline expand**

Replace the `// Vertical inline-expand branch behavior lands in Task 6.` comment and its enclosing `if` in `_handleItemTap` with:

```dart
void _handleItemTap(NibNavItem item, List<String> path, List<String> siblingIds) {
  if (item.disabled) return;
  if (!item.hasChildren) {
    widget.onItemSelected?.call(item.id);
    _closeFlyoutsFrom(0);
    return;
  }
  if (widget.orientation == NibNavMenuOrientation.horizontal) {
    _toggleFlyout(item, path);
  } else {
    _toggleInline(item, siblingIds);
  }
}

void _toggleInline(NibNavItem item, List<String> siblingIds) {
  final exclusive = widget.allowMultipleOpen ? null : (siblingIds.toSet()..remove(item.id));
  _controller.toggleOpenId(item.id, exclusiveSiblings: exclusive);
}
```

Add a recursive vertical node builder (leaf-only children rendering for now — Task 7 makes it fully recursive):

```dart
Widget _buildVerticalNode(
  BuildContext context,
  NibTheme theme,
  NibNavItem item,
  List<String> path,
  List<String> siblingIds,
) {
  final header = _buildItem(context, theme, item, path, siblingIds);
  if (!item.hasChildren) return header;

  final isOpen = _controller.openIds.contains(item.id);
  final childSiblingIds = [for (final c in item.children) c.id];
  final childList = Padding(
    padding: const EdgeInsets.only(left: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in item.children)
          _buildItem(context, theme, child, [...path, child.id], childSiblingIds),
      ],
    ),
  );

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [header, if (isOpen) childList],
  );
}
```

In `build()`, change the vertical branch of `nodes` to call `_buildVerticalNode` instead of `_buildItem`:

```dart
final nodes = [
  for (final item in widget.items)
    widget.orientation == NibNavMenuOrientation.horizontal
        ? _buildItem(context, theme, item, [item.id], topSiblingIds)
        : _buildVerticalNode(context, theme, item, [item.id], topSiblingIds),
];
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/navigation_menu/nib_navigation_menu_test.dart`
Expected: PASS (15 tests total)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/navigation_menu/nib_navigation_menu.dart test/navigation_menu/nib_navigation_menu_test.dart
git commit -m "feat(navigation-menu): vertical inline expand with single-open coordination"
```

---

### Task 7: Vertical recursive multi-level inline expand

**Files:**
- Modify: `lib/src/navigation_menu/nib_navigation_menu.dart`
- Modify: `test/navigation_menu/nib_navigation_menu_test.dart`

**Interfaces:**
- Consumes: `_buildVerticalNode` (Task 6).
- Produces: a grandchild item (a child of an already-expanded child) also expands inline when tapped, indented one level further, to arbitrary depth.

- [ ] **Step 1: Write the failing test**

Append to `test/navigation_menu/nib_navigation_menu_test.dart`:

```dart
testWidgets('vertical: a grandchild branch item also expands inline, arbitrary depth', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        orientation: NibNavMenuOrientation.vertical,
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [
              NibNavItem(
                id: 'hardware',
                label: 'Hardware',
                children: [NibNavItem(id: 'widgets', label: 'Widgets')],
              ),
            ],
          ),
        ],
      ),
    ),
  );
  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  expect(find.text('Hardware'), findsOneWidget);
  expect(find.text('Widgets'), findsNothing);

  await tester.tap(find.text('Hardware'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsOneWidget);

  await tester.tap(find.text('Hardware'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsNothing);
  expect(find.text('Hardware'), findsOneWidget, reason: 'collapsing a grandchild does not collapse its parent');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/navigation_menu/nib_navigation_menu_test.dart`
Expected: FAIL — "Hardware" (a branch item nested one level deep) doesn't expand when tapped, since Task 6's `childList` renders nested children via `_buildItem` (leaf-only), not `_buildVerticalNode`.

- [ ] **Step 3: Make it recursive**

In `_buildVerticalNode`'s `childList`, replace the `_buildItem` call with a recursive `_buildVerticalNode` call:

```dart
final childList = Padding(
  padding: const EdgeInsets.only(left: 16),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final child in item.children)
        _buildVerticalNode(context, theme, child, [...path, child.id], childSiblingIds),
    ],
  ),
);
```

(This is the only change — `_buildVerticalNode` already handles the leaf case via its `if (!item.hasChildren) return header;` guard, so recursing into it for every child is correct at any depth.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/navigation_menu/nib_navigation_menu_test.dart`
Expected: PASS (16 tests total)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/navigation_menu/nib_navigation_menu.dart test/navigation_menu/nib_navigation_menu_test.dart
git commit -m "feat(navigation-menu): recursive multi-level vertical inline expand"
```

---

### Task 8: Keyboard — Escape closes an open flyout

**Files:**
- Modify: `lib/src/navigation_menu/nib_navigation_menu.dart`
- Modify: `test/navigation_menu/nib_navigation_menu_test.dart`

**Interfaces:**
- Consumes: `_closeFlyoutsFrom`, `_controller.openChain` (Task 4).
- Produces: pressing Escape while a horizontal flyout chain is open closes its deepest level.

**Note — most keyboard traversal needs no custom code.** Every item is already a focusable `InkWell` (Tasks 3–4), so Tab/Shift+Tab traversal and Left/Right/Up/Down directional movement between visible focusable items, and Enter/Space activating the focused item (same as tapping it — opening a flyout, expanding inline, or firing `onItemSelected`), all come from Flutter's own default focus traversal and `InkWell`'s built-in `ActivateIntent` handling. This mirrors the exact "works for free" finding already documented for `NibDataTable`'s row traversal in `NIB_COMPONENTS_PROGRESS.md`'s Known Gaps table. The **only** genuinely custom behavior needed is Escape, since there is no default Flutter action bound to "dismiss this custom `OverlayEntry`-based flyout."

- [ ] **Step 1: Write the failing tests**

Append to `test/navigation_menu/nib_navigation_menu_test.dart` (add `import 'package:flutter/services.dart';` at the top alongside the existing imports):

```dart
testWidgets('tab focuses the first item, then arrow-right moves to the next sibling', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        items: [
          NibNavItem(id: 'home', label: 'Home'),
          NibNavItem(id: 'about', label: 'About'),
        ],
      ),
    ),
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
  final firstFocus = FocusManager.instance.primaryFocus;
  expect(firstFocus, isNotNull);

  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await tester.pumpAndSettle();
  final secondFocus = FocusManager.instance.primaryFocus;
  expect(secondFocus, isNotNull);
  expect(identical(firstFocus, secondFocus), isFalse);
});

testWidgets('enter activates the focused horizontal branch item, opening its flyout', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [NibNavItem(id: 'widgets', label: 'Widgets')],
          ),
        ],
      ),
    ),
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsNothing);

  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsOneWidget);
});

testWidgets('enter activates a focused vertical branch item, expanding it inline', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        orientation: NibNavMenuOrientation.vertical,
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [NibNavItem(id: 'widgets', label: 'Widgets')],
          ),
        ],
      ),
    ),
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsOneWidget);
});

testWidgets('escape closes an open horizontal flyout', (tester) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [NibNavItem(id: 'widgets', label: 'Widgets')],
          ),
        ],
      ),
    ),
  );
  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsOneWidget);

  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  expect(find.text('Widgets'), findsNothing);
});
```

- [ ] **Step 2: Run tests to verify current state**

Run: `flutter test test/navigation_menu/nib_navigation_menu_test.dart`
Expected: the tab/arrow and both Enter tests already PASS (default traversal + `InkWell` activation, per the note above). Only the Escape test FAILS.

- [ ] **Step 3: Implement Escape-to-close**

Add near the top of `lib/src/navigation_menu/nib_navigation_menu.dart`:

```dart
import 'package:flutter/services.dart' show LogicalKeySet;
```

Add a private intent class at the bottom of the file:

```dart
class _CloseFlyoutIntent extends Intent {
  const _CloseFlyoutIntent();
}
```

Wrap `build()`'s existing return value in `Shortcuts`/`Actions`. Replace:

```dart
return Semantics(
  label: widget.semanticLabel,
  container: true,
  child: widget.orientation == NibNavMenuOrientation.horizontal
      ? Row(mainAxisSize: MainAxisSize.min, children: nodes)
      : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: nodes,
        ),
);
```

with:

```dart
final content = Semantics(
  label: widget.semanticLabel,
  container: true,
  child: widget.orientation == NibNavMenuOrientation.horizontal
      ? Row(mainAxisSize: MainAxisSize.min, children: nodes)
      : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: nodes,
        ),
);

return Shortcuts(
  shortcuts: const {LogicalKeySet(LogicalKeyboardKey.escape): _CloseFlyoutIntent()},
  child: Actions(
    actions: {
      _CloseFlyoutIntent: CallbackAction<_CloseFlyoutIntent>(
        onInvoke: (intent) {
          if (widget.orientation == NibNavMenuOrientation.horizontal) {
            final chain = _controller.openChain;
            if (chain.isNotEmpty) _closeFlyoutsFrom(chain.length - 1);
          }
          return null;
        },
      ),
    },
    child: content,
  ),
);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/navigation_menu/nib_navigation_menu_test.dart`
Expected: PASS (20 tests total)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/navigation_menu/nib_navigation_menu.dart test/navigation_menu/nib_navigation_menu_test.dart
git commit -m "feat(navigation-menu): escape closes an open flyout"
```

---

### Task 9: Horizontal overflow — dynamic-measurement "More" menu

**Files:**
- Modify: `lib/src/navigation_menu/nib_navigation_menu.dart`
- Modify: `test/navigation_menu/nib_navigation_menu_test.dart`

**Interfaces:**
- Consumes: `MeasureSize` (Task 1); `_buildItem`, `_toggleFlyout`/flyout machinery (Tasks 3–5).
- Produces: in horizontal orientation, when the available width can't fit every top-level item, the items that don't fit collapse into a synthetic trailing `NibNavItem(id: '__more__', label: 'More', children: overflowItems)`, opened via the exact same flyout machinery as any other branch item. Widths are measured for real (an invisible `Offstage` pass), not estimated from fixed breakpoints.

- [ ] **Step 1: Write the failing tests**

Append to `test/navigation_menu/nib_navigation_menu_test.dart`:

```dart
testWidgets('horizontal: items that do not fit collapse into a trailing "More" flyout', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      SizedBox(
        width: 220,
        child: const NibNavigationMenu(
          items: [
            NibNavItem(id: 'home', label: 'Home'),
            NibNavItem(id: 'products', label: 'Products'),
            NibNavItem(id: 'about', label: 'About Us'),
            NibNavItem(id: 'contact', label: 'Contact'),
            NibNavItem(id: 'careers', label: 'Careers'),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Home'), findsOneWidget);
  expect(find.text('More'), findsOneWidget);
  expect(find.text('Careers'), findsNothing);

  await tester.tap(find.text('More'));
  await tester.pumpAndSettle();
  expect(find.text('Careers'), findsOneWidget);
});

testWidgets('horizontal: a wide viewport shows every item with no "More" trigger', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        items: [
          NibNavItem(id: 'home', label: 'Home'),
          NibNavItem(id: 'about', label: 'About'),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('More'), findsNothing);
  expect(find.text('Home'), findsOneWidget);
  expect(find.text('About'), findsOneWidget);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/navigation_menu/nib_navigation_menu_test.dart`
Expected: FAIL — every item always renders directly, regardless of available width; no "More" trigger exists yet.

- [ ] **Step 3: Implement dynamic-measurement overflow**

Add the import in `lib/src/navigation_menu/nib_navigation_menu.dart`:

```dart
import '../overlay/measure_size.dart';
```

Add a field and width-tracking to `_NibNavigationMenuState`:

```dart
final Map<String, double> _measuredWidths = {};

void _recordWidth(String id, double width) {
  if (_measuredWidths[id] == width) return;
  setState(() => _measuredWidths[id] = width);
}
```

In `didUpdateWidget`, drop stale measurements for removed items (append after the existing controller-rebind check):

```dart
final currentIds = {for (final i in widget.items) i.id};
_measuredWidths.removeWhere((id, _) => id != '__more__' && !currentIds.contains(id));
```

Add a measurement-only visual builder (no interactive chrome, no `GlobalKey` — used only inside an invisible `Offstage` pass, so it must not collide with the real item's key from `_keyFor`):

```dart
Widget _measureVisual(NibNavItem item) {
  final theme = NibTheme.of(context);
  return ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.icon != null) ...[item.icon!, const SizedBox(width: 8)],
          Text(item.label, style: TextStyle(color: theme.foreground)),
          if (item.badge != null) ...[const SizedBox(width: 6), item.badge!],
        ],
      ),
    ),
  );
}
```

Add the packing function:

```dart
({List<NibNavItem> visible, List<NibNavItem> overflow}) _packItems(
  double maxWidth,
  double moreWidth,
) {
  var used = 0.0;
  final visible = <NibNavItem>[];
  final overflow = <NibNavItem>[];
  for (var i = 0; i < widget.items.length; i++) {
    final item = widget.items[i];
    final width = _measuredWidths[item.id];
    if (width == null) {
      // Not measured yet this frame — show everything until we know better.
      visible.add(item);
      continue;
    }
    final hasMoreAfter = i < widget.items.length - 1;
    final reserve = hasMoreAfter ? moreWidth : 0.0;
    if (visible.isEmpty || used + width + reserve <= maxWidth) {
      used += width;
      visible.add(item);
    } else {
      overflow.addAll(widget.items.sublist(i));
      break;
    }
  }
  return (visible: visible, overflow: overflow);
}
```

Add a dedicated horizontal-row builder:

```dart
Widget _buildHorizontalRow(BuildContext context, NibTheme theme) {
  final measuringPass = Offstage(
    offstage: true,
    child: Row(
      children: [
        for (final item in widget.items)
          MeasureSize(
            onChange: (size) => _recordWidth(item.id, size.width),
            child: _measureVisual(item),
          ),
        MeasureSize(
          onChange: (size) => _recordWidth('__more__', size.width),
          child: _measureVisual(const NibNavItem(id: '__more__', label: 'More')),
        ),
      ],
    ),
  );

  return LayoutBuilder(
    builder: (context, constraints) {
      final moreWidth = _measuredWidths['__more__'] ?? 72.0;
      final packed = _packItems(constraints.maxWidth, moreWidth);
      final displayItems = packed.overflow.isEmpty
          ? packed.visible
          : [
              ...packed.visible,
              NibNavItem(id: '__more__', label: 'More', children: packed.overflow),
            ];
      final topSiblingIds = [for (final i in displayItems) i.id];
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          measuringPass,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in displayItems)
                _buildItem(context, theme, item, [item.id], topSiblingIds),
            ],
          ),
        ],
      );
    },
  );
}
```

In `build()`, change the horizontal branch of `content` to use it:

```dart
final content = Semantics(
  label: widget.semanticLabel,
  container: true,
  child: widget.orientation == NibNavMenuOrientation.horizontal
      ? _buildHorizontalRow(context, theme)
      : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: nodes,
        ),
);
```

`nodes` is now only used by the vertical branch — narrow its declaration above this to only build vertical nodes (the horizontal branch no longer needs the flat `nodes` list at all, since `_buildHorizontalRow` builds its own `displayItems` from `widget.items` directly):

```dart
final topSiblingIds = [for (final i in widget.items) i.id];
final nodes = widget.orientation == NibNavMenuOrientation.vertical
    ? [
        for (final item in widget.items)
          _buildVerticalNode(context, theme, item, [item.id], topSiblingIds),
      ]
    : const <Widget>[];
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/navigation_menu/nib_navigation_menu_test.dart`
Expected: PASS (22 tests total)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/navigation_menu/nib_navigation_menu.dart test/navigation_menu/nib_navigation_menu_test.dart
git commit -m "feat(navigation-menu): dynamic-measurement horizontal overflow \"More\" menu"
```

---

### Task 10: NibMotion integration — animated flyout entrance + animated inline reveal

**Files:**
- Modify: `lib/src/navigation_menu/nib_navigation_menu.dart`
- Modify: `test/navigation_menu/nib_navigation_menu_test.dart`

**Interfaces:**
- Consumes: `NibMotion`, `NibAnim`, `NibTransition`, `NibPresence` (`package:nib_motion/nib_motion.dart`, already imported since Task 3).
- Produces: when `widget.animated` is `true`, an opened horizontal flyout fades+scales in via `NibMotion`; an opened vertical inline reveal fades+slides in/out via `NibPresence` + a keyed `NibMotion` with `exit`. When `false` (default), zero `NibMotion`/`NibPresence` widgets are built anywhere.

- [ ] **Step 1: Write the failing tests**

Append to `test/navigation_menu/nib_navigation_menu_test.dart` (add `import 'package:nib_motion/nib_motion.dart';` at the top alongside the existing imports):

```dart
testWidgets('animated: false builds zero NibMotion widgets for an open flyout', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [NibNavItem(id: 'widgets', label: 'Widgets')],
          ),
        ],
      ),
    ),
  );
  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  expect(find.byType(NibMotion), findsNothing);
});

testWidgets('animated: true wraps an opened flyout in NibMotion', (tester) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        animated: true,
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [NibNavItem(id: 'widgets', label: 'Widgets')],
          ),
        ],
      ),
    ),
  );
  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  expect(find.byType(NibMotion), findsWidgets);
});

testWidgets('animated: false builds zero NibMotion/NibPresence widgets for vertical inline reveal', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        orientation: NibNavMenuOrientation.vertical,
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [NibNavItem(id: 'widgets', label: 'Widgets')],
          ),
        ],
      ),
    ),
  );
  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  expect(find.byType(NibMotion), findsNothing);
  expect(find.byType(NibPresence), findsNothing);
});

testWidgets('animated: true wraps an opened vertical inline reveal in NibPresence + NibMotion', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      const NibNavigationMenu(
        orientation: NibNavMenuOrientation.vertical,
        animated: true,
        items: [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [NibNavItem(id: 'widgets', label: 'Widgets')],
          ),
        ],
      ),
    ),
  );
  await tester.tap(find.text('Products'));
  await tester.pumpAndSettle();
  expect(find.byType(NibPresence), findsOneWidget);
  expect(find.byType(NibMotion), findsOneWidget);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/navigation_menu/nib_navigation_menu_test.dart`
Expected: FAIL — the two `animated: true` tests fail (no `NibMotion`/`NibPresence` built yet); the two `animated: false` tests already pass.

- [ ] **Step 3: Implement animation**

In `_toggleFlyout` (Task 4), replace the `contentBuilder` argument to `NibAnchoredOverlay.show` with:

```dart
contentBuilder: (overlayContext) {
  final built = _buildFlyoutContent(item.children, path);
  if (!widget.animated) return built;
  return NibMotion(
    initial: const NibAnim(opacity: 0, scale: 0.95),
    animate: const NibAnim(opacity: 1, scale: 1),
    transition: widget.transition ?? const NibTransition(duration: Duration(milliseconds: 160)),
    child: built,
  );
},
```

In `_buildVerticalNode` (Tasks 6–7), replace the final `return Column(... children: [header, if (isOpen) childList]);` with:

```dart
final reveal = widget.animated
    ? NibPresence(
        children: [
          if (isOpen)
            NibMotion(
              key: ValueKey('nib-nav-inline-${item.id}'),
              initial: const NibAnim(opacity: 0, y: -6),
              animate: const NibAnim(opacity: 1, y: 0),
              exit: const NibAnim(opacity: 0, y: -6),
              transition:
                  widget.transition ?? const NibTransition(duration: Duration(milliseconds: 180)),
              child: childList,
            ),
        ],
      )
    : (isOpen ? childList : const SizedBox.shrink());

return Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [header, reveal],
);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/navigation_menu/nib_navigation_menu_test.dart`
Expected: PASS (26 tests total)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/navigation_menu/nib_navigation_menu.dart test/navigation_menu/nib_navigation_menu_test.dart
git commit -m "feat(navigation-menu): opt-in NibMotion entrance/exit for flyouts and inline reveal"
```

---

### Task 11: Example app wiring, full verification, progress tracker update

**Files:**
- Create: `example/lib/examples/navigation_menu_examples.dart`
- Modify: `example/lib/catalog.dart`
- Modify: `NIB_COMPONENTS_PROGRESS.md`

**Interfaces:**
- Consumes: `NibNavigationMenu`, `NibNavItem`, `NibNavMenuOrientation`, `NibNavMenuController` (all prior tasks).
- Produces: 4 demo widgets registered in the example app's catalog — minimal, a common-variant cascading flyout, an advanced vertical/controller/animated/disabled/badge demo, and a deterministic overflow-triggering demo (mirrors `DataTableWideExample`'s fixed-narrow-container convention).

- [ ] **Step 1: Write the example demos**

```dart
// example/lib/examples/navigation_menu_examples.dart
import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal/default usage — flat leaf items, horizontal.
class NavigationMenuMinimalExample extends StatelessWidget {
  const NavigationMenuMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return NibNavigationMenu(
      items: const [
        NibNavItem(id: 'home', label: 'Home'),
        NibNavItem(id: 'about', label: 'About'),
        NibNavItem(id: 'contact', label: 'Contact'),
      ],
      onItemSelected: (id) {},
    );
  }
}

/// 2. Common variant — cascading multi-level flyout, active-item indicator.
class NavigationMenuFlyoutExample extends StatefulWidget {
  const NavigationMenuFlyoutExample({super.key});

  @override
  State<NavigationMenuFlyoutExample> createState() =>
      _NavigationMenuFlyoutExampleState();
}

class _NavigationMenuFlyoutExampleState extends State<NavigationMenuFlyoutExample> {
  String _activeId = 'home';

  @override
  Widget build(BuildContext context) {
    return NibNavigationMenu(
      activeItemId: _activeId,
      items: const [
        NibNavItem(id: 'home', label: 'Home'),
        NibNavItem(
          id: 'products',
          label: 'Products',
          children: [
            NibNavItem(id: 'widgets', label: 'Widgets'),
            NibNavItem(
              id: 'hardware',
              label: 'Hardware',
              children: [
                NibNavItem(id: 'sensors', label: 'Sensors'),
                NibNavItem(id: 'controllers', label: 'Controllers'),
              ],
            ),
          ],
        ),
        NibNavItem(id: 'about', label: 'About'),
      ],
      onItemSelected: (id) => setState(() => _activeId = id),
    );
  }
}

/// 3. Advanced — vertical orientation, external controller, animated toggle,
/// allowMultipleOpen toggle, disabled item, badge.
class NavigationMenuAdvancedExample extends StatefulWidget {
  const NavigationMenuAdvancedExample({super.key});

  @override
  State<NavigationMenuAdvancedExample> createState() =>
      _NavigationMenuAdvancedExampleState();
}

class _NavigationMenuAdvancedExampleState
    extends State<NavigationMenuAdvancedExample> {
  final _controller = NibNavMenuController();
  bool _animated = true;
  bool _allowMultipleOpen = false;
  String? _selected;

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
        SwitchListTile(
          title: const Text('Animated'),
          value: _animated,
          onChanged: (value) => setState(() => _animated = value),
        ),
        SwitchListTile(
          title: const Text('Allow multiple open'),
          value: _allowMultipleOpen,
          onChanged: (value) => setState(() => _allowMultipleOpen = value),
        ),
        if (_selected != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Selected: $_selected'),
          ),
        NibNavigationMenu(
          orientation: NibNavMenuOrientation.vertical,
          controller: _controller,
          animated: _animated,
          allowMultipleOpen: _allowMultipleOpen,
          items: [
            const NibNavItem(
              id: 'products',
              label: 'Products',
              children: [
                NibNavItem(id: 'widgets', label: 'Widgets'),
                NibNavItem(id: 'gadgets', label: 'Gadgets', disabled: true),
              ],
            ),
            NibNavItem(
              id: 'company',
              label: 'Company',
              badge: const SizedBox(
                width: 8,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                ),
              ),
              children: const [
                NibNavItem(id: 'about', label: 'About'),
                NibNavItem(id: 'careers', label: 'Careers'),
              ],
            ),
          ],
          onItemSelected: (id) => setState(() => _selected = id),
        ),
      ],
    );
  }
}

/// 4. Overflow demo — pinned to a narrow width (deliberately narrower than
/// every item's combined natural width) so the "More" flyout always
/// triggers, regardless of the host window's actual size. Mirrors
/// `DataTableWideExample`'s deterministic-trigger convention.
class NavigationMenuOverflowExample extends StatelessWidget {
  const NavigationMenuOverflowExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 260,
      child: NibNavigationMenu(
        items: [
          NibNavItem(id: 'home', label: 'Home'),
          NibNavItem(id: 'products', label: 'Products'),
          NibNavItem(id: 'about', label: 'About Us'),
          NibNavItem(id: 'contact', label: 'Contact'),
          NibNavItem(id: 'careers', label: 'Careers'),
          NibNavItem(id: 'blog', label: 'Blog'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Register in the catalog**

In `example/lib/catalog.dart`, add the import and four entries after the existing Data Table entries:

```dart
import 'examples/navigation_menu_examples.dart';
```

```dart
CatalogEntry(
  name: 'Navigation Menu — minimal',
  builder: (context) => const NavigationMenuMinimalExample(),
),
CatalogEntry(
  name: 'Navigation Menu — cascading flyout',
  builder: (context) => const NavigationMenuFlyoutExample(),
),
CatalogEntry(
  name: 'Navigation Menu — advanced (vertical, controller, animated)',
  builder: (context) => const NavigationMenuAdvancedExample(),
),
CatalogEntry(
  name: 'Navigation Menu — overflow (narrow, "More" menu)',
  builder: (context) => const NavigationMenuOverflowExample(),
),
```

- [ ] **Step 3: Run full verification**

Run: `flutter test && flutter analyze && (cd example && flutter analyze)`
Expected: every test PASS (26 in `nib_navigation_menu_test.dart` + 8 in `nib_navigation_menu_controller_test.dart` + 4 in `nib_anchored_overlay_test.dart`, plus all pre-existing Data Table/theme tests unaffected), `No issues found!` from both analyzer runs.

- [ ] **Step 4: Update the progress tracker**

In `NIB_COMPONENTS_PROGRESS.md`, change the Navigation Menu row in the Tier A table from:

```
| 2 | Navigation Menu | not started | |
```

to:

```
| 2 | Navigation Menu | built — awaiting visual confirm | 2026-07-10 |
```

Per the project's session workflow rules (`CLAUDE.md`), do **not** mark it `verified` — that status is reserved for the user's own check after running `flutter run -d linux` in `example/`.

- [ ] **Step 5: Commit**

```bash
git add example/lib/examples/navigation_menu_examples.dart example/lib/catalog.dart NIB_COMPONENTS_PROGRESS.md
git commit -m "feat(navigation-menu): wire example app demos, mark built — awaiting visual confirm"
```

---

## Self-Review

**Spec coverage** (against `docs/superpowers/specs/2026-07-10-navigation-menu-design.md`): shared anchor primitive (Task 1) ✓; recursive `NibNavItem` model + controller (Task 2) ✓; leaf render/active indicator/disabled (Task 3) ✓; horizontal single-level flyout (Task 4) ✓; cascading multi-level flyout (Task 5) ✓; vertical single-level inline expand + single-open coordination (Task 6) ✓; vertical recursive nested inline expand (Task 7) ✓; keyboard traversal + Escape (Task 8) ✓; dynamic-measurement overflow "More" menu (Task 9) ✓; opt-in NibMotion entrance/exit (Task 10) ✓; optional controller (Task 2) ✓; example wiring + tests + progress update (Task 11) ✓. Documented known gaps (hover-to-open, sticky active-item scroll) intentionally out of scope for this pass, per the design spec.

**Placeholder scan:** no `TBD`/`TODO` — every code block is complete. Task 5 is intentionally implementation-free (verification only), explicitly flagged as such rather than left ambiguous.

**Type consistency:** `NibNavItem`, `NibNavMenuOrientation`, `NibNavMenuController`, `NibAnchoredOverlay`/`NibAnchoredOverlayHandle`/`NibOverlayPlacement`, `MeasureSize` are used identically across every task that references them. `_buildItem(context, theme, item, path, siblingIds)`'s signature is introduced in Task 3 and never changes shape afterward — only its call sites and internal branching grow.

## Execution Handoff

Per this repo's `CLAUDE.md` session workflow rules ("Write code directly — no implementer/reviewer subagent pattern by default"), this plan should be executed via **superpowers:executing-plans** (inline, in the main session) rather than subagent-driven — that choice is already pinned by project convention, not left open per-plan.
