import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/combobox/nib_combobox_filter.dart';
import 'package:nib_components/src/combobox/nib_combobox_option.dart';

const _options = [
  NibComboboxOption(value: 'apple', label: 'Apple', subtitle: 'A red fruit'),
  NibComboboxOption(value: 'banana', label: 'Banana'),
  NibComboboxOption(
    value: 'cherry',
    label: 'Cherry',
    subtitle: 'Small and red',
  ),
];

void main() {
  group('defaultComboboxFilter', () {
    test('empty query matches everything', () {
      for (final o in _options) {
        expect(defaultComboboxFilter(o, ''), isTrue);
      }
    });

    test('matches label case-insensitively', () {
      expect(defaultComboboxFilter(_options[0], 'APP'), isTrue);
      expect(defaultComboboxFilter(_options[0], 'ppl'), isTrue);
      expect(defaultComboboxFilter(_options[1], 'app'), isFalse);
    });

    test('matches subtitle case-insensitively', () {
      expect(defaultComboboxFilter(_options[0], 'red fruit'), isTrue);
      expect(defaultComboboxFilter(_options[2], 'SMALL'), isTrue);
      // banana has no subtitle and no label match
      expect(defaultComboboxFilter(_options[1], 'red'), isFalse);
    });
  });

  group('filterOptions', () {
    test('keeps only matches, preserving order', () {
      final result = filterOptions(_options, 'red', defaultComboboxFilter);
      expect(result.map((o) => o.value), ['apple', 'cherry']);
    });

    test('empty query returns all in order', () {
      final result = filterOptions(_options, '', defaultComboboxFilter);
      expect(result, _options);
    });

    test('no match returns empty', () {
      expect(filterOptions(_options, 'zzz', defaultComboboxFilter), isEmpty);
    });

    test('honours a custom filter', () {
      bool startsWith<T>(NibComboboxOption<T> o, String q) =>
          q.isEmpty || o.label.toLowerCase().startsWith(q.toLowerCase());
      final result = filterOptions(_options, 'c', startsWith);
      expect(result.map((o) => o.value), ['cherry']);
      // substring 'rr' would match Cherry with the default filter but not
      // with startsWith
      expect(filterOptions(_options, 'rr', startsWith), isEmpty);
    });
  });
}
