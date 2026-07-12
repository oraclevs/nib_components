import 'package:flutter/widgets.dart';

/// Which selection behavior a [NibDatePicker] uses.
enum NibDatePickerMode {
  /// One date at a time; tapping a day replaces the selection.
  single,

  /// A contiguous start–end range picked with two taps.
  range,

  /// Any set of individual days, toggled on/off.
  multi,
}

/// How a [NibDatePicker] surfaces its calendar.
enum NibDatePickerDisplayMode {
  /// Renders the calendar directly in the layout.
  inline,

  /// A trigger field opens the calendar in an overlay anchored to it.
  popover,

  /// A trigger field opens the calendar centered in a dialog with a barrier.
  dialog,
}

/// A day is disabled (not selectable) when this returns `true` for it.
typedef NibDisabledDayPredicate = bool Function(DateTime day);

/// The shape of a day cell's selected/highlighted background.
enum NibDateCellShape {
  /// A circle (the default).
  circle,

  /// A rounded square (uses the theme's small radius).
  rounded,

  /// A hard square with no corner radius.
  square,

  /// A fully-rounded pill.
  pill,
}

/// The full visual state of a single day cell, handed to a
/// [NibCalendarDayBuilder] so a consumer can render any cell they like.
@immutable
class NibCalendarDayState {
  const NibCalendarDayState({
    required this.date,
    required this.selected,
    required this.inRange,
    required this.isRangeStart,
    required this.isRangeEnd,
    required this.today,
    required this.outOfMonth,
    required this.disabled,
  });

  /// The day this cell represents.
  final DateTime date;

  /// Whether this exact day is selected (single, multi, or a range endpoint).
  final bool selected;

  /// Whether this day falls strictly between a range's two ends.
  final bool inRange;

  final bool isRangeStart;
  final bool isRangeEnd;

  /// Whether this day is today.
  final bool today;

  /// Whether this day belongs to an adjacent month (grid spill).
  final bool outOfMonth;

  /// Whether this day is non-selectable (min/max bounds or the predicate).
  final bool disabled;
}

/// Builds a fully custom day cell. Return just the cell's *content* — the
/// calendar still wraps it in the tap target and enforces the 44px cell size.
typedef NibCalendarDayBuilder = Widget Function(BuildContext context, NibCalendarDayState state);

/// An inclusive date range. [end] is `null` while a range is mid-selection
/// (only the start has been picked).
@immutable
class NibDateRange {
  const NibDateRange({required this.start, this.end});

  final DateTime start;
  final DateTime? end;

  /// Whether both ends have been picked.
  bool get isComplete => end != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NibDateRange &&
          _sameDay(other.start, start) &&
          _sameNullableDay(other.end, end);

  @override
  int get hashCode => Object.hash(
    start.year,
    start.month,
    start.day,
    end?.year,
    end?.month,
    end?.day,
  );

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _sameNullableDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == null && b == null;
    return _sameDay(a, b);
  }
}
