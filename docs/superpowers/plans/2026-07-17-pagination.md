# NibPagination — design & build plan (2026-07-17)

Component #20 (Tier B). Spec: `NIB_COMPONENTS_MASTER_PROMPT.md` §6 row 20
(sensible ellipsis collapsing for large page counts; params `totalPages`,
`currentPage`, `siblingCount`) + §1 architecture rules. User-approved brainstorm
(2026-07-17):

1. **Reuse `NibButton`** for every page / prev / next / first / last cell — free
   focus, ripple, keyboard activation, ≥48 tap target and semantics from the
   tested widget; consistent with the design system.
2. **Two variants** — `NibPaginationVariant { numbered, compact }`. numbered =
   `‹ 1 … 4 [5] 6 … 10 ›`; compact = `‹ Prev · "Page 5 of 10" · Next ›`.
3. **Both** motions when `animated:true` — a sliding active-pill indicator that
   glides to the new page **and** a scale-pop on the newly-active number.
   `animated:false` builds **zero** `NibMotion`.

## Public API

```dart
NibPagination({
  required int currentPage,            // 1-based
  required int totalPages,
  required ValueChanged<int>? onPageChanged, // null ⇒ disabled
  NibPaginationVariant variant = NibPaginationVariant.numbered,
  int siblingCount = 1,                // pages either side of current
  int boundaryCount = 1,               // pages pinned at each end
  bool showPrevNext = true,
  bool showFirstLast = false,          // « … » jump-to-first/last (numbered)
  bool disabled = false,
  String Function(int current, int total)? compactLabelBuilder, // 'Page X of Y'
  // customization (memory: component-customization-mandate)
  double? itemSize,                    // cell square, default 44
  double? gap,                         // default 6
  Color? activeColor,                  // pill fill, default primary
  BorderRadius? itemBorderRadius,
  // motion
  bool animated = false,
  NibTransition? transition,
  // a11y
  String? semanticLabel,               // default 'Pagination'
})
```

### Types (`nib_pagination_types.dart`)
- `enum NibPaginationVariant { numbered, compact }`.
- `List<int?> paginationRange({required int currentPage, required int totalPages,
  int siblingCount = 1, int boundaryCount = 1})` — the MUI `usePagination`
  algorithm; `null` marks an ellipsis. Pure + unit-tested.

## Architecture (§1.1)

- **Cells are `NibButton`s** (`variant: ghost`, fixed `width==height==itemSize`,
  `padding: zero`). The active look is a separate **pill** behind the row, not the
  button's own fill, so it can glide:
  - Numbered layout is a `Stack`: `[activePill (Positioned), Row(cells)]`.
  - Slot order: `[first?, prev?, …range items…, next?, last?]`. Each slot is one
    `itemSize` square (ellipsis = an inert centred `…`, not a button).
  - `activePill` = an `itemSize` rounded rect in `activeColor`; its left =
    `activeSlotIndex * (itemSize + gap)`. The active number's `NibButton.content`
    uses `primaryForeground` so it reads on the pill.
- prev/next/first/last = icon-only ghost `NibButton`s, **disabled at the bounds**
  (`currentPage == 1` / `== totalPages`).
- **compact** variant: `Row[prev, Flexible(Center(Text(label))), next]`, label from
  `compactLabelBuilder` (default `'Page $current of $total'`). No pill/ellipsis.
- Keyboard: inherited from the `NibButton` cells (Tab traversal + Enter/Space
  activate). No bespoke arrow-key roving (same call Data Table / Date Picker made).
- `Semantics(container: true, label: semanticLabel)` around the whole control.

## State (§1.3)

Controlled via `currentPage`/`onPageChanged` (that pair *is* the state — same call
as Slider). No separate controller. Private `State` tracks only the previous page
(to detect a change → replay the pop) and focus.

## Motion (§1.4)

- Pill glide: the pill's `NibMotion(animate: NibAnim(x: targetLeft))` tweens `x`
  to the new active slot on `currentPage` change. `animated:false` → a plain
  `Positioned(left: targetLeft)` (instant, zero `NibMotion`).
- Active-page pop: the active number `NibButton` is wrapped in
  `NibMotion(key: ValueKey(currentPage), initial: scale .9 → animate identity)`,
  replaying on change (Button/Slider precedent). compact pops the label `Text`.
- `animated:false` builds **zero** `NibMotion` (page changes/taps still work).
  Verified `find.byType(NibMotion), findsNothing`.

## Responsive (§1.7)

Ellipsis already bounds the numbered row to a fixed max slot count. As a hard
fallback for very narrow viewports the numbered row is wrapped in a horizontal
`SingleChildScrollView` when its intrinsic width exceeds the available width
(`LayoutBuilder`), so it scrolls instead of overflowing (Data Table pattern).
compact is inherently narrow. Tested at a narrow width (no overflow exception).

## Tokens (§2)

Pill/active = `primary` (text `primaryForeground`); inactive numbers = ghost
`foreground`; ellipsis + compact label = `mutedForeground`; disabled dims to 0.5.
Cell radius = default radius. `itemSize` 44, `gap` 6 (pitch 50 ≥ 48 → button tap
targets don't overlap).

## Tests (§1.6)

`test/pagination/nib_pagination_test.dart`: `paginationRange` cases (total10 cur5 →
`[1,null,4,5,6,null,10]`; cur1 → `[1,2,3,4,5,null,10]`; total3 → `[1,2,3]`;
total7 cur4 → `[1,null,3,4,5,null,7]`) · numbered renders the right page buttons +
ellipsis · tapping a page fires `onPageChanged` · prev/next fire ±1 and are disabled
at bounds · `showFirstLast` jumps to 1 / total · compact shows the label + prev/next
· `animated:true` builds `NibMotion` / `false` → `findsNothing` · narrow width no
overflow.

## Output contract (§1.5)

`example/lib/examples/pagination_examples.dart`: (1) minimal numbered · (2) large
count + siblings + first/last + animated · (3) compact · registered in
`catalog.dart` after the Slider entries.

## Deferred → Known gaps

- Bespoke arrow-key roving between page cells (Tab + Enter already works via the
  `NibButton` cells) — same deferral precedent as Data Table / Date Picker.
- Page-size selector / "jump to page" input — out of scope for the numbered/compact
  spec; a Data-Table-pager concern if it ever needs one.
