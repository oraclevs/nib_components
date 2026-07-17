# NibBreadcrumb — design & build plan (2026-07-17)

Component #21 (Tier B). Spec: `NIB_COMPONENTS_MASTER_PROMPT.md` §6 row 21
(auto-collapse middle items into an ellipsis/overflow menu when the trail is
long; params `items`, `maxVisibleItems`) + §1 rules. User-approved brainstorm
(2026-07-17):

1. **Count + width-adaptive collapse** — collapse when `items.length >
   maxVisibleItems` **or** when the full trail can't fit the available width
   (`LayoutBuilder`). Two levels: full, or `first › … › last`.
2. **Reuse `NibPopover`** for the overflow — the `…` is a popover trigger; its
   content is a menu of the hidden crumbs.
3. **Staggered crumb reveal** on `animated:true` (each crumb slides+fades in,
   ~40ms apart). `animated:false` builds **zero** `NibMotion`.

## Public API

```dart
NibBreadcrumb({
  required List<NibBreadcrumbItem> items, // last = current page (not a link)
  int? maxVisibleItems,                   // collapse when exceeded (null = width-only)
  int itemsBeforeCollapse = 1,            // leading crumbs kept when collapsed
  int itemsAfterCollapse = 1,             // trailing crumbs kept when collapsed
  Widget? separator,                      // default chevron ›
  bool disabled = false,
  NibPopoverPlacement overflowPlacement = NibPopoverPlacement.bottom,
  // customization (memory: component-customization-mandate)
  Color? linkColor, currentColor, separatorColor,
  double? fontSize,                       // default 14
  EdgeInsetsGeometry? itemPadding, double? gap,
  // motion
  bool animated = false,
  NibTransition? transition,
  // a11y
  String? semanticLabel,                  // default 'Breadcrumb'
})
```

### Types (`nib_breadcrumb_types.dart`)
- `NibBreadcrumbItem { String label; Widget? icon; VoidCallback? onTap; }` —
  immutable. A non-last item with a non-null `onTap` renders as a focusable link.
- `List<int?> breadcrumbVisibleIndices({required int count, required bool collapsed,
  int before = 1, int after = 1})` — pure, unit-tested; `null` marks the ellipsis.
  `[0, null, 4]` for count 5 collapsed; `[0,1,2,3,4]` when not. Only collapses when
  `count > before + after`.

## Architecture (§1.1)

- `LayoutBuilder` gives the available width. A `TextPainter` pass measures each
  crumb's intrinsic label width (+ a fixed icon/separator slot estimate) to sum the
  **full** trail width. `collapsed = (maxVisibleItems != null && count >
  maxVisibleItems) || fullWidth > availableWidth` (and `count > before + after`).
- Visible entries via `breadcrumbVisibleIndices`; rendered as a `Row` interleaved
  with the separator:
  - **Link crumb** (non-last, `onTap != null`): a private `_CrumbLink` built on
    `FocusableActionDetector` (native focus + `ActivateIntent` on Enter/Space +
    click cursor + hover/focus underline), wrapped in `Semantics(link: true)`.
  - **Current crumb** (last): plain emphasised `Text` (foreground, w600), wrapped
    in `Flexible(… overflow: ellipsis)` so an extremely narrow viewport ellipsizes
    the current label instead of overflowing.
  - **Plain crumb** (non-last, no `onTap`): muted `Text`.
  - **Ellipsis**: a `NibPopover(trigger: '…', content: hidden-crumb menu,
    placement: overflowPlacement)`. Each menu tile taps the hidden item's `onTap`
    then closes via `NibPopoverScope.of(context).close()`.
- Never overflows: collapse + the `Flexible` current crumb guarantee it (§1.7).

## State (§1.3)

Stateless data in / callbacks out (`item.onTap`) — a `StatefulWidget` only to hold
nothing beyond what `_CrumbLink`/`NibPopover` manage themselves. No controller.

## Motion (§1.4)

`animated:true` wraps each visible crumb in
`NibMotion(initial: NibAnim(x:-8, opacity:0), animate: identity,
transition: NibTransition(delay: index*40ms))`, keyed by the crumb index so it
replays on a trail change (staggered slide+fade). The overflow `NibPopover` gets
the same `animated`. `animated:false` builds **zero** `NibMotion` (crumbs plain;
closed popover builds none). Verified with a short (non-overflowing) trail.

## Tokens (§2)

links = `mutedForeground` → `foreground` + underline on hover/focus; current =
`foreground` w600; separator/ellipsis = `mutedForeground`; overflow menu panel =
`card` with `border`. Disabled dims 0.5. `fontSize` 14.

## Tests (§1.6)

`test/breadcrumb/nib_breadcrumb_test.dart`: `breadcrumbVisibleIndices` cases ·
renders labels + (count-1) separators · last crumb is current (tapping it does not
fire a link) · tapping a link fires its `onTap` · `maxVisibleItems` collapse shows
`…` and hides middle labels · tapping `…` opens the popover listing hidden crumbs;
tapping one fires its `onTap` · narrow width collapses (no overflow exception) ·
`animated:true` builds `NibMotion` / `false` → `findsNothing`.

## Output contract (§1.5)

`example/lib/examples/breadcrumb_examples.dart`: (1) minimal 3-crumb · (2) long
trail collapsing to an overflow menu (animated) · (3) custom separator + icons ·
registered in `catalog.dart` after the Pagination entries.

## Deferred → Known gaps

- Multi-level greedy collapse (showing *as many* trailing crumbs as fit, between
  full and `first › … › last`) — two-level collapse matches the approved preview;
  greedy in-between is a nicety.
- Icon/separator width in the fit math is a fixed-slot estimate, not a real measure
  of an arbitrary icon widget — fine for the fit decision (labels dominate).
