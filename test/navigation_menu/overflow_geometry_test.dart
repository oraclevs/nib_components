import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

const _longLabel = 'Workspace settings, billing, and organization preferences';
const _overflowItems = [
  NibNavItem(id: 'workspace', label: _longLabel),
  NibNavItem(id: 'reports', label: 'Reports'),
  NibNavItem(id: 'members', label: 'Members'),
  NibNavItem(id: 'support', label: 'Support'),
];

class _MenuHarness extends StatefulWidget {
  const _MenuHarness({
    super.key,
    required this.width,
    this.items = _overflowItems,
    this.orientation = NibNavMenuOrientation.horizontal,
    this.textScale = 1.5,
  });
  final double width;
  final List<NibNavItem> items;
  final NibNavMenuOrientation orientation;
  final double textScale;

  @override
  State<_MenuHarness> createState() => _MenuHarnessState();
}

class _MenuHarnessState extends State<_MenuHarness> {
  late double width = widget.width;
  late List<NibNavItem> items = widget.items;
  String? active;
  final selections = <String>[];
  final controller = NibNavMenuController();

  void update({double? width, List<NibNavItem>? items, String? active}) {
    setState(() {
      if (width != null) this.width = width;
      if (items != null) this.items = items;
      if (active != null) this.active = active;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData(extensions: const [NibTheme.dark]),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(widget.textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            key: const ValueKey('menu-bounds'),
            width: width,
            child: NibNavigationMenu(
              items: items,
              controller: controller,
              orientation: widget.orientation,
              activeItemId: active,
              onItemSelected: (id) => setState(() {
                active = id;
                selections.add(id);
              }),
            ),
          ),
        ),
      ),
    ),
  );
}

void _surface(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _within(WidgetTester tester, Finder item, Rect bounds) {
  final rect = tester.getRect(item);
  expect(rect.width, greaterThan(0));
  expect(rect.left, greaterThanOrEqualTo(bounds.left - .01));
  expect(rect.right, lessThanOrEqualTo(bounds.right + .01));
}

Finder _inkFor(String text) =>
    find.ancestor(of: find.text(text), matching: find.byType(InkWell)).first;

void main() {
  for (final width in [360.0, 390.0, 768.0]) {
    testWidgets(
      'initial $width layout and More keep every destination reachable at large text',
      (tester) async {
        _surface(tester, width);
        final key = GlobalKey<_MenuHarnessState>();
        await tester.pumpWidget(_MenuHarness(key: key, width: width - 32));
        // The first, unmeasured frame must be valid too; settling alone can hide
        // a transient overflow in the measuring/fallback pass.
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('More'), findsOneWidget);
        expect(find.text(_longLabel), findsNothing);
        final bounds = tester.getRect(
          find.byKey(const ValueKey('menu-bounds')),
        );
        _within(tester, _inkFor('More'), bounds);

        for (final item in _overflowItems) {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          expect(key.currentState!.controller.openChain, ['__more__']);
          for (final destination in _overflowItems) {
            expect(find.text(destination.label), findsOneWidget);
            _within(
              tester,
              find.text(destination.label),
              Rect.fromLTWH(0, 0, width, 1000),
            );
          }
          await tester.tap(find.text(item.label));
          await tester.pumpAndSettle();
          expect(key.currentState!.selections.last, item.id);
          expect(key.currentState!.controller.openChain, isEmpty);
          expect(find.text(_longLabel), findsNothing);
          expect(tester.takeException(), isNull);
        }
        expect(key.currentState!.selections, [
          'workspace',
          'reports',
          'members',
          'support',
        ]);
      },
    );
  }

  testWidgets(
    'width and same-id label changes remeasure without dropping a destination',
    (tester) async {
      _surface(tester, 1000);
      final key = GlobalKey<_MenuHarnessState>();
      const short = [
        NibNavItem(id: 'home', label: 'Home'),
        NibNavItem(id: 'about', label: 'About'),
        NibNavItem(id: 'help', label: 'Help'),
      ];
      await tester.pumpWidget(_MenuHarness(key: key, width: 800, items: short));
      await tester.pumpAndSettle();
      expect(find.text('More'), findsNothing);
      for (final item in short) {
        expect(find.text(item.label), findsOneWidget);
      }
      key.currentState!.update(width: 160);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('More'), findsOneWidget);
      _within(
        tester,
        _inkFor('More'),
        tester.getRect(find.byKey(const ValueKey('menu-bounds'))),
      );
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Help'), findsOneWidget);
      await tester.tap(find.text('Help'));
      await tester.pumpAndSettle();
      expect(key.currentState!.selections, ['help']);

      key.currentState!.update(width: 800);
      await tester.pumpAndSettle();
      expect(find.text('More'), findsNothing);
      key.currentState!.update(
        items: const [
          NibNavItem(id: 'home', label: _longLabel),
          NibNavItem(id: 'about', label: 'About'),
          NibNavItem(id: 'help', label: 'Help'),
        ],
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('More'), findsOneWidget);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text(_longLabel), findsOneWidget);
      await tester.tap(find.text(_longLabel));
      await tester.pumpAndSettle();
      expect(key.currentState!.selections.last, 'home');
    },
  );

  testWidgets('active text and hidden measurement use the same font weight', (
    tester,
  ) async {
    _surface(tester, 800);
    final key = GlobalKey<_MenuHarnessState>();
    await tester.pumpWidget(
      _MenuHarness(
        key: key,
        width: 700,
        items: const [
          NibNavItem(id: 'home', label: 'Home'),
          NibNavItem(id: 'about', label: 'About'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    key.currentState!.update(active: 'home');
    await tester.pumpAndSettle();
    final homeTexts = tester
        .widgetList<Text>(find.text('Home', skipOffstage: false))
        .toList();
    expect(homeTexts, hasLength(2));
    for (final text in homeTexts) {
      expect(text.style!.fontWeight, FontWeight.w600);
    }
    _within(
      tester,
      _inkFor('Home'),
      tester.getRect(find.byKey(const ValueKey('menu-bounds'))),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard opens More and Escape returns focus from a flyout leaf',
    (tester) async {
      _surface(tester, 390);
      final key = GlobalKey<_MenuHarnessState>();
      await tester.pumpWidget(_MenuHarness(key: key, width: 358));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final trigger = tester.widget<InkWell>(_inkFor('More')).focusNode!;
      expect(trigger.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(key.currentState!.controller.openChain, ['__more__']);
      final leaf = tester.widget<InkWell>(_inkFor(_longLabel)).focusNode!;
      leaf.requestFocus();
      await tester.pump();
      expect(leaf.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(key.currentState!.controller.openChain, isEmpty);
      expect(find.text(_longLabel), findsNothing);
      expect(trigger.hasPrimaryFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Escape closes one cascade depth and restores its own opener', (
    tester,
  ) async {
    _surface(tester, 800);
    final key = GlobalKey<_MenuHarnessState>();
    await tester.pumpWidget(
      _MenuHarness(
        key: key,
        width: 700,
        items: const [
          NibNavItem(
            id: 'products',
            label: 'Products',
            children: [
              NibNavItem(
                id: 'hardware',
                label: 'Hardware',
                children: [NibNavItem(id: 'devices', label: 'Devices')],
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    final rootOpener = tester.widget<InkWell>(_inkFor('Products')).focusNode!;
    await tester.tap(find.text('Hardware'));
    await tester.pumpAndSettle();
    expect(key.currentState!.controller.openChain, ['products', 'hardware']);
    final nestedOpener = tester.widget<InkWell>(_inkFor('Hardware')).focusNode!;
    tester.widget<InkWell>(_inkFor('Devices')).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(key.currentState!.controller.openChain, ['products']);
    expect(find.text('Devices'), findsNothing);
    expect(find.text('Hardware'), findsOneWidget);
    expect(nestedOpener.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(key.currentState!.controller.openChain, isEmpty);
    expect(find.text('Hardware'), findsNothing);
    expect(rootOpener.hasPrimaryFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'vertical long labels wrap inside the available width and select a nested destination',
    (tester) async {
      _surface(tester, 360);
      final key = GlobalKey<_MenuHarnessState>();
      const childLabel = 'Reports for every team in the current workspace';
      await tester.pumpWidget(
        _MenuHarness(
          key: key,
          width: 220,
          textScale: 2,
          orientation: NibNavMenuOrientation.vertical,
          items: const [
            NibNavItem(
              id: 'workspace',
              label: _longLabel,
              children: [NibNavItem(id: 'reports', label: childLabel)],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final bounds = tester.getRect(find.byKey(const ValueKey('menu-bounds')));
      _within(tester, find.text(_longLabel), bounds);
      expect(tester.getSize(find.text(_longLabel)).height, greaterThan(40));
      await tester.tap(find.text(_longLabel));
      await tester.pumpAndSettle();
      expect(key.currentState!.controller.openIds, contains('workspace'));
      _within(tester, find.text(childLabel), bounds);
      expect(tester.getSize(find.text(childLabel)).height, greaterThan(40));
      await tester.tap(find.text(childLabel));
      await tester.pumpAndSettle();
      expect(key.currentState!.selections, ['reports']);
      expect(tester.takeException(), isNull);
    },
  );
}
