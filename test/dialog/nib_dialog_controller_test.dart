import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

void main() {
  test('starts closed', () {
    expect(NibDialogController().isOpen, isFalse);
  });

  test('open() opens and notifies once', () {
    final c = NibDialogController();
    var notifications = 0;
    c.addListener(() => notifications++);
    c.open();
    expect(c.isOpen, isTrue);
    expect(notifications, 1);
  });

  test('open() is a no-op when already open', () {
    final c = NibDialogController()..open();
    var notifications = 0;
    c.addListener(() => notifications++);
    c.open();
    expect(notifications, 0);
  });

  test('close() closes and notifies once', () {
    final c = NibDialogController()..open();
    var notifications = 0;
    c.addListener(() => notifications++);
    c.close();
    expect(c.isOpen, isFalse);
    expect(notifications, 1);
  });

  test('close() is a no-op when already closed', () {
    final c = NibDialogController();
    var notifications = 0;
    c.addListener(() => notifications++);
    c.close();
    expect(notifications, 0);
  });
}
