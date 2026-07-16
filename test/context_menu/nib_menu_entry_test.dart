import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/context_menu/nib_menu_entry.dart';

void main() {
  test('hasSubmenu reflects a non-empty submenu list', () {
    const leaf = NibMenuItem(label: 'Leaf');
    expect(leaf.hasSubmenu, isFalse);

    const emptySub = NibMenuItem(label: 'Empty', submenu: []);
    expect(emptySub.hasSubmenu, isFalse);

    const parent = NibMenuItem(
      label: 'Parent',
      submenu: [NibMenuItem(label: 'Child')],
    );
    expect(parent.hasSubmenu, isTrue);
  });

  test('defaults: enabled true, not destructive', () {
    const item = NibMenuItem(label: 'X');
    expect(item.enabled, isTrue);
    expect(item.destructive, isFalse);
  });
}
