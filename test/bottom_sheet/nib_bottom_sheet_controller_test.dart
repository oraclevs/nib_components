import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/bottom_sheet/nib_bottom_sheet_controller.dart';

void main() {
  test('open/close toggles isOpen and notifies once each', () {
    final c = NibBottomSheetController();
    var notifications = 0;
    c.addListener(() => notifications++);

    expect(c.isOpen, isFalse);
    c.open();
    expect(c.isOpen, isTrue);
    c.open(); // no-op
    c.close();
    expect(c.isOpen, isFalse);
    c.close(); // no-op

    expect(notifications, 2);
    c.dispose();
  });

  test('snapTo records a pending snap and notifies; consume clears it', () {
    final c = NibBottomSheetController();
    var notifications = 0;
    c.addListener(() => notifications++);

    c.snapTo(1);
    expect(c.pendingSnap, 1);
    expect(notifications, 1);

    c.consumePendingSnap();
    expect(c.pendingSnap, isNull);
    c.dispose();
  });

  test('close clears any pending snap', () {
    final c = NibBottomSheetController()
      ..open()
      ..snapTo(2);
    expect(c.pendingSnap, 2);
    c.close();
    expect(c.pendingSnap, isNull);
    c.dispose();
  });
}
