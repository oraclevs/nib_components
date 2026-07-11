import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/command_palette/nib_command_palette_controller.dart';

void main() {
  group('NibCommandPaletteController', () {
    test('starts closed', () {
      final controller = NibCommandPaletteController();
      expect(controller.isOpen, isFalse);
    });

    test('open/close/toggle update isOpen and notify listeners exactly once each', () {
      final controller = NibCommandPaletteController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.open();
      expect(controller.isOpen, isTrue);
      expect(notifications, 1);

      controller.open(); // already open: no-op, no extra notification
      expect(notifications, 1);

      controller.close();
      expect(controller.isOpen, isFalse);
      expect(notifications, 2);

      controller.close(); // already closed: no-op
      expect(notifications, 2);

      controller.toggle();
      expect(controller.isOpen, isTrue);
      expect(notifications, 3);

      controller.toggle();
      expect(controller.isOpen, isFalse);
      expect(notifications, 4);
    });

    test('recordUsed pushes to front, dedups, caps at maxRecent', () {
      final controller = NibCommandPaletteController();
      controller.recordUsed('a', 3);
      controller.recordUsed('b', 3);
      controller.recordUsed('c', 3);
      expect(controller.recentActionIds, ['c', 'b', 'a']);

      controller.recordUsed('a', 3); // re-used: moves to front, no duplicate
      expect(controller.recentActionIds, ['a', 'c', 'b']);

      controller.recordUsed('d', 3); // over cap: oldest drops off
      expect(controller.recentActionIds, ['d', 'a', 'c']);
    });
  });
}
