# NIB_COMPONENTS_PROGRESS.md

Tracks build status for every component in `NIB_COMPONENTS_MASTER_PROMPT.md`
section 3. Status values: `not started` / `in progress` / `built` / `tested`
/ `verified` (visually confirmed by user in `example/`).

Setup infra (git repo, `nib_motion` wiring, `example/` demo app with
Linux+web platforms) completed 2026-07-10.

## Known gaps (deferred, not silently dropped)

| Component | Gap | Notes |
|---|---|---|
| Data Table | No screen-reader grid semantics or arrow-key row traversal | Master prompt section 1.1 baseline not yet met. Basic keyboard activation (Tab + Enter/Space on headers/rows/checkboxes) works via native `InkWell`/`Checkbox`; missing: table/row/cell `Semantics` roles and arrow-key grid navigation. Close before calling Data Table fully done against 1.1, or accept as a tracked follow-up. |
| Data Table | Pagination hook not wired | Pagination (#20) doesn't exist yet; `rows: List<T>` is already page-slice-friendly for when it lands. |
| Data Table | No sticky first column while horizontally scrolled | Plain horizontal scroll (Task 9) covers the actual "doesn't fit on a phone" case; pinning a column during that scroll is deferred, comparable in complexity to Resizable Panels (#3). |

## Tier A — Hardest

| # | Component | Status | Date |
|---|---|---|---|
| 1 | Data Table | built — awaiting visual confirm | 2026-07-10 |
| 2 | Navigation Menu | not started | |
| 3 | Resizable Panels | not started | |
| 4 | Command Palette | not started | |
| 5 | Combobox | not started | |
| 6 | Date Picker / Calendar | not started | |
| 7 | Select / Dropdown | not started | |
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
