# NIB_COMPONENTS_MASTER_PROMPT.md
### Master build prompt for Claude Code — Nib Component Library

---

## 0. How to use this document

Give this entire file to Claude Code as the standing instruction set for the Nib component-build effort. Work through **Section 3 (Build Order)** one component at a time, top to bottom. Do not start the next component until the current one passes the Definition of Done in Section 6, with concrete evidence attached (not a claim that it works).

> **Note on the build order and per-component parameter lists below:** the hardest→simplest ranking and the specific parameter sets are my proposed design, based on typical Flutter RenderObject-level implementation complexity and the gaps identified in our earlier research — not something we'd previously locked in. Adjust anything before handing this to Claude Code if you disagree with the ordering or a parameter choice.

---

## 1. Non-Negotiable Architecture Rules (apply to every single component)

### 1.1 Build native, not wrapped
No component is allowed to be a `Container` + `GestureDetector`/`InkWell` bolted together as a shortcut. Every interactive component must be built the way Flutter's own Material widgets are built:
- Extend `StatefulWidget` (see 1.3) and construct the actual render/paint logic yourself, or compose Flutter's own low-level primitives (`RawGestureDetector`, `FocusNode`, `Actions`/`Shortcuts`, `Semantics`, `InkResponse`/custom paint for ripple, `RenderObject` subclasses where custom layout or hit-testing is required) rather than stacking high-level convenience widgets that hide what's actually happening.
- Where NibMotion needs direct paint control (per the existing NibMotion mandate), the component's internals should be structured so motion can hook in at the `RenderObject` level via `markNeedsPaint()`, not by wrapping the whole thing in an `AnimatedContainer`.
- Every component must retain, at minimum, everything a Flutter native equivalent gives for free: `Semantics` labels/roles, focus traversal order, keyboard activation (`Enter`/`Space` where applicable), proper hit-target sizing (minimum 48x48 logical pixels for tap targets), and platform-appropriate feedback (ripple on Android-style theme, opacity/scale on iOS-style theme — component decides based on the active Nib theme, not hardcoded).
- If a component has no reasonable Flutter/Material precedent (Command Palette, Combobox, Resizable Panels, etc.), build it to the same standard of care as if Flutter's own team were shipping it — reference how `ExpansionTile`, `DropdownButtonFormField`, or `Autocomplete` are implemented internally for the bar to clear.

### 1.2 Simple by default, powerful on demand
This is the core product differentiator — do not compromise on it for any component:
- Every component must be usable in its most common form with **as few required parameters as possible** — ideally just the data/content parameter(s) (e.g., `NibButton(label: 'Save', onPressed: ...)`), producing something that already looks finished with Nib's design tokens.
- Nobody should ever need to override more than 1–2 properties to get a materially different but still "simple" look (e.g., changing variant or size).
- Advanced behavior (custom decoration, custom builders, fine-grained animation control, slot overrides) is available through additional named parameters that are **all optional with sensible defaults** — never force a consumer down a path where changing one thing requires supplying five unrelated parameters just to keep existing behavior.
- Concretely: audit each component against Flutter's own equivalent (e.g., `ElevatedButton` requiring a full `ButtonStyle` override chain to get something simple-looking) and make sure Nib's version does not repeat that failure mode.

### 1.3 Stateful by default
- Every component that can have internal state (loading, expanded/collapsed, open/closed, hovered, pressed, selected, error) **must manage that state internally** as a `StatefulWidget`, exposing simple boolean/enum parameters (e.g., `loading: bool`, `disabled: bool`, `expanded: bool?` for optional external control) rather than requiring the consumer to wrap it in their own `StatefulBuilder` or manage a controller for basic use.
- Container-like or overlay-like components (Dialog, Modal, Bottom Sheet, Popover) must not force their children into a stateless context — if a consumer puts a button with a loading state inside a Nib dialog, that button must be able to manage and rebuild its own state without the outer dialog needing special plumbing. This means Nib's dialog/modal/sheet/popover internals must not rebuild their entire subtree unnecessarily and must not swallow `setState` calls from descendants.
- For components that benefit from both simple (internal-only) and advanced (externally observable/controllable) state, provide an **optional controller** (e.g., `NibAccordionController`, `NibCarouselController`) that is never required for basic use but is available when the consumer needs to drive state programmatically.
- Standard internal-state property pattern to use consistently across all components (see Section 4 for the full code skeleton):
  - `loading: bool = false` → shows a built-in loading representation (spinner slot, skeleton overlay, or shimmer depending on component type) and auto-disables interaction while true.
  - `disabled: bool = false`
  - `error: String?` / `errorText: String?` where applicable → switches the component into its built-in error visual state without the consumer building a separate error UI.

### 1.4 NibMotion integration contract
- Every component accepts an `animated: bool = false` parameter. **Animation is opt-in, off by default**, matching the current lean-simple-by-default philosophy.
- When `animated: true`, the component should accept an `animation` parameter (name/preset — e.g., `NibAnimationPreset` enum or a raw `NibAnim`/`NibTransition` value from the NibMotion API) that lets the consumer pick or fully customize the transition. If `animated: true` is set with no explicit `animation` value, fall back to a sensible default preset appropriate to that component (e.g., Dialog defaults to fade+scale, Toast defaults to slide+fade, Accordion defaults to height/opacity).
- Do not hardcode `AnimatedContainer`/`AnimatedOpacity`/implicit animation widgets for this — route through NibMotion's `MotionValue` → `RenderNibMotion.markNeedsPaint()` path per the existing architecture mandate, so animation never triggers `setState` on the host widget tree.
- Components must render and function correctly with `animated: false` with zero NibMotion overhead (no wasted controllers, no wasted `MotionValue` allocations) — animation must be fully lazy/opt-in at the object level, not just visually suppressed.

### 1.5 Output contract (per component)
Every component ships with, at minimum:
- `<component>.dart` — the widget implementation
- `meta.dart` / `meta.json` — registry metadata (per existing Nib registry format)
- Preview file(s) wired into the existing preview app
- At least 3 usage examples: (1) minimal/default usage, (2) a "common variant" usage, (3) an advanced/fully-customized usage exercising loading/error/animation

### 1.6 Testing & evidence requirement (standing convention — do not skip)
Per our existing convention: no component is marked done without concrete evidence, not a claim that it works. For each component, before moving to the next:
- Widget tests covering: default render, each variant, `loading` state, `disabled` state, keyboard interaction where applicable, and `animated: true` vs `animated: false` behavior.
- A short written note of what was actually tested and the output (test run results), not just "tests added."
- If the component touches overlay/positioning logic (Dialog, Popover, Select, Command Palette, Context Menu, Hover Card, Bottom Sheet), a manual verification note describing what was checked on-device/in the preview app (e.g., "verified it clamps to screen bounds when triggered near the right edge").

---

## 2. Design Token & Theming Rules

- All components read from the existing Nib `Theme.of(context)` extension — no hardcoded hex values in any component file.
- Border radius, spacing, and typography tokens from the existing design system (from prior sessions: radius `8` default / `4` sm / `12` lg / `9999` pill; Inter for labels, JetBrains Mono for code) must be used, not re-derived per component.
- Every component must work correctly in both light and dark mode without additional consumer configuration.

---

## 3. Build Order — Hardest to Simplest

Work strictly in this order. Do not skip ahead.

### Tier A — Hardest (build first)
1. **Data Table**
2. **Navigation Menu**
3. **Resizable Panels**
4. **Command Palette**
5. **Combobox**
6. **Date Picker / Calendar**
7. **Select / Dropdown**
8. **Dialog / Modal**
9. **Bottom Sheet**
10. **Popover**
11. **Context Menu**
12. **Hover Card**

### Tier B — Standard
13. **Carousel**
14. **OTP Input**
15. **Accordion**
16. **Tabs**
17. **Toast**
18. **Button**
19. **Slider**
20. **Pagination**
21. **Breadcrumb**
22. **Textarea**
23. **Input**
24. **Radio Group**
25. **Checkbox**
26. **Switch**
27. **Toggle Group**
28. **Card**
29. **Alert**
30. **Label**

### Tier C — Simplest (build last)
31. **Skeleton**
32. **Progress — Circular**
33. **Progress — Linear**
34. **Avatar**
35. **Toggle**
36. **Badge**
37. **Separator**

---

## 4. Stateful Component Pattern (apply this shape to every component)

```dart
class NibButton extends StatefulWidget {
  const NibButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = NibButtonVariant.primary,
    this.size = NibButtonSize.medium,
    this.loading = false,
    this.disabled = false,
    this.leadingIcon,
    this.trailingIcon,
    this.tooltip,
    this.semanticLabel,
    this.animated = false,
    this.animation,
    this.loadingWidget, // optional override for the built-in spinner
  });

  final String label;
  final VoidCallback? onPressed;
  final NibButtonVariant variant;
  final NibButtonSize size;
  final bool loading;
  final bool disabled;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final String? tooltip;
  final String? semanticLabel;
  final bool animated;
  final NibAnimationPreset? animation;
  final Widget? loadingWidget;

  @override
  State<NibButton> createState() => _NibButtonState();
}

class _NibButtonState extends State<NibButton> {
  // Internal state (press/hover/focus visual states) lives here.
  // The `loading` and `disabled` flags are driven externally but their
  // *visual and interaction consequences* (disabling tap, swapping in
  // the spinner slot, announcing state changes to Semantics) are fully
  // handled internally — the consumer never manages this by hand.
  ...
}
```

Every component follows this shape: **the widget's public constructor exposes plain, simple properties; the private `State` class is where all internal bookkeeping happens.** Consumers should almost never need `StatefulBuilder`, a manual `AnimationController`, or a manual `FocusNode` to use any Nib component in its default form.

---

## 5. Tier A — Detailed Specifications (hardest components; build these first, to this level of detail)

### 5.1 Data Table
**Why it's hardest:** requires custom layout (fixed/flexible column sizing), virtualization for large datasets, multi-directional interaction (sort, select, resize), and must stay performant with hundreds/thousands of rows.
- Required features: column definitions with typed cell renderers, sortable columns (tap header to cycle asc/desc/none), row selection (single + multi with checkbox column), sticky header on vertical scroll, optional sticky first column on horizontal scroll, empty-state slot, loading-state (skeleton rows, not a spinner overlay), pagination hook (works with the Nib Pagination component but not required), row click callback.
- Key parameters: `columns: List<NibDataColumn>`, `rows: List<NibDataRow>` (or a builder-based variant for large/async datasets), `sortable: bool`, `onSort`, `selectable: NibDataTableSelectionMode` (none/single/multi), `onSelectionChanged`, `loading: bool`, `emptyState: Widget?`, `rowHeight`, `stickyHeader: bool`.
- Must virtualize rows (use `ListView.builder`/`SliverList` under the hood) — never build all rows eagerly.
- Stateful: sort state, selection state, and column-width state (if resizable columns are enabled) are managed internally with escape hatches via optional controller.

### 5.2 Navigation Menu
**Why it's hard:** multi-level menus, keyboard traversal, responsive collapse behavior, overlay/anchor positioning for submenus.
- Required features: top-level items with optional nested submenus (flyout or inline depending on orientation), keyboard arrow-key navigation between siblings and into/out of submenus, active/selected item indicator, horizontal and vertical orientation support, responsive collapse into an overflow/"more" menu when horizontal space runs out.
- Key parameters: `items: List<NibNavItem>`, `orientation`, `activeItemId`, `onItemSelected`, `overflowBehavior`.
- Submenus must use an anchored overlay (see Popover's positioning logic — share the underlying anchoring primitive rather than reimplementing it).

### 5.3 Resizable Panels
**Why it's hard:** genuinely has no Flutter equivalent; requires a custom `RenderObject`/`MultiChildLayoutDelegate` to manage flexible panel sizing with drag handles, min/max constraints per panel, and persisted size ratios.
- Required features: horizontal and vertical panel groups, drag handle between panels (with hover/active affordance), min size and max size per panel, double-click/tap handle to reset to default split, optional persisted layout (via the existing `window.storage`-style pattern if this ships inside an artifact context, otherwise a simple `ValueChanged<List<double>>` callback for the host app to persist).
- Key parameters: `direction: Axis`, `panels: List<NibResizablePanel>` (each with `minSize`, `maxSize`, `initialSize`), `onLayoutChanged`.
- This is the component most likely to need genuine custom `RenderObject` work rather than composition — do not fake it with nested `Expanded`/`Flexible` and a manually-dragged `SizedBox`, since that won't correctly enforce per-panel min/max during a drag that affects multiple panels at once.

### 5.4 Command Palette
**Why it's hard:** global keyboard shortcut capture, focus trapping, fuzzy search/filtering, and must not conflict with the host app's own shortcuts.
- Required features: global open shortcut (configurable, sensible platform-aware default — `Cmd+K` on macOS/web-on-mac, `Ctrl+K` elsewhere), fuzzy/substring filtering of a flat or grouped action list, keyboard up/down/enter navigation, nested/sub-action support (selecting an action can reveal a further list, e.g., "Change theme" → "Light/Dark"), escape to close, optional recent/frequently-used section.
- Key parameters: `actions: List<NibCommandAction>`, `openShortcut`, `filter` (overridable filter function), `placeholder`, `onActionSelected`.
- Must work without a physical keyboard too (programmatic open via a trigger button/icon), matching the accessibility requirement in Section 1.1.

### 5.5 Combobox
**Why it's hard:** combines a text field, filtered dropdown list, and keyboard navigation, with both sync and async data source support.
- Required features: type-to-filter, keyboard navigation of filtered results, free-text entry vs. selection-only modes, multi-select variant (chips inside the field), async/debounced data source support (loading state inside the dropdown, not a separate spinner), "no results" slot, clear button.
- Key parameters: `options` or `asyncOptionsLoader`, `multiSelect: bool`, `allowFreeText: bool`, `debounceDuration`, `onSelectionChanged`, `loading` (for async), `noResultsBuilder`.
- Stateful: query text, filtered results, open/closed state, and selection are all managed internally; expose an optional controller for external reads.

### 5.6 Date Picker / Calendar
**Why it's hard:** calendar date math, range selection, and localization all need to be correct, not just visually styled.
- Required features: single date, date range, and multi-date selection modes; month/year quick navigation (not just arrow-by-arrow); min/max selectable date bounds; disabled-dates predicate; locale-aware month/weekday labels and first-day-of-week; optional inline calendar vs. popover-triggered calendar.
- Key parameters: `mode: NibDatePickerMode`, `selectedDate`/`selectedRange`, `minDate`, `maxDate`, `disabledDayPredicate`, `locale`, `displayMode: NibDatePickerDisplayMode` (inline/popover/dialog).
- Reuse Popover's anchoring logic for the popover display mode rather than reimplementing overlay positioning again.

### 5.7 Select / Dropdown
**Why it's hard:** overlay positioning that correctly flips/clamps to screen bounds (this was an explicit past bug we already had to fix once in a different dropdown — do not regress it here), plus keyboard support and optional search.
- Required features: single-select and multi-select variants, optional in-list search/filter for long option lists, keyboard navigation, correct overlay positioning that flips above the trigger and clamps to all four screen edges when there isn't room below, grouped options (section headers), disabled individual options.
- Key parameters: `options`, `multiSelect`, `searchable`, `onChanged`, `placeholder`, `disabled`.
- This is the component our earlier research flagged as one of Flutter's most-hated defaults — treat the visual polish bar here as high priority, not just functional parity.

### 5.8 Dialog / Modal
**Why it's hard:** focus trapping, stacking multiple dialogs correctly, barrier/backdrop behavior, and must not break `setState` for stateful children (per Section 1.3).
- Required features: barrier dismiss toggle, focus trap (Tab cycles within the dialog only), stacked-dialog support (opening a dialog from within a dialog works correctly), scrollable content area when content overflows, standard header/body/footer slot structure with sensible defaults, size presets (`sm`/`md`/`lg`/`fullscreen`) plus a custom-size escape hatch.
- Key parameters: `barrierDismissible`, `size`, `header`, `footer`, `content`, `onClose`, `animated`, `animation`.

### 5.9 Bottom Sheet
**Why it's hard:** drag-to-dismiss physics with velocity-based snapping, multiple snap points, and correct interaction with the barrier.
- Required features: drag handle, drag-to-dismiss with velocity threshold (fast flick dismisses even if not fully dragged down), multiple snap points (e.g., peek/half/full) with drag-to-snap between them, rounded top corners token-driven, barrier dismiss toggle.
- Key parameters: `snapPoints: List<double>`, `initialSnap`, `onSnapChanged`, `dismissible`, `content`.

### 5.10 Popover
**Why it's hard:** general-purpose anchored positioning with collision/flip detection — this is a shared primitive other components (Select, Date Picker, Navigation Menu submenus) should build on, so get the anchoring logic right once, here.
- Required features: anchor to any trigger widget, auto-flip placement (top/bottom/left/right) when the preferred side doesn't fit, clamp to screen bounds, optional arrow/pointer graphic pointing at the trigger, dismiss on outside tap or explicit close only.
- Key parameters: `trigger`, `content`, `placement: NibPopoverPlacement`, `dismissOnOutsideTap`, `showArrow`.
- **Build this before Select/Date Picker/Navigation Menu conceptually rely on it** — even though it's numbered after them in the strict build order, flag to the consumer whether extracting the anchoring logic into a shared internal utility earlier makes sense so the later Tier A components don't duplicate positioning code. If so, note that as a deviation from strict order with a one-line justification, rather than silently reordering.

### 5.11 Context Menu
**Why it's hard:** must support both right-click (desktop/web) and long-press (touch) triggers, with correct positioning at the cursor/touch point rather than anchored to a widget's bounds.
- Required features: right-click trigger on desktop/web, long-press trigger on touch, positioning at the exact pointer location with screen-bounds clamping, nested submenus, keyboard navigation once open, dividers/section grouping.
- Key parameters: `items`, `child` (the widget that triggers the menu), `onItemSelected`.

### 5.12 Hover Card
**Why it's hard (relatively, within this tier):** desktop-only hover detection with correct show/hide delay tuning so it doesn't flicker, and must degrade gracefully (tap-to-show) on touch platforms where hover doesn't exist.
- Required features: configurable show/hide delay, follows Popover's anchoring/flip logic, graceful touch-platform fallback (tap to show, tap outside to dismiss), doesn't steal focus from the underlying trigger.
- Key parameters: `trigger`, `content`, `showDelay`, `hideDelay`, `placement`.

---

## 6. Tier B — Standard Components (specification table)

Build these to the same architecture standard as Tier A (Section 1), using the table below for required features and key parameters. Full prose specs are not repeated per-component here since these have clearer Material precedent — apply the same rigor Section 5 modeled.

| # | Component | Non-obvious/critical requirement | Key parameters (beyond label/value/onChange) |
|---|---|---|---|
| 13 | Carousel | Dots indicator, auto-scroll with pause-on-interaction, "peek" of adjacent cards, loop mode | `autoPlay`, `autoPlayInterval`, `loop`, `peekExtent`, `indicatorStyle` |
| 14 | OTP Input | Paste support (splits a pasted code across all fields), auto-advance focus per digit, SMS autofill hook on supported platforms | `length`, `obscureText`, `onCompleted`, `autoFocus` |
| 15 | Accordion | **Must support single-open coordination between sibling items** (this is a documented Flutter gap — `ExpansionTile` has no built-in way to do this) | `allowMultipleOpen: bool = false`, `defaultOpenIndex` |
| 16 | Tabs | Scrollable tab bar when tabs overflow, indicator that animates position/width smoothly | `scrollable`, `indicatorStyle` |
| 17 | Toast | **ID-based de-duplication** — triggering a toast with an ID that's already showing shakes/pulses the existing one instead of stacking a duplicate | `id`, `onDuplicateTrigger: NibToastDuplicateBehavior` (shake/ignore/replace), `duration`, `position` |
| 18 | Button | Full spec already given in Section 4 — treat as the reference implementation other components' `loading`/`disabled` patterns follow | see Section 4 |
| 19 | Slider | Optional range mode (two thumbs), tick marks, value label on drag | `range`, `divisions`, `showValueLabel` |
| 20 | Pagination | Sensible ellipsis collapsing for large page counts | `totalPages`, `currentPage`, `siblingCount` |
| 21 | Breadcrumb | Auto-collapse middle items into an ellipsis/overflow menu when the trail is long | `items`, `maxVisibleItems` |
| 22 | Textarea | Auto-grow height with min/max line bounds, character counter | `minLines`, `maxLines`, `maxLength`, `showCounter` |
| 23 | Input | Built-in error/helper text slots, leading/trailing icon slots, clear button | `errorText`, `helperText`, `prefixIcon`, `suffixIcon`, `clearable` |
| 24 | Radio Group | Keyboard arrow-key navigation between options | `options`, `value`, `onChanged` |
| 25 | Checkbox | Indeterminate state support | `value: bool?` (tri-state) |
| 26 | Switch | — | `value`, `onChanged`, `loading` (for async-confirmed toggles) |
| 27 | Toggle Group | Single vs multi-select mode | `multiSelect` |
| 28 | Card | Optional interactive/pressable variant with proper feedback | `interactive: bool`, `onTap` |
| 29 | Alert | Dismissible variant, severity-driven default icon/color | `severity`, `dismissible`, `onDismiss` |
| 30 | Label | Required-field indicator, association with form control for accessibility | `required`, `htmlFor`-equivalent semantics link |

---

## 7. Tier C — Simple Components (specification table)

| # | Component | Notes |
|---|---|---|
| 31 | Skeleton | Shimmer animation should route through the NibMotion `animated` contract like everything else (default off → static pulse-free placeholder; on → shimmer sweep) |
| 32 | Progress — Circular | Determinate and indeterminate modes |
| 33 | Progress — Linear | Determinate and indeterminate modes, buffer-progress variant |
| 34 | Avatar | Network image with graceful fallback to initials, and a further fallback to a default icon if no name is available |
| 35 | Toggle | Icon-only pressable toggle (distinct from Switch — this is the single boolean icon-button style toggle) |
| 36 | Badge | Dot and labeled variants, overflow formatting for counts (e.g., `99+`) |
| 37 | Separator | Horizontal/vertical, optional inline label |

---

## 8. Workflow Instructions for Claude Code

1. Work top-to-bottom through Section 3's order. One component per work session.
2. For each component: read its spec (Section 5, 6, or 7), implement per Section 1's architecture rules, write tests per Section 1.6, produce the output contract per Section 1.5.
3. Do not mark a component done and move to the next until Section 1.6's evidence requirement is satisfied. Report back with the actual test output and, for overlay/positioning components, the manual verification note.
4. Maintain a running checklist at the top of your own working notes (e.g., a `NIB_COMPONENTS_PROGRESS.md`) tracking: component name, status (not started / in progress / built / tested / verified), and date, so a future Claude Code session can pick up mid-list without losing context — this matches the tracking pattern used on the NibMotion build.
5. If you find, while building a Tier A component, that extracting a shared primitive earlier (e.g., the anchoring/positioning logic behind Popover, Select, Date Picker, Navigation Menu, Context Menu, and Hover Card) meaningfully reduces duplicate work, flag that as a proposed one-time reorder with a one-line justification rather than silently changing the plan.
