import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/popover/nib_popover_controller.dart';

void main() {
  test('open/close/toggle drive isOpen and notify once per real change', () {
    final c = NibPopoverController();
    var notifications = 0;
    c.addListener(() => notifications++);

    expect(c.isOpen, isFalse);
    c.open();
    expect(c.isOpen, isTrue);
    c.open(); // no-op
    c.toggle();
    expect(c.isOpen, isFalse);
    c.toggle();
    expect(c.isOpen, isTrue);
    c.close();
    c.close(); // no-op

    expect(notifications, 4);
    c.dispose();
  });
}
