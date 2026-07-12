import 'package:flutter/foundation.dart';

import 'nib_calendar_math.dart';
import 'nib_date_picker_types.dart';

/// Optional external controller for a [NibDatePicker]'s selection, open/closed
/// state, and which month the calendar is showing. Never required for basic
/// use — `NibDatePicker` creates and owns its own controller internally when
/// none is supplied, and disposes it on unmount/controller-swap.
///
/// Only the getter matching the picker's [NibDatePickerMode] is meaningful:
/// [selectedDate] for single, [selectedRange] for range, [selectedDates] for
/// multi.
class NibDatePickerController extends ChangeNotifier {
  NibDatePickerController({
    DateTime? selectedDate,
    NibDateRange? selectedRange,
    List<DateTime>? selectedDates,
    DateTime? displayedMonth,
  })  : _single = selectedDate == null ? null : dateOnly(selectedDate),
        _range = selectedRange,
        _multi = [for (final d in selectedDates ?? const <DateTime>[]) dateOnly(d)],
        _displayedMonth = firstOfMonth(
          displayedMonth ??
              selectedDate ??
              selectedRange?.start ??
              (selectedDates != null && selectedDates.isNotEmpty ? selectedDates.first : DateTime.now()),
        );

  DateTime? _single;
  NibDateRange? _range;
  final List<DateTime> _multi;
  bool _isOpen = false;
  DateTime _displayedMonth;
  DateTime? _minSelectable;
  DateTime? _maxSelectable;

  /// The selected day in single mode, or `null`.
  DateTime? get selectedDate => _single;

  /// The selected range in range mode, or `null`. May be incomplete
  /// ([NibDateRange.isComplete] `false`) while the second end is unpicked.
  NibDateRange? get selectedRange => _range;

  /// The selected days in multi mode (unmodifiable, ascending).
  List<DateTime> get selectedDates => List<DateTime>.unmodifiable(_multi);

  /// Whether the overlay is open (popover/dialog display modes).
  bool get isOpen => _isOpen;

  /// The month currently shown by the calendar (always the first of a month).
  DateTime get displayedMonth => _displayedMonth;

  /// Runtime lower bound on selectable days, or `null` for no controller-set
  /// bound. When set, it takes precedence over the widget's `minDate`.
  DateTime? get minSelectable => _minSelectable;

  /// Runtime upper bound on selectable days, or `null`. Takes precedence over
  /// the widget's `maxDate` when set.
  DateTime? get maxSelectable => _maxSelectable;

  /// Restricts (or, with two `null`s, clears the restriction on) which days
  /// are selectable, at runtime. Days outside `[min, max]` render greyed and
  /// are inert. Overrides the widget's `minDate`/`maxDate` while set.
  void setSelectableBounds(DateTime? min, DateTime? max) {
    final newMin = min == null ? null : dateOnly(min);
    final newMax = max == null ? null : dateOnly(max);
    if (_sameNullableDay(newMin, _minSelectable) && _sameNullableDay(newMax, _maxSelectable)) {
      return;
    }
    _minSelectable = newMin;
    _maxSelectable = newMax;
    notifyListeners();
  }

  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }

  /// Shows the month containing [month] (clamped to its first day).
  void showMonth(DateTime month) {
    final normalized = firstOfMonth(month);
    if (isSameDay(normalized, _displayedMonth)) return;
    _displayedMonth = normalized;
    notifyListeners();
  }

  /// Clears the whole selection across all modes.
  void clear() {
    if (_single == null && _range == null && _multi.isEmpty) return;
    _single = null;
    _range = null;
    _multi.clear();
    notifyListeners();
  }

  // --- Mode-specific setters used by the widget when a day is tapped. -------

  void setSingle(DateTime? day) {
    final d = day == null ? null : dateOnly(day);
    if (_sameNullableDay(d, _single)) return;
    _single = d;
    notifyListeners();
  }

  void setRange(NibDateRange? range) {
    if (range == _range) return;
    _range = range;
    notifyListeners();
  }

  void setMulti(List<DateTime> days) {
    _multi
      ..clear()
      ..addAll([for (final d in days) dateOnly(d)]);
    notifyListeners();
  }

  static bool _sameNullableDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == null && b == null;
    return isSameDay(a, b);
  }
}
