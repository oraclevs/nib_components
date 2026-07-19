import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

void main() {
  test('initial displayed month derives from selection or now', () {
    final c = NibDatePickerController(selectedDate: DateTime(2026, 3, 20));
    expect(c.displayedMonth, DateTime(2026, 3, 1));
    expect(c.selectedDate, DateTime(2026, 3, 20));

    final empty = NibDatePickerController();
    expect(empty.displayedMonth.day, 1);
  });

  test('open/close notify only on real change', () {
    final c = NibDatePickerController();
    var n = 0;
    c.addListener(() => n++);
    c.open();
    c.open();
    c.close();
    c.close();
    expect(n, 2);
    expect(c.isOpen, isFalse);
  });

  test('showMonth normalizes to the first and dedupes', () {
    final c = NibDatePickerController(displayedMonth: DateTime(2026, 7, 1));
    var n = 0;
    c.addListener(() => n++);
    c.showMonth(DateTime(2026, 8, 15));
    expect(c.displayedMonth, DateTime(2026, 8, 1));
    c.showMonth(DateTime(2026, 8, 1)); // no-op
    expect(n, 1);
  });

  test('setSingle stores date-only and dedupes', () {
    final c = NibDatePickerController();
    var n = 0;
    c.addListener(() => n++);
    c.setSingle(DateTime(2026, 7, 12, 9, 30));
    expect(c.selectedDate, DateTime(2026, 7, 12));
    c.setSingle(DateTime(2026, 7, 12, 18)); // same day, no-op
    expect(n, 1);
  });

  test('setMulti and clear', () {
    final c = NibDatePickerController();
    c.setMulti([DateTime(2026, 7, 5), DateTime(2026, 7, 10)]);
    expect(c.selectedDates, [DateTime(2026, 7, 5), DateTime(2026, 7, 10)]);
    expect(
      () => c.selectedDates.add(DateTime(2026, 7, 1)),
      throwsUnsupportedError,
    );

    var n = 0;
    c.addListener(() => n++);
    c.clear();
    c.clear(); // no-op
    expect(c.selectedDates, isEmpty);
    expect(n, 1);
  });

  test('setSelectableBounds normalizes, dedupes, and clears', () {
    final c = NibDatePickerController();
    var n = 0;
    c.addListener(() => n++);
    c.setSelectableBounds(
      DateTime(2026, 7, 5, 9, 30),
      DateTime(2026, 7, 20, 18),
    );
    expect(c.minSelectable, DateTime(2026, 7, 5));
    expect(c.maxSelectable, DateTime(2026, 7, 20));
    c.setSelectableBounds(
      DateTime(2026, 7, 5),
      DateTime(2026, 7, 20),
    ); // same day -> no-op
    expect(n, 1);
    c.setSelectableBounds(null, null);
    expect(c.minSelectable, isNull);
    expect(c.maxSelectable, isNull);
    expect(n, 2);
  });

  test('setRange holds incomplete then complete', () {
    final c = NibDatePickerController();
    c.setRange(NibDateRange(start: DateTime(2026, 7, 5)));
    expect(c.selectedRange!.isComplete, isFalse);
    c.setRange(
      NibDateRange(start: DateTime(2026, 7, 5), end: DateTime(2026, 7, 10)),
    );
    expect(c.selectedRange!.isComplete, isTrue);
  });
}
