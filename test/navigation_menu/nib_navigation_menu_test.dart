import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion, NibPresence;

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

  testWidgets('vertical orientation lays out items in a Column', (
    tester,
  ) async {
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

  testWidgets(
    'tapping a horizontal branch item opens a flyout with its children',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibNavigationMenu(
            items: [
              NibNavItem(
                id: 'products',
                label: 'Products',
                children: [
                  NibNavItem(id: 'widgets', label: 'Widgets'),
                  NibNavItem(id: 'gadgets', label: 'Gadgets'),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.text('Widgets'), findsNothing);

      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.text('Widgets'), findsOneWidget);
      expect(find.text('Gadgets'), findsOneWidget);
    },
  );

  testWidgets('tapping the same branch item again closes the flyout', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const NibNavigationMenu(
          items: [
            NibNavItem(
              id: 'products',
              label: 'Products',
              children: [NibNavItem(id: 'widgets', label: 'Widgets')],
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    expect(find.text('Widgets'), findsOneWidget);

    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    expect(find.text('Widgets'), findsNothing);
  });

  testWidgets(
    'selecting a leaf inside a flyout calls onItemSelected and closes it',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        _wrap(
          NibNavigationMenu(
            items: const [
              NibNavItem(
                id: 'products',
                label: 'Products',
                children: [NibNavItem(id: 'widgets', label: 'Widgets')],
              ),
            ],
            onItemSelected: (id) => selected = id,
          ),
        ),
      );
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Widgets'));
      await tester.pumpAndSettle();
      expect(selected, 'widgets');
      expect(find.text('Widgets'), findsNothing);
    },
  );

  testWidgets('tapping outside the flyout closes it', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Align(
          alignment: Alignment.topLeft,
          child: NibNavigationMenu(
            items: [
              NibNavItem(
                id: 'products',
                label: 'Products',
                children: [NibNavItem(id: 'widgets', label: 'Widgets')],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    expect(find.text('Widgets'), findsOneWidget);

    // Far bottom-right corner of the 800x600 test surface — guaranteed
    // clear of both the trigger (top-left) and its flyout beneath it.
    await tester.tapAt(const Offset(780, 580));
    await tester.pumpAndSettle();
    expect(find.text('Widgets'), findsNothing);
  });

  testWidgets(
    'an item inside an open flyout with its own children opens a cascading second flyout',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibNavigationMenu(
            items: [
              NibNavItem(
                id: 'products',
                label: 'Products',
                children: [
                  NibNavItem(
                    id: 'hardware',
                    label: 'Hardware',
                    children: [NibNavItem(id: 'widgets', label: 'Widgets')],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.text('Hardware'), findsOneWidget);
      expect(find.text('Widgets'), findsNothing);

      await tester.tap(find.text('Hardware'));
      await tester.pumpAndSettle();
      expect(find.text('Widgets'), findsOneWidget);
    },
  );

  testWidgets(
    'closing the first-level flyout also closes any open cascade beneath it',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Align(
            alignment: Alignment.topLeft,
            child: NibNavigationMenu(
              items: [
                NibNavItem(
                  id: 'products',
                  label: 'Products',
                  children: [
                    NibNavItem(
                      id: 'hardware',
                      label: 'Hardware',
                      children: [NibNavItem(id: 'widgets', label: 'Widgets')],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hardware'));
      await tester.pumpAndSettle();
      expect(find.text('Widgets'), findsOneWidget);

      await tester.tapAt(const Offset(780, 580));
      await tester.pumpAndSettle();
      expect(find.text('Hardware'), findsNothing);
      expect(find.text('Widgets'), findsNothing);
    },
  );

  testWidgets(
    'switching to a sibling at the same depth replaces the deeper cascade',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibNavigationMenu(
            items: [
              NibNavItem(
                id: 'products',
                label: 'Products',
                children: [
                  NibNavItem(
                    id: 'hardware',
                    label: 'Hardware',
                    children: [NibNavItem(id: 'widgets', label: 'Widgets')],
                  ),
                  NibNavItem(
                    id: 'software',
                    label: 'Software',
                    children: [NibNavItem(id: 'licenses', label: 'Licenses')],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hardware'));
      await tester.pumpAndSettle();
      expect(find.text('Widgets'), findsOneWidget);

      await tester.tap(find.text('Software'));
      await tester.pumpAndSettle();
      expect(find.text('Widgets'), findsNothing);
      expect(find.text('Licenses'), findsOneWidget);
      expect(find.text('Hardware'), findsOneWidget);
      expect(find.text('Software'), findsOneWidget);
    },
  );

  testWidgets('vertical: tapping a branch item expands its children inline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const NibNavigationMenu(
          orientation: NibNavMenuOrientation.vertical,
          items: [
            NibNavItem(
              id: 'products',
              label: 'Products',
              children: [NibNavItem(id: 'widgets', label: 'Widgets')],
            ),
          ],
        ),
      ),
    );
    expect(find.text('Widgets'), findsNothing);

    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    expect(find.text('Widgets'), findsOneWidget);

    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    expect(find.text('Widgets'), findsNothing);
  });

  testWidgets(
    'vertical: single-open by default closes a sibling when a new one opens',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibNavigationMenu(
            orientation: NibNavMenuOrientation.vertical,
            items: [
              NibNavItem(
                id: 'products',
                label: 'Products',
                children: [NibNavItem(id: 'widgets', label: 'Widgets')],
              ),
              NibNavItem(
                id: 'company',
                label: 'Company',
                children: [NibNavItem(id: 'about', label: 'About')],
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.text('Widgets'), findsOneWidget);

      await tester.tap(find.text('Company'));
      await tester.pumpAndSettle();
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Widgets'), findsNothing);
    },
  );

  testWidgets('vertical: allowMultipleOpen keeps both siblings expanded', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const NibNavigationMenu(
          orientation: NibNavMenuOrientation.vertical,
          allowMultipleOpen: true,
          items: [
            NibNavItem(
              id: 'products',
              label: 'Products',
              children: [NibNavItem(id: 'widgets', label: 'Widgets')],
            ),
            NibNavItem(
              id: 'company',
              label: 'Company',
              children: [NibNavItem(id: 'about', label: 'About')],
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Company'));
    await tester.pumpAndSettle();
    expect(find.text('Widgets'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets(
    'vertical: a grandchild branch item also expands inline, arbitrary depth',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibNavigationMenu(
            orientation: NibNavMenuOrientation.vertical,
            items: [
              NibNavItem(
                id: 'products',
                label: 'Products',
                children: [
                  NibNavItem(
                    id: 'hardware',
                    label: 'Hardware',
                    children: [NibNavItem(id: 'widgets', label: 'Widgets')],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.text('Hardware'), findsOneWidget);
      expect(find.text('Widgets'), findsNothing);

      await tester.tap(find.text('Hardware'));
      await tester.pumpAndSettle();
      expect(find.text('Widgets'), findsOneWidget);

      await tester.tap(find.text('Hardware'));
      await tester.pumpAndSettle();
      expect(find.text('Widgets'), findsNothing);
      expect(
        find.text('Hardware'),
        findsOneWidget,
        reason: 'collapsing a grandchild does not collapse its parent',
      );
    },
  );

  testWidgets(
    'tab focuses the first item, then arrow-right moves to the next sibling',
    (tester) async {
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
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final firstFocus = FocusManager.instance.primaryFocus;
      expect(firstFocus, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      final secondFocus = FocusManager.instance.primaryFocus;
      expect(secondFocus, isNotNull);
      expect(identical(firstFocus, secondFocus), isFalse);
    },
  );

  testWidgets(
    'enter activates the focused horizontal branch item, opening its flyout',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibNavigationMenu(
            items: [
              NibNavItem(
                id: 'products',
                label: 'Products',
                children: [NibNavItem(id: 'widgets', label: 'Widgets')],
              ),
            ],
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('Widgets'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Widgets'), findsOneWidget);
    },
  );

  testWidgets(
    'enter activates a focused vertical branch item, expanding it inline',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibNavigationMenu(
            orientation: NibNavMenuOrientation.vertical,
            items: [
              NibNavItem(
                id: 'products',
                label: 'Products',
                children: [NibNavItem(id: 'widgets', label: 'Widgets')],
              ),
            ],
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Widgets'), findsOneWidget);
    },
  );

  testWidgets('escape closes an open horizontal flyout', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const NibNavigationMenu(
          items: [
            NibNavItem(
              id: 'products',
              label: 'Products',
              children: [NibNavItem(id: 'widgets', label: 'Widgets')],
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    expect(find.text('Widgets'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Widgets'), findsNothing);
  });

  testWidgets(
    'horizontal: items that do not fit collapse into a trailing "More" flyout',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 220,
            child: const NibNavigationMenu(
              items: [
                NibNavItem(id: 'home', label: 'Home'),
                NibNavItem(id: 'products', label: 'Products'),
                NibNavItem(id: 'about', label: 'About Us'),
                NibNavItem(id: 'contact', label: 'Contact'),
                NibNavItem(id: 'careers', label: 'Careers'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.text('Careers'), findsNothing);

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Careers'), findsOneWidget);
    },
  );

  testWidgets(
    'horizontal: a wide viewport shows every item with no "More" trigger',
    (tester) async {
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
      await tester.pumpAndSettle();
      expect(find.text('More'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    },
  );

  testWidgets(
    'animated: false builds zero NibMotion widgets for an open flyout',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibNavigationMenu(
            items: [
              NibNavItem(
                id: 'products',
                label: 'Products',
                children: [NibNavItem(id: 'widgets', label: 'Widgets')],
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.byType(NibMotion), findsNothing);
    },
  );

  testWidgets('animated: true wraps an opened flyout in NibMotion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const NibNavigationMenu(
          animated: true,
          items: [
            NibNavItem(
              id: 'products',
              label: 'Products',
              children: [NibNavItem(id: 'widgets', label: 'Widgets')],
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    expect(find.byType(NibMotion), findsWidgets);
  });

  testWidgets(
    'animated: false builds zero NibMotion/NibPresence widgets for vertical inline reveal',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibNavigationMenu(
            orientation: NibNavMenuOrientation.vertical,
            items: [
              NibNavItem(
                id: 'products',
                label: 'Products',
                children: [NibNavItem(id: 'widgets', label: 'Widgets')],
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.byType(NibMotion), findsNothing);
      expect(find.byType(NibPresence), findsNothing);
    },
  );

  testWidgets(
    'animated: true wraps an opened vertical inline reveal in NibPresence + NibMotion',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibNavigationMenu(
            orientation: NibNavMenuOrientation.vertical,
            animated: true,
            items: [
              NibNavItem(
                id: 'products',
                label: 'Products',
                children: [NibNavItem(id: 'widgets', label: 'Widgets')],
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.byType(NibPresence), findsOneWidget);
      expect(find.byType(NibMotion), findsOneWidget);
    },
  );
}
