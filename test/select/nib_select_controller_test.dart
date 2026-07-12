import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

void main() {
  test('starts empty and closed', () {
    final c = NibSelectController<String>();
    expect(c.selectedValues, isEmpty);
    expect(c.selectedValue, isNull);
    expect(c.isOpen, isFalse);
  });

  test('open/close notify and are idempotent', () {
    final c = NibSelectController<String>();
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

  test('selectOnly replaces the whole selection (single-select)', () {
    final c = NibSelectController<String>();
    c.selectOnly('a');
    c.selectOnly('b');
    expect(c.selectedValues, ['b']);
    expect(c.selectedValue, 'b');
  });

  test('selectOnly with the same single value does not notify', () {
    final c = NibSelectController<String>()..selectOnly('a');
    var notifications = 0;
    c.addListener(() => notifications++);
    c.selectOnly('a');
    expect(notifications, 0);
  });

  test('toggle adds then removes (multi-select)', () {
    final c = NibSelectController<String>();
    c.toggle('a');
    c.toggle('b');
    expect(c.selectedValues, ['a', 'b']);
    c.toggle('a'); // present -> removed
    expect(c.selectedValues, ['b']);
  });

  test('clear empties and only notifies when there was a selection', () {
    final c = NibSelectController<String>()..toggle('a');
    var notifications = 0;
    c.addListener(() => notifications++);
    c.clear();
    expect(c.selectedValues, isEmpty);
    expect(notifications, 1);
    c.clear(); // already empty -> no notify
    expect(notifications, 1);
  });

  test('setSelection replaces and skips notify when unchanged', () {
    final c = NibSelectController<String>();
    var notifications = 0;
    c.addListener(() => notifications++);
    c.setSelection(['a', 'b']);
    expect(c.selectedValues, ['a', 'b']);
    expect(notifications, 1);
    c.setSelection(['a', 'b']); // equal -> no notify
    expect(notifications, 1);
  });

  test('selectedValues is unmodifiable', () {
    final c = NibSelectController<String>()..toggle('a');
    expect(() => c.selectedValues.add('x'), throwsUnsupportedError);
  });
}
