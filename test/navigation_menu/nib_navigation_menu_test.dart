import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: const [NibTheme.light]),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders every top-level item label, horizontal by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const NibNavigationMenu(
          items: [
            NibNavItem(id: 'home', label: 'Home'),
            NibNavItem(id: 'about', label: 'About'),
          ],
        ),
      ),
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.byType(Row), findsWidgets);
  });

  testWidgets('vertical orientation lays out items in a Column', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const NibNavigationMenu(
          orientation: NibNavMenuOrientation.vertical,
          items: [
            NibNavItem(id: 'home', label: 'Home'),
            NibNavItem(id: 'about', label: 'About'),
          ],
        ),
      ),
    );
    expect(find.byType(Column), findsWidgets);
  });

  testWidgets('tapping a leaf item calls onItemSelected with its id', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      _wrap(
        NibNavigationMenu(
          items: const [NibNavItem(id: 'home', label: 'Home')],
          onItemSelected: (id) => selected = id,
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(selected, 'home');
  });

  testWidgets('disabled item does not call onItemSelected', (tester) async {
    String? selected;
    await tester.pumpWidget(
      _wrap(
        NibNavigationMenu(
          items: const [NibNavItem(id: 'home', label: 'Home', disabled: true)],
          onItemSelected: (id) => selected = id,
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });

  testWidgets('activeItemId is announced as selected to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        const NibNavigationMenu(
          activeItemId: 'home',
          items: [
            NibNavItem(id: 'home', label: 'Home'),
            NibNavItem(id: 'about', label: 'About'),
          ],
        ),
      ),
    );
    final homeNode = tester.getSemantics(find.text('Home'));
    final aboutNode = tester.getSemantics(find.text('About'));
    // ignore: deprecated_member_use
    expect(homeNode.hasFlag(SemanticsFlag.isSelected), isTrue);
    // ignore: deprecated_member_use
    expect(aboutNode.hasFlag(SemanticsFlag.isSelected), isFalse);
    handle.dispose();
  });
}
