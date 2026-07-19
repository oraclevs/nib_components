import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/date_picker/nib_calendar_math.dart';
import 'package:nib_components/src/date_picker/nib_date_picker_types.dart';

void main() {
  group('isSameDay / dateOnly', () {
    test('same day ignores time', () {
      expect(
        isSameDay(DateTime(2026, 7, 12, 9), DateTime(2026, 7, 12, 23, 59)),
        isTrue,
      );
      expect(isSameDay(DateTime(2026, 7, 12), DateTime(2026, 7, 13)), isFalse);
    });

    test('dateOnly strips time', () {
      expect(dateOnly(DateTime(2026, 7, 12, 15, 30)), DateTime(2026, 7, 12));
    });
  });

  group('daysInMonth', () {
    test('handles 30/31 and February leap years', () {
      expect(daysInMonth(2026, 1), 31);
      expect(daysInMonth(2026, 4), 30);
      expect(daysInMonth(2026, 2), 28);
      expect(daysInMonth(2024, 2), 29); // leap
      expect(daysInMonth(2000, 2), 29); // century leap
      expect(daysInMonth(1900, 2), 28); // century non-leap
      expect(daysInMonth(2026, 12), 31);
    });
  });

  group('addMonths', () {
    test('steps forward and back across year boundaries', () {
      expect(addMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
      expect(addMonths(DateTime(2026, 1, 15), -1), DateTime(2025, 12, 15));
    });

    test('clamps the day to the shorter target month', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
      expect(addMonths(DateTime(2026, 3, 31), -1), DateTime(2026, 2, 28));
    });
  });

  group('calendarDays', () {
    test('produces 42 days starting on the configured first weekday', () {
      // July 2026: the 1st is a Wednesday.
      final sundayFirst = calendarDays(DateTime(2026, 7, 1), 0);
      expect(sundayFirst, hasLength(42));
      // grid starts Sunday June 28, 2026
      expect(sundayFirst.first, DateTime(2026, 6, 28));
      expect(sundayFirst.first.weekday, DateTime.sunday);
      expect(sundayFirst.last, DateTime(2026, 8, 8));
      expect(sundayFirst, contains(DateTime(2026, 7, 1)));
    });

    test('honors a Monday-first locale', () {
      final mondayFirst = calendarDays(DateTime(2026, 7, 1), 1);
      expect(mondayFirst.first.weekday, DateTime.monday);
      // Monday on/before July 1 (Wed) is June 29.
      expect(mondayFirst.first, DateTime(2026, 6, 29));
    });

    test(
      'a month starting exactly on the first weekday has no leading spill',
      () {
        // Feb 2026 starts on a Sunday.
        final grid = calendarDays(DateTime(2026, 2, 1), 0);
        expect(grid.first, DateTime(2026, 2, 1));
      },
    );
  });

  group('isInRange', () {
    final start = DateTime(2026, 7, 5);
    final end = DateTime(2026, 7, 10);

    test('inclusive of both ends', () {
      expect(isInRange(start, start, end), isTrue);
      expect(isInRange(end, start, end), isTrue);
      expect(isInRange(DateTime(2026, 7, 7), start, end), isTrue);
    });

    test('excludes outside days and is order-independent', () {
      expect(isInRange(DateTime(2026, 7, 4), start, end), isFalse);
      expect(isInRange(DateTime(2026, 7, 11), start, end), isFalse);
      expect(isInRange(DateTime(2026, 7, 7), end, start), isTrue);
    });
  });

  group('isDayDisabled', () {
    test('min/max bounds are inclusive', () {
      final min = DateTime(2026, 7, 5);
      final max = DateTime(2026, 7, 10);
      expect(
        isDayDisabled(DateTime(2026, 7, 4), minDate: min, maxDate: max),
        isTrue,
      );
      expect(
        isDayDisabled(DateTime(2026, 7, 5), minDate: min, maxDate: max),
        isFalse,
      );
      expect(
        isDayDisabled(DateTime(2026, 7, 10), minDate: min, maxDate: max),
        isFalse,
      );
      expect(
        isDayDisabled(DateTime(2026, 7, 11), minDate: min, maxDate: max),
        isTrue,
      );
    });

    test('predicate disables matching days', () {
      bool weekends(DateTime d) =>
          d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
      expect(
        isDayDisabled(DateTime(2026, 7, 11), predicate: weekends),
        isTrue,
      ); // Sat
      expect(
        isDayDisabled(DateTime(2026, 7, 13), predicate: weekends),
        isFalse,
      ); // Mon
    });
  });

  group('nextRange', () {
    test('first tap starts an incomplete range', () {
      final r = nextRange(null, DateTime(2026, 7, 5));
      expect(r.start, DateTime(2026, 7, 5));
      expect(r.end, isNull);
      expect(r.isComplete, isFalse);
    });

    test('second later tap completes the range', () {
      final r = nextRange(
        NibDateRange(start: DateTime(2026, 7, 5)),
        DateTime(2026, 7, 10),
      );
      expect(r.start, DateTime(2026, 7, 5));
      expect(r.end, DateTime(2026, 7, 10));
      expect(r.isComplete, isTrue);
    });

    test('second earlier tap swaps ends', () {
      final r = nextRange(
        NibDateRange(start: DateTime(2026, 7, 10)),
        DateTime(2026, 7, 5),
      );
      expect(r.start, DateTime(2026, 7, 5));
      expect(r.end, DateTime(2026, 7, 10));
    });

    test('tapping again after a complete range restarts', () {
      final complete = NibDateRange(
        start: DateTime(2026, 7, 5),
        end: DateTime(2026, 7, 10),
      );
      final r = nextRange(complete, DateTime(2026, 7, 20));
      expect(r.start, DateTime(2026, 7, 20));
      expect(r.end, isNull);
    });
  });

  group('toggleDate', () {
    test('adds when absent, keeps ascending order', () {
      var dates = <DateTime>[];
      dates = toggleDate(dates, DateTime(2026, 7, 10));
      dates = toggleDate(dates, DateTime(2026, 7, 5));
      expect(dates, [DateTime(2026, 7, 5), DateTime(2026, 7, 10)]);
    });

    test('removes when present', () {
      final dates = toggleDate([
        DateTime(2026, 7, 5),
        DateTime(2026, 7, 10),
      ], DateTime(2026, 7, 5));
      expect(dates, [DateTime(2026, 7, 10)]);
    });
  });
}
