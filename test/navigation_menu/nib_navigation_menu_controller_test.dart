import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

void main() {
  group('NibNavItem', () {
    test('hasChildren reflects whether children is non-empty', () {
      const leaf = NibNavItem(id: 'a', label: 'A');
      const branch = NibNavItem(
        id: 'b',
        label: 'B',
        children: [NibNavItem(id: 'c', label: 'C')],
      );
      expect(leaf.hasChildren, isFalse);
      expect(branch.hasChildren, isTrue);
    });
  });

  group('NibNavMenuController', () {
    test('starts with given openChain/openIds', () {
      final controller = NibNavMenuController(openChain: ['a'], openIds: {'x'});
      expect(controller.openChain, ['a']);
      expect(controller.openIds, {'x'});
    });

    test('openChainTo replaces the chain and notifies', () {
      final controller = NibNavMenuController();
      var notified = 0;
      controller.addListener(() => notified++);
      controller.openChainTo(['a', 'b']);
      expect(controller.openChain, ['a', 'b']);
      expect(notified, 1);
    });

    test('closeFromDepth truncates the chain from the given depth', () {
      final controller = NibNavMenuController(openChain: ['a', 'b', 'c']);
      controller.closeFromDepth(1);
      expect(controller.openChain, ['a']);
    });

    test('closeAll empties the chain, no-op if already empty', () {
      final controller = NibNavMenuController(openChain: ['a']);
      var notified = 0;
      controller.addListener(() => notified++);
      controller.closeAll();
      expect(controller.openChain, isEmpty);
      expect(notified, 1);
      controller.closeAll();
      expect(notified, 1, reason: 'no-op close should not notify again');
    });

    test('toggleOpenId adds then removes, notifying each time', () {
      final controller = NibNavMenuController();
      var notified = 0;
      controller.addListener(() => notified++);
      controller.toggleOpenId('a');
      expect(controller.openIds, {'a'});
      controller.toggleOpenId('a');
      expect(controller.openIds, isEmpty);
      expect(notified, 2);
    });

    test(
      'toggleOpenId with exclusiveSiblings closes siblings when opening',
      () {
        final controller = NibNavMenuController(openIds: {'sibling'});
        controller.toggleOpenId('a', exclusiveSiblings: {'sibling'});
        expect(controller.openIds, {'a'});
      },
    );

    test('openChain/openIds are unmodifiable', () {
      final controller = NibNavMenuController(openChain: ['a'], openIds: {'x'});
      expect(() => controller.openChain.add('b'), throwsUnsupportedError);
      expect(() => controller.openIds.add('y'), throwsUnsupportedError);
    });
  });
}
