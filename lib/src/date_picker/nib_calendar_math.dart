import 'nib_date_picker_types.dart';

/// Pure calendar/date helpers for `NibDatePicker`. No Flutter or localization
/// dependency — just date arithmetic, isolated here so it can be unit-tested
/// exhaustively (this is the bug-prone part of a date picker).

/// Whether [a] and [b] fall on the same calendar day, ignoring time.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Midnight of [d]'s day (strips any time component).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The first day of [d]'s month, at midnight.
DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

/// Number of days in the given [month] of [year] (1-based month).
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// [d] shifted by [n] whole months (negative to go back). The day-of-month is
/// clamped to the target month's length, so `addMonths(Jan 31, 1)` is Feb 28/29
/// rather than rolling into March.
DateTime addMonths(DateTime d, int n) {
  final zeroBased = d.year * 12 + (d.month - 1) + n;
  final year = zeroBased ~/ 12;
  final month = zeroBased % 12 + 1;
  final dim = daysInMonth(year, month);
  return DateTime(year, month, d.day > dim ? dim : d.day);
}

/// The 42 days (6 weeks × 7) of the calendar grid for [month], including the
/// trailing days of the previous month and leading days of the next month
/// needed to fill complete weeks.
///
/// [firstDayOfWeekIndex] is `MaterialLocalizations.firstDayOfWeekIndex`
/// (0 = Sunday … 6 = Saturday). Built by incrementing the day component so it
/// stays correct across month/year boundaries and DST transitions.
List<DateTime> calendarDays(DateTime month, int firstDayOfWeekIndex) {
  final first = firstOfMonth(month);
  // DateTime.weekday is Mon=1..Sun=7; map to Sun=0..Sat=6.
  final firstWeekdaySunZero = first.weekday % 7;
  final leading = (firstWeekdaySunZero - firstDayOfWeekIndex + 7) % 7;
  final start = DateTime(first.year, first.month, first.day - leading);
  return [
    for (var i = 0; i < 42; i++)
      DateTime(start.year, start.month, start.day + i),
  ];
}

/// Whether [day] lies within the inclusive span between [start] and [end]
/// (order-independent), comparing by calendar day only.
bool isInRange(DateTime day, DateTime start, DateTime end) {
  final d = dateOnly(day);
  final s = dateOnly(start);
  final e = dateOnly(end);
  final lo = s.isBefore(e) ? s : e;
  final hi = s.isBefore(e) ? e : s;
  return !d.isBefore(lo) && !d.isAfter(hi);
}

/// Whether [day] should be non-selectable given the optional [minDate]/
/// [maxDate] bounds (inclusive) and a [predicate].
bool isDayDisabled(
  DateTime day, {
  DateTime? minDate,
  DateTime? maxDate,
  NibDisabledDayPredicate? predicate,
}) {
  final d = dateOnly(day);
  if (minDate != null && d.isBefore(dateOnly(minDate))) return true;
  if (maxDate != null && d.isAfter(dateOnly(maxDate))) return true;
  if (predicate != null && predicate(d)) return true;
  return false;
}

/// The range-selection reducer: given the [current] range (or `null`) and a
/// newly-tapped [day], returns the next range.
///
/// - No range yet, or a complete range → start a fresh range (start only).
/// - Start picked, tapping a later day → completes the range.
/// - Start picked, tapping an earlier day → completes it with the two ends
///   swapped so `start <= end`.
NibDateRange nextRange(NibDateRange? current, DateTime day) {
  final d = dateOnly(day);
  if (current == null || current.isComplete) {
    return NibDateRange(start: d);
  }
  final s = dateOnly(current.start);
  if (d.isBefore(s)) return NibDateRange(start: d, end: s);
  return NibDateRange(start: s, end: d);
}

/// The multi-select reducer: toggles [day] in [dates] (adds if absent, removes
/// if present), returning a new ascending-sorted list.
List<DateTime> toggleDate(List<DateTime> dates, DateTime day) {
  final d = dateOnly(day);
  final without = [
    for (final x in dates)
      if (!isSameDay(x, d)) dateOnly(x),
  ];
  if (without.length == dates.length) without.add(d);
  without.sort((a, b) => a.compareTo(b));
  return without;
}
