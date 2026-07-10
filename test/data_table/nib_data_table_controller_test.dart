import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

void main() {
  group('NibDataTableController', () {
    test('starts with the given sort and selection', () {
      final controller = NibDataTableController<int>(
        sort: const NibDataTableSort(
          columnIndex: 1,
          direction: NibSortDirection.ascending,
        ),
        selected: {1, 2},
      );
      expect(controller.sort.columnIndex, 1);
      expect(controller.sort.direction, NibSortDirection.ascending);
      expect(controller.selected, {1, 2});
    });

    test('setSort notifies listeners', () {
      final controller = NibDataTableController<int>();
      var notified = 0;
      controller.addListener(() => notified++);
      controller.setSort(
        const NibDataTableSort(
          columnIndex: 0,
          direction: NibSortDirection.descending,
        ),
      );
      expect(controller.sort.columnIndex, 0);
      expect(notified, 1);
    });

    test('toggleSelected adds then removes, notifying each time', () {
      final controller = NibDataTableController<String>();
      var notified = 0;
      controller.addListener(() => notified++);
      controller.toggleSelected('a');
      expect(controller.selected, {'a'});
      controller.toggleSelected('a');
      expect(controller.selected, isEmpty);
      expect(notified, 2);
    });

    test('setSelected replaces the whole set', () {
      final controller = NibDataTableController<int>(selected: {1});
      controller.setSelected({2, 3});
      expect(controller.selected, {2, 3});
    });

    test('clearSelection empties the set and only notifies if non-empty', () {
      final controller = NibDataTableController<int>(selected: {1});
      var notified = 0;
      controller.addListener(() => notified++);
      controller.clearSelection();
      expect(controller.selected, isEmpty);
      expect(notified, 1);
      controller.clearSelection();
      expect(notified, 1, reason: 'no-op clear should not notify again');
    });

    test('selected is unmodifiable', () {
      final controller = NibDataTableController<int>(selected: {1});
      expect(() => controller.selected.add(2), throwsUnsupportedError);
    });
  });

  test('NibDataColumn.sortable reflects whether sortValue is set', () {
    final withSort = NibDataColumn<int>(
      label: 'A',
      cellBuilder: (context, row) => Text('$row'),
      sortValue: (row) => row,
    );
    final withoutSort = NibDataColumn<int>(
      label: 'B',
      cellBuilder: (context, row) => Text('$row'),
    );
    expect(withSort.sortable, isTrue);
    expect(withoutSort.sortable, isFalse);
  });
}
