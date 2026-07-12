# NIB_COMPONENTS_PROGRESS.md

Tracks build status for every component in `NIB_COMPONENTS_MASTER_PROMPT.md`
section 3. Status values: `not started` / `in progress` / `built` / `tested`
/ `verified` (visually confirmed by user in `example/`).

Setup infra (git repo, `nib_motion` wiring, `example/` demo app with
Linux+web platforms) completed 2026-07-10.

## Known gaps (deferred, not silently dropped)

| Component | Gap | Notes |
|---|---|---|
| Data Table | Screen-reader labels + tap targets fixed (2026-07-10); formal table/row/cell `SemanticsRole` still open | Arrow-key row traversal works for free (native focusable `InkWell`s + Flutter's default directional focus shortcuts — verified by test). Sortable headers now announce label+sort state, selected rows/checkboxes announce selected/checked, header height meets 48px minimum. Not done: Flutter exposes `SemanticsRole.table/row/cell/columnHeader` with debug-mode structural validation this SDK version supports — adopting it would give a screen reader a real "table" reading, but needs its own careful pass to satisfy that validation correctly. Low risk as deferred (current labels are a genuine improvement, not a stub). |
| Data Table | Pagination hook not wired | Pagination (#20) doesn't exist yet; `rows: List<T>` is already page-slice-friendly for when it lands. |
| Data Table | No sticky first column while horizontally scrolled | Plain horizontal scroll (Task 9) covers the actual "doesn't fit on a phone" case; pinning a column during that scroll is deferred, comparable in complexity to Resizable Panels (#3). |
| Navigation Menu | No hover-to-open for horizontal flyouts on desktop | Tap/click-only on every platform per the locked design spec — hover-intent timing (open/close delay tuning to avoid flicker) is explicitly Hover Card's (#12) problem space, not duplicated here. |
| Navigation Menu | No sticky/scroll-into-view for the active item in very long vertical menus | Purely a nice-to-have polish item, not required by any tested behavior; deferred rather than adding untested scroll-position logic. |
| Date Picker | Day-grid keyboard nav relies on Flutter's default directional focus traversal between focusable day `InkWell`s (Tab/arrows move focus, Enter/Space selects); no custom roving-tabindex or type-to-jump | Same approach Data Table took for row traversal. A bespoke arrow-key roving-focus handler (move ±1 day / ±7 for up-down, wrapping across month edges) would be a polish improvement but isn't required by any tested behavior. |
| Date Picker | Tapping an adjacent-month day (shown faded in the grid) selects that date but does not auto-advance the displayed month | Low-impact; the date is still correctly selected. Auto-switching the visible month on out-of-month taps is a follow-up nicety. |
| Select / Dropdown | No type-to-jump in the non-searchable trigger (typing a letter to jump to the next matching option) | Arrow-key nav + Enter/Space/Esc fully cover keyboard use (verified by test); `searchable: true` gives full typeahead. A bespoke printable-key type-ahead handler on the closed/open trigger is a polish nicety, same call Data Table/Date Picker made on roving-focus. |
| Select / Dropdown | Animated exit unmounts the overlay on a duration *estimate* (`transition.duration` + buffer, or ~450ms for springs), not a real per-animation completion callback | `NibPresence` plays the exit; the overlay's `OverlayEntry` is then removed by a timer sized to that estimate. Tween exits are exact; a very slow/custom spring could unmount slightly early. Wiring a true completion signal out of `NibPresence`/`NibMotionAnimator` would remove the estimate — deferred as a small refinement. |

## Tier A — Hardest

| # | Component | Status | Date |
|---|---|---|---|
| 1 | Data Table | verified | 2026-07-10 |
| 2 | Navigation Menu | verified | 2026-07-11 |
| 3 | Resizable Panels | verified | 2026-07-11 |
| 4 | Command Palette | verified | 2026-07-11 |
| 5 | Combobox | verified | 2026-07-11 |
| 6 | Date Picker / Calendar | verified | 2026-07-12 |
| 7 | Select / Dropdown | verified | 2026-07-12 |
| 8 | Dialog / Modal | not started | |
| 9 | Bottom Sheet | not started | |
| 10 | Popover | not started | |
| 11 | Context Menu | not started | |
| 12 | Hover Card | not started | |

## Tier B — Standard

| # | Component | Status | Date |
|---|---|---|---|
| 13 | Carousel | not started | |
| 14 | OTP Input | not started | |
| 15 | Accordion | not started | |
| 16 | Tabs | not started | |
| 17 | Toast | not started | |
| 18 | Button | not started | |
| 19 | Slider | not started | |
| 20 | Pagination | not started | |
| 21 | Breadcrumb | not started | |
| 22 | Textarea | not started | |
| 23 | Input | not started | |
| 24 | Radio Group | not started | |
| 25 | Checkbox | not started | |
| 26 | Switch | not started | |
| 27 | Toggle Group | not started | |
| 28 | Card | not started | |
| 29 | Alert | not started | |
| 30 | Label | not started | |

## Tier C — Simplest

| # | Component | Status | Date |
|---|---|---|---|
| 31 | Skeleton | not started | |
| 32 | Progress — Circular | not started | |
| 33 | Progress — Linear | not started | |
| 34 | Avatar | not started | |
| 35 | Toggle | not started | |
| 36 | Badge | not started | |
| 37 | Separator | not started | |
