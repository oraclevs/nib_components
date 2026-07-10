# Navigation Menu — Design

Status: approved, ready for implementation plan.
Component: #2 in `NIB_COMPONENTS_MASTER_PROMPT.md` §3 Tier A build order.

## One-line reorder note (per master prompt §5.10 / §8.5)

Popover (#10) owns the general anchored-overlay/flip/clamp primitive, but Navigation Menu (#2) needs it for submenu flyouts. Rather than duplicate positioning logic now and redo it properly at #10, this pass extracts a minimal shared primitive early: `lib/src/overlay/nib_anchored_overlay.dart`. Popover will reuse/extend this file rather than rebuild it. This is the one-time reorder the master prompt asked to flag, not a silent change to build order — Navigation Menu itself stays at #2.

## Shared primitive: `nib_anchored_overlay.dart`

Generic, nav-menu-agnostic. Wraps `CompositedTransformTarget` / `CompositedTransformFollower` + `OverlayEntry` — the same low-level primitives Flutter's own overlay-anchored widgets (`Tooltip`, `DropdownButton` internals) are built on, satisfying §1.1's "build native, not wrapped."

Responsibilities:
- Given a trigger's `LayerLink` + size and a preferred placement, compute flip (try the opposite side if the preferred side doesn't fit in the viewport) and clamp the resulting rect to screen bounds.
- Expose a small imperative API, e.g. `NibAnchoredOverlay.show(context, {required LayerLink link, required Size triggerSize, required WidgetBuilder contentBuilder, NibOverlayPlacement placement, VoidCallback? onDismiss})` returning a handle with `.remove()`.
- No nav-menu-specific concepts (items, cascades, selection) live here — purely positioning.

## Directory layout

```
lib/src/overlay/nib_anchored_overlay.dart        (shared primitive)
lib/src/navigation_menu/
  nib_navigation_menu.dart              (NibNavigationMenu widget)
  nib_nav_item.dart                     (NibNavItem data class, recursive children)
  nib_navigation_menu_types.dart        (NibNavMenuOrientation, NibOverlayPlacement if not colocated with overlay/)
  nib_navigation_menu_controller.dart   (optional NibNavMenuController)
```

## Data model

```dart
class NibNavItem {
  final String id;
  final String label;
  final Widget? icon;
  final bool disabled;
  final Widget? badge;
  final List<NibNavItem> children; // empty = leaf; recursive nesting supports cascades
}
```

## Widget API

```dart
NibNavigationMenu({
  required List<NibNavItem> items,
  NibNavMenuOrientation orientation = .horizontal,
  String? activeItemId,
  ValueChanged<String>? onItemSelected,
  bool allowMultipleOpen = false,   // vertical inline-expand sibling coordination
  bool animated = false,
  NibAnimationPreset? animation,
  NibNavMenuController? controller,
})
```

## State & interaction model

- **Horizontal:** top-level items in a `Row`. Tapping an item with `children` opens a flyout (via the anchor primitive) anchored below it. A child within that flyout that itself has `children` opens a cascading side-anchored sub-flyout (recursion — same anchor primitive, `placement: end`). Internal state: `List<String> _openChain` (ids from root to deepest open flyout). Tapping outside or pressing Escape collapses one level (Escape pops the last chain entry); tapping fully outside the whole chain collapses it entirely.
- **Vertical:** top-level items in a `Column`. Tapping an item with `children` expands inline (indented nested list); height animates via NibMotion when `animated: true`, instant show/hide otherwise. Internal state: `Set<String> _openIds`. If `allowMultipleOpen == false` (default), opening a sibling closes other open siblings at that same depth — mirrors the Accordion (#15) single-open behavior already planned.
- Both orientations share one recursive internal widget (`_NavItemNode`) for leaf/branch rendering so the logic isn't duplicated per orientation.
- `activeItemId` only drives a visual indicator (underline/background, token-driven) on the matching item. It is fully decoupled from expand/collapse state — it's a "current page" marker, not a trigger.
- **Keyboard** (`FocusNode` per item + `Shortcuts`/`Actions`):
  - Horizontal: Left/Right moves between top-level siblings. Down/Enter opens a flyout and moves focus into it. Right (once inside a flyout, on an item with children) drills into a cascade. Left/Escape backs out one level.
  - Vertical: Up/Down moves between currently-visible items in tree order. Right/Enter expands a branch and moves focus into its children. Left collapses the current branch and returns focus to its parent.

## Overflow ("More" menu) — horizontal only

A small custom `RenderObject` (`_MeasureSize`, wraps a child and reports its laid-out size via callback) measures each top-level item's real width in an invisible/off-screen pass. The visible `LayoutBuilder` then packs items left-to-right against available width; the first item that wouldn't fit (leaving room for a trailing "More" trigger) — and everything after it — moves into a synthetic `NibNavItem` (id `__more__`) whose `children` is that leftover list. This reuses the exact same flyout/cascade machinery already built for regular submenus; there is no separately-coded overflow UI path.

## NibMotion integration

- `animated: false` (default): instant show/hide for both flyouts and inline expand; zero `NibMotion` widgets built.
- `animated: true`: flyouts default to a fade+scale-from-anchor preset; vertical inline expand defaults to a height/opacity preset. Both overridable via `animation`.

## Testing plan (per §1.6 / §1.7)

- Default render, horizontal, no children open.
- Leaf item tap fires `onItemSelected`.
- Branch item tap opens flyout (horizontal) / inline expand (vertical).
- `allowMultipleOpen: false` closes sibling submenus when a new one opens; `true` allows multiple.
- Disabled item does not open or fire `onItemSelected`.
- Active-item indicator renders on the item matching `activeItemId`.
- Cascading second-level flyout opens from an item inside an already-open first-level flyout.
- Keyboard traversal: arrow keys between siblings, Enter/Right to open/drill in, Escape/Left to back out.
- Narrow-width pump (`SizedBox` narrower than total item width) forces overflow: "More" trigger appears; tapping it opens the leftover items via the same flyout path.
- `animated: true` vs `false`: `find.byType(NibMotion)` present vs `findsNothing`.

## Known gaps for this pass (documented, not silently dropped)

- Hover-to-open on desktop for horizontal flyouts is deferred — tap/click-only for now (all platforms). Hover-intent timing belongs to Hover Card's (#12) problem space; revisit if a stronger desktop-parity need shows up.
- No sticky/scroll-into-view behavior for the active item in very long vertical menus.
