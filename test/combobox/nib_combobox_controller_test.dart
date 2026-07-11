import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

void main() {
  test('starts closed, empty selection, empty query', () {
    final c = NibComboboxController<String>();
    expect(c.isOpen, isFalse);
    expect(c.selectedValues, isEmpty);
    expect(c.selectedValue, isNull);
    expect(c.query, '');
  });

  test('open/close notify only on a real change', () {
    final c = NibComboboxController<String>();
    var notifications = 0;
    c.addListener(() => notifications++);

    c.open();
    c.open(); // no-op
    expect(c.isOpen, isTrue);
    expect(notifications, 1);

    c.close();
    c.close(); // no-op
    expect(c.isOpen, isFalse);
    expect(notifications, 2);
  });

  test('selectOnly replaces the whole selection', () {
    final c = NibComboboxController<String>();
    c.selectOnly('a');
    c.selectOnly('b');
    expect(c.selectedValues, ['b']);
    expect(c.selectedValue, 'b');
  });

  test('toggle adds then removes', () {
    final c = NibComboboxController<String>();
    c.toggle('a');
    c.toggle('b');
    expect(c.selectedValues, ['a', 'b']);
    c.toggle('a');
    expect(c.selectedValues, ['b']);
  });

  test('clear empties selection and notifies once', () {
    final c = NibComboboxController<String>();
    c.toggle('a');
    var notifications = 0;
    c.addListener(() => notifications++);
    c.clear();
    c.clear(); // no-op
    expect(c.selectedValues, isEmpty);
    expect(notifications, 1);
  });

  test('selectedValues is unmodifiable', () {
    final c = NibComboboxController<String>();
    c.toggle('a');
    expect(() => c.selectedValues.add('b'), throwsUnsupportedError);
  });
}
