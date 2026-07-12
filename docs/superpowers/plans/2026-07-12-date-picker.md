# Date Picker / Calendar (#6) — implementation plan

Component #6 (MASTER_PROMPT §3, spec §5.6). A calendar with single / range /
multi-date selection, month+year quick navigation (not arrow-by-arrow only),
min/max bounds, a disabled-day predicate, locale-aware labels + first-day-of-week,
and three display modes: inline, popover-anchored, and centered dialog.

## Why it's hard (spec)

Calendar date math (month grids, leading/trailing days, DST-safe stepping), range
selection, and localization all have to be *correct*, not just styled. Reference
bar: Flutter's own `CalendarDatePicker` internals.

## Architecture decisions

- **One public widget, `NibDatePicker`, + `NibDatePickerController` + types.** The
  calendar grid is a private `_CalendarView`; `displayMode: inline` renders it
  directly, `popover`/`dialog` render a trigger field that opens it in an overlay.
  No separate public `NibCalendar` — `NibDatePicker(displayMode: inline)` *is* the
  bare calendar.

- **Pure date math in `nib_calendar_math.dart` (unexported), TDD'd hard.** Date
  math is the bug-prone part, so it's isolated and covered by unit tests before any
  widget exists: `isSameDay`, `dateOnly`, `firstOfMonth`, `addMonths` (day-clamped),
  `daysInMonth`, `calendarDays` (42-cell 6-week grid honoring `firstDayOfWeekIndex`,
  built via `DateTime(y,m,day+i)` so it's DST-safe), `isInRange`, `isDayDisabled`
  (min/max/predicate), `nextRange` (range-selection reducer), `toggleDate` (multi).

- **Localization via `MaterialLocalizations`, zero new deps** (Rule 7). Weekday
  headers from `narrowWeekdays` reordered by `firstDayOfWeekIndex`; header label
  from `formatMonthYear`; trigger text from `formatMediumDate`. The `locale`
  param wraps the calendar subtree in `Localizations.override(locale:)`, so names
  and first-day-of-week resolve for that locale using whatever the host app
  registered — standard Flutter degradation, no `intl` dependency added.

- **Quick month/year navigation.** `_CalendarView` has a `pickerMode`
  (`days`/`months`/`years`). Tapping the header enters `years` (a 12-year grid with
  ‹›  paging); picking a year → `months` (12 localized `formatMonthYear` rows with
  ‹› year stepping); picking a month → back to `days`. Covers "not just
  arrow-by-arrow" while keeping every label localized.

- **Selection reducers routed through the pure math + the controller.** Single: tap
  replaces. Range: `nextRange` (1st tap = start, 2nd = end with auto-swap if before
  start, 3rd = restart), fires on every change (consumer checks `isComplete`).
  Multi: `toggleDate`. Disabled days (min/max/predicate) are inert.

- **Overlays reuse existing primitives.** Popover uses `NibAnchoredOverlay.show`
  (the shared flip/clamp anchoring primitive the spec says to reuse for the popover
  mode), with its content wrapped in `AnimatedBuilder(animation: controller)` so it
  rebuilds live as the selection changes. Dialog uses an own centered `OverlayEntry`
  + opaque barrier (same shape as `NibCommandPalette`). Both driven by a
  `controller.isOpen` listener; `closeOnSelect` closes single-mode (and completed
  ranges) after a pick.

- **Optional-controller pattern** (`_bindController`/`_unbindController`/
  `_ownsController`) identical to `NibComboboxController`; controller holds
  `selectedDate` / `selectedRange` / `selectedDates`, `isOpen`, `displayedMonth`.

- **Animation (§1.4):** `animated: false` → zero `NibMotion`; `true` → the calendar
  card gets a `NibMotion` fade+scale, `transition` overridable.

- **Responsive (§1.7):** day cells are fixed 44px in a 7-col grid; the popover/
  dialog card is width-capped and the whole thing fits a phone width. Inline sizes
  to its parent.

## API surface

```dart
enum NibDatePickerMode { single, range, multi }
enum NibDatePickerDisplayMode { inline, popover, dialog }
typedef NibDisabledDayPredicate = bool Function(DateTime day);

class NibDateRange { final DateTime start; final DateTime? end; bool get isComplete; }

NibDatePicker({
  NibDatePickerMode mode = NibDatePickerMode.single,
  NibDatePickerDisplayMode displayMode = NibDatePickerDisplayMode.inline,
  DateTime? selectedDate, NibDateRange? selectedRange, List<DateTime>? selectedDates,
  DateTime? initialMonth,
  DateTime? minDate, DateTime? maxDate,
  NibDisabledDayPredicate? disabledDayPredicate,
  Locale? locale,
  ValueChanged<DateTime?>? onDateChanged,
  ValueChanged<NibDateRange?>? onRangeChanged,
  ValueChanged<List<DateTime>>? onDatesChanged,
  String placeholder = 'Select date', bool disabled = false,
  bool closeOnSelect = true,
  bool animated = false, NibTransition? transition,
  NibDatePickerController? controller,
})
```

## Files

- `lib/src/date_picker/nib_date_picker_types.dart` — enums, `NibDateRange`, typedef.
- `lib/src/date_picker/nib_calendar_math.dart` — pure math (not exported).
- `lib/src/date_picker/nib_date_picker_controller.dart` — the controller.
- `lib/src/date_picker/nib_date_picker.dart` — widget + private `_CalendarView`.
- barrel: export types, controller, widget (not math).

## Tasks

1. Plan doc (this file).
2. Math + types + math tests (TDD).
3. Controller + controller tests.
4. `NibDatePicker` + `_CalendarView` (grid, nav, quick month/year, selection modes,
   min/max, disabled, locale, display modes, animated) + barrel.
5. Widget tests (inline render, single/range/multi select, disabled/min-max inert,
   month nav + quick year/month nav, popover open/close + select, dialog, animated
   on/off, narrow viewport).
6. Example demos (inline single, range popover, multi + min/max/disabled advanced) +
   catalog.
7. `flutter test` + `flutter analyze` + example analyze/build; report real output;
   mark row `built — awaiting visual confirm`.

## Evidence / DoD

Per §1.6: tests for default render, each selection mode, disabled/bounds, keyboard
where applicable, `animated` on/off, and (overlay component) a note on popover
flip/clamp left for the user's visual pass; narrow-viewport no-overflow test (§1.7).
Real `flutter test` + `flutter analyze` output before claiming done.
