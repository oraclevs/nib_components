import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/command_palette/nib_command_action.dart';
import 'package:nib_components/src/command_palette/nib_command_palette_filter.dart';

const _actions = [
  NibCommandAction(id: 'new-file', label: 'New File', group: 'File'),
  NibCommandAction(id: 'open-file', label: 'Open File', subtitle: 'Recent workspace', group: 'File'),
  NibCommandAction(id: 'toggle-sidebar', label: 'Toggle Sidebar'),
  NibCommandAction(id: 'toggle-panel', label: 'Toggle Panel'),
  NibCommandAction(id: 'go-to-line', label: 'Go to Line', group: 'Navigation'),
];

void main() {
  group('defaultCommandActionFilter', () {
    test('empty query matches everything', () {
      for (final action in _actions) {
        expect(defaultCommandActionFilter(action, ''), isTrue);
      }
    });

    test('case-insensitive substring match on label', () {
      expect(defaultCommandActionFilter(_actions[0], 'new'), isTrue);
      expect(defaultCommandActionFilter(_actions[0], 'NEW'), isTrue);
      expect(defaultCommandActionFilter(_actions[0], 'xyz'), isFalse);
    });

    test('matches against subtitle too', () {
      expect(defaultCommandActionFilter(_actions[1], 'workspace'), isTrue);
    });
  });

  group('filterActions', () {
    test('preserves input order, drops non-matches', () {
      final result = filterActions(_actions, 'toggle', defaultCommandActionFilter);
      expect(result.map((a) => a.id), ['toggle-sidebar', 'toggle-panel']);
    });

    test('empty query returns everything unfiltered, same order', () {
      final result = filterActions(_actions, '', defaultCommandActionFilter);
      expect(result, _actions);
    });

    test('no matches returns empty list', () {
      final result = filterActions(_actions, 'zzzz', defaultCommandActionFilter);
      expect(result, isEmpty);
    });

    test('honors a custom filter function', () {
      final result = filterActions(_actions, 'File', (action, query) => action.group == query);
      expect(result.map((a) => a.id), ['new-file', 'open-file']);
    });
  });

  group('findActionById', () {
    test('finds a top-level action', () {
      expect(findActionById(_actions, 'go-to-line')?.label, 'Go to Line');
    });

    test('finds a nested action inside children', () {
      const nested = [
        NibCommandAction(
          id: 'change-theme',
          label: 'Change Theme',
          children: [
            NibCommandAction(id: 'theme-light', label: 'Light'),
            NibCommandAction(id: 'theme-dark', label: 'Dark'),
          ],
        ),
      ];
      expect(findActionById(nested, 'theme-dark')?.label, 'Dark');
    });

    test('returns null when not found', () {
      expect(findActionById(_actions, 'nope'), isNull);
    });
  });

  group('groupActions', () {
    test('clusters consecutive same-group actions, preserves first-appearance order', () {
      final buckets = groupActions(_actions);
      expect(buckets.map((b) => b.group), ['File', null, 'Navigation']);
      expect(buckets[0].actions.map((a) => a.id), ['new-file', 'open-file']);
      expect(buckets[1].actions.map((a) => a.id), ['toggle-sidebar', 'toggle-panel']);
      expect(buckets[2].actions.map((a) => a.id), ['go-to-line']);
    });

    test('all-ungrouped input is a single null-group bucket', () {
      final buckets = groupActions(const [
        NibCommandAction(id: 'a', label: 'A'),
        NibCommandAction(id: 'b', label: 'B'),
      ]);
      expect(buckets, hasLength(1));
      expect(buckets.single.group, isNull);
      expect(buckets.single.actions.map((a) => a.id), ['a', 'b']);
    });

    test('empty input returns empty buckets', () {
      expect(groupActions(const []), isEmpty);
    });

    test('same group appearing in two separate runs stays split into two buckets', () {
      final buckets = groupActions(const [
        NibCommandAction(id: 'a', label: 'A', group: 'X'),
        NibCommandAction(id: 'b', label: 'B'),
        NibCommandAction(id: 'c', label: 'C', group: 'X'),
      ]);
      expect(buckets.map((b) => b.group), ['X', null, 'X']);
    });
  });
}
