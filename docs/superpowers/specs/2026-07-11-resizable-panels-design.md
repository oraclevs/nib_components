# Resizable Panels — Design

Status: approved, ready for implementation plan.
Component: #3 in `NIB_COMPONENTS_MASTER_PROMPT.md` §3 Tier A build order.

## Why this is hard (per master prompt §5.3)

No Flutter/Material precedent. Needs genuine custom `RenderObject` work — nested
`Expanded`/`Flexible` plus a manually-dragged `SizedBox` cannot correctly enforce
per-panel min/max during a drag that affects two panels at once, since Flutter's
own flex layout algorithm would be fighting our constraint solver rather than
implementing it.

## Directory layout

```
lib/src/resizable_panels/
  nib_resizable_panels.dart              (NibResizablePanels widget, public API)
  nib_resizable_panel.dart               (NibResizablePanel data class)
  nib_resizable_panels_types.dart        (enums: NibResizablePanelsDirection is just Axis; handle state enum)
  nib_resizable_panels_controller.dart   (optional NibResizablePanelsController)
  render_resizable_panels.dart           (_RenderResizablePanels — the custom RenderObject)
```

## Data model

```dart
class NibResizablePanel {
  const NibResizablePanel({
    required this.child,
    this.minSize = 0.1,
    this.maxSize = 1.0,
    this.initialSize,
  });

  final Widget child;
  final double minSize;   // fraction [0.0, 1.0] of the group's main-axis extent
  final double maxSize;   // fraction [0.0, 1.0]
  final double? initialSize; // fraction; null = share remaining space evenly
}
```

All sizes are **fractions of the group's own main-axis extent**, not pixels.
`initialSize`s that don't sum to 1.0 across all panels are normalized at layout
time (proportionally scaled so they do) — this keeps the common case (`initialSize`
omitted entirely = equal split) trivial while still allowing exact ratios like
`0.25/0.5/0.25`.

## Widget API

```dart
NibResizablePanels({
  super.key,
  required Axis direction,
  required List<NibResizablePanel> panels,
  NibResizablePanelsController? controller,
  ValueChanged<List<double>>? onLayoutChanged, // fires on drag end + keyboard nudge + reset
  double handleThickness = 1.0,   // visual line thickness; hit-test slop is wider, fixed
  bool animated = false,
  NibAnimationPreset? animation,  // applied to handle hover/active affordance only
})
```

`panels.length` must be ≥ 2 (asserted in debug mode). At least two panels are
required for a handle to exist at all.

## Controller

```dart
class NibResizablePanelsController extends ChangeNotifier {
  NibResizablePanelsController({List<double>? initialSizes});

  List<double> get sizes;              // current fractions, always sums to 1.0
  void setSizes(List<double> sizes);   // clamped per-panel min/max, re-normalized, notifies
  void resetPanelPair(int handleIndex);// resets the two panels adjacent to that handle to their initialSize
  void resetAll();                     // resets every panel to its initialSize
}
```

Never required for basic use — `NibResizablePanels` creates and owns its own
controller internally when none is passed, disposing it correctly on
unmount/controller-swap (same pattern as `NibDataTableController`,
`NibNavMenuController`).

## The custom RenderObject: `_RenderResizablePanels`

`RenderBox` + `ContainerRenderObjectMixin<RenderBox, _ResizablePanelsParentData>`
+ `RenderBoxContainerDefaultsMixin`. One render object owns every panel child
plus paints the handles between them (handles are not separate child widgets —
they're painted and hit-tested by the render object itself, at the gaps
between laid-out children). This keeps constraint-solving, layout, painting,
and hit-testing all in one place instead of splitting the source of truth
between a `Row`/`Column` and a separately-dragged overlay.

Responsibilities:
- **Layout pass:** given the incoming `BoxConstraints`, compute each panel's
  pixel extent from its current fraction × the group's main-axis extent, lay
  out each child with tight main-axis / loose cross-axis constraints, position
  them sequentially.
- **Handle painting:** for each of `panels.length - 1` gaps, paint a thin line
  in the gap using `border` token by default, `ring` token while
  hovered/dragging (`MouseRegion` state tracked per-handle in the render
  object).
- **Hit testing:** each handle's hit-test region is wider than its painted
  thickness (fixed touch-friendly slop, not configurable) so it's draggable
  without pixel-perfect precision, matching the touch-target concern already
  raised for Data Table.
- **Drag handling:** `RenderObject`-level `PanGestureRecognizer`-equivalent via
  raw pointer events (`handleEvent`), converting drag delta to a fraction
  delta (`delta.dx / size.width` for horizontal), applying it to the two
  panels adjacent to the dragged handle only, clamped independently to each
  panel's own `minSize`/`maxSize` — **stop-at-limit, no cascade to further
  panels**. `markNeedsLayout()` on change; `onLayoutChanged` fires once on
  drag end (not per-frame) to avoid flooding the host app.
- **Double-click/tap reset:** resets only the two panels adjacent to the
  double-clicked handle to their `initialSize` fractions (re-normalized
  against each other, other panels/handles untouched).
- **Keyboard:** each handle is independently focusable (`Focus` node created
  and managed by the render object, one per handle — or, if simpler in
  practice during implementation, a thin `Focus`+`Semantics` widget per handle
  composited by the surrounding `NibResizablePanels` widget rather than the
  render object itself; implementation may choose whichever keeps focus
  management simplest, as long as each handle is independently focusable).
  Left/Right (horizontal) or Up/Down (vertical) nudge the two adjacent panels
  by a fixed step (2% of group extent) per key press, same clamp/no-cascade
  rule as drag. Home/End jump to that handle's min/max extremes. Each nudge
  fires `onLayoutChanged`.
- **Semantics:** each handle exposes a `Semantics` node (`label: "Resize
  handle"`, `increasedValue`/`decreasedValue` actions wired to the same
  nudge logic keyboard uses) so screen readers get a real affordance, not
  just a focusable rectangle.

## Narrow-viewport fallback (per §1.7)

A `LayoutBuilder` wraps `_RenderResizablePanels`. If the available main-axis
extent is below `panels.length * 160px` (the same "would squish below a
usable size" check Data Table uses, with 160px as this component's usable-
panel floor), the group renders as a plain, **always vertically-scrolling**
`SingleChildScrollView` stacking each panel full-width, one per row, with
**no handles, no dragging** — resize interaction is meaningless once panels
can't share the available space at a usable size. For a `vertical` group
this is the same axis it already uses (it just gains scrolling instead of
squishing). For a `horizontal` group this is an axis pivot: side-by-side
panels collapse into a single vertical column, matching the locked decision
from brainstorming ("collapse to stacked/scrollable single-column") rather
than merely making the horizontal row scrollable sideways. Above the
threshold, normal resizable behavior applies. This mirrors Data Table's
LayoutBuilder→scrollable-fallback pattern (§1.7) rather than introducing a
new mechanism.

## NibMotion integration

- `animated: false` (default): handle hover/active affordance is an instant
  color swap (`border` → `ring` token), zero `NibMotion` widgets built.
- `animated: true`: handle hover/active affordance transitions via NibMotion's
  color-tween primitive; panel content itself is never animated by this
  component (panels resize instantly with the drag/keyboard input — animating
  the actual size during a drag would fight the pointer). Default preset is a
  short color-fade; overridable via `animation`.

## Nesting

Supported implicitly — a `NibResizablePanel.child` can itself be a
`NibResizablePanels` (e.g. an outer vertical split with a nested horizontal
split as one panel's content). No special-case coordination code; each group
is a self-contained render object that only knows about its own direct
children. Verified with one nested-groups widget test, not a distinct code
path.

## Testing plan (per §1.6 / §1.7)

- Default render: N panels laid out at their initial fractions, N−1 handles
  present.
- `initialSize`s that don't sum to 1.0 are normalized correctly.
- Simulated drag on a handle resizes its two adjacent panels only; other
  panels/handles unaffected.
- Drag past a panel's `minSize`/`maxSize` stops at the limit (no cascade into
  the next panel).
- Double-click/tap a handle resets its two adjacent panels to their
  `initialSize`.
- Keyboard: focused handle responds to arrow-key nudge (both axes depending
  on `direction`) and Home/End; verify `onLayoutChanged` fires with the
  expected values.
- `NibResizablePanelsController.setSizes`/`resetPanelPair`/`resetAll` drive
  the same layout as user interaction and notify listeners.
- Controller created internally when none supplied; swapping a supplied
  controller disposes the old one correctly (no leak, no crash) — same check
  pattern as prior controller-owning components.
- Narrow-width pump (`SizedBox` narrower than `panels.length * 160px`) forces
  the scrollable, handle-less fallback; wide pump keeps normal resizable
  behavior. Assert no overflow/clip in the narrow case.
- Nested `NibResizablePanels` (one panel's child is itself a group) lays out
  and drags correctly at both levels independently.
- `animated: true` vs `false`: `find.byType(NibMotion), findsNothing` when
  `false`.

## Known gaps to flag if they surface during implementation

None anticipated up front beyond the general RenderObject-semantics caveat
already true of Data Table (§ formal `SemanticsRole` adoption is a broader,
separately-tracked effort, not specific to this component). Anything that
does surface goes in `NIB_COMPONENTS_PROGRESS.md`'s Known Gaps table per the
standing convention, not silently dropped.
