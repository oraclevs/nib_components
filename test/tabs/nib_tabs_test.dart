import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

/// Wraps [child] in a fixed 400x600 box so the pager width (and therefore the
/// gutter math) is deterministic.
Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 400, height: 600, child: child)),
  ),
);

List<NibTab> _panels({List<int>? builtLog}) => [
  NibTab(
    label: 'A',
    builder: (_) {
      builtLog?.add(0);
      return const SizedBox(height: 120, child: Text('PanelA'));
    },
  ),
  NibTab(
    label: 'B',
    builder: (_) {
      builtLog?.add(1);
      return const SizedBox(height: 120, child: Text('PanelB'));
    },
  ),
  NibTab(
    label: 'C',
    builder: (_) {
      builtLog?.add(2);
      return const SizedBox(height: 120, child: Text('PanelC'));
    },
  ),
];

void main() {
  group('NibTabs', () {
    testWidgets('renders tab labels and lazily builds only the active panel', (
      tester,
    ) async {
      final built = <int>[];
      await tester.pumpWidget(_host(NibTabs(tabs: _panels(builtLog: built))));
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);

      expect(find.text('PanelA'), findsOneWidget);
      expect(find.text('PanelB'), findsNothing);
      expect(find.text('PanelC'), findsNothing);
      expect(built, isNot(contains(1)));
      expect(built, isNot(contains(2)));
    });

    testWidgets('tapping a tab switches the panel and fires onChanged', (
      tester,
    ) async {
      int? changed;
      await tester.pumpWidget(
        _host(NibTabs(tabs: _panels(), onChanged: (i) => changed = i)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();

      expect(changed, 1);
      expect(find.text('PanelB'), findsOneWidget);
      expect(find.text('PanelA'), findsNothing);
    });

    testWidgets('horizontal swipe switches the panel', (tester) async {
      await tester.pumpWidget(_host(NibTabs(tabs: _panels())));
      await tester.pumpAndSettle();

      await tester.drag(find.text('PanelA'), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(find.text('PanelB'), findsOneWidget);
      expect(find.text('PanelA'), findsNothing);
    });

    testWidgets('swipe does nothing when swipeable is false', (tester) async {
      await tester.pumpWidget(
        _host(NibTabs(tabs: _panels(), swipeable: false)),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('PanelA'), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(find.text('PanelA'), findsOneWidget);
      expect(find.text('PanelB'), findsNothing);
    });

    testWidgets('indicator moves position when the tab changes', (
      tester,
    ) async {
      await tester.pumpWidget(_host(NibTabs(tabs: _panels())));
      await tester.pumpAndSettle();

      final left0 = tester
          .getTopLeft(find.byKey(const ValueKey('nib-tabs-indicator')))
          .dx;

      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();

      final left2 = tester
          .getTopLeft(find.byKey(const ValueKey('nib-tabs-indicator')))
          .dx;

      expect(left2, greaterThan(left0));
    });

    testWidgets('introduces no extra Scrollable — the panel never traps scroll', (
      tester,
    ) async {
      await tester.pumpWidget(_host(NibTabs(tabs: _panels())));
      await tester.pumpAndSettle();

      // The only Scrollable is the widget's own single vertical CustomScrollView;
      // the panel is part of it, not its own competing Scrollable.
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(Scrollable), findsOneWidget);
    });

    testWidgets('separates panels by panelGap during a drag (the gutter)', (
      tester,
    ) async {
      await tester.pumpWidget(_host(NibTabs(tabs: _panels(), panelGap: 16)));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('PanelA')),
      );
      // Step past the touch slop so the horizontal-drag recognizer engages
      // (a single large moveBy never resolves the gesture arena mid-drag).
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(-15, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Mid-drag both the outgoing and incoming panels are present…
      expect(find.text('PanelA'), findsOneWidget);
      expect(find.text('PanelB'), findsOneWidget);

      // …offset by exactly viewportWidth (400) + panelGap (16).
      final ax = tester.getCenter(find.text('PanelA')).dx;
      final bx = tester.getCenter(find.text('PanelB')).dx;
      expect(bx - ax, closeTo(416, 0.5));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('adaptive height reflows the footer between panels of '
        'different heights', (tester) async {
      final tabs = [
        NibTab(
          label: 'Short',
          builder: (_) => const SizedBox(height: 100, child: Text('S')),
        ),
        NibTab(
          label: 'Tall',
          builder: (_) => const SizedBox(height: 300, child: Text('T')),
        ),
      ];
      await tester.pumpWidget(
        _host(NibTabs(tabs: tabs, footer: const Text('FOOTER'))),
      );
      await tester.pumpAndSettle();

      final footerY0 = tester.getTopLeft(find.text('FOOTER')).dy;

      await tester.tap(find.text('Tall'));
      await tester.pumpAndSettle();

      final footerY1 = tester.getTopLeft(find.text('FOOTER')).dy;

      // Taller panel pushes the footer down by ~200 (300 - 100).
      expect(footerY1 - footerY0, closeTo(200, 1));
    });

    testWidgets('animated:true builds NibMotion; animated:false builds none', (
      tester,
    ) async {
      await tester.pumpWidget(_host(NibTabs(tabs: _panels(), animated: false)));
      await tester.pumpAndSettle();
      expect(find.byType(NibMotion), findsNothing);

      await tester.pumpWidget(_host(NibTabs(tabs: _panels(), animated: true)));
      await tester.pumpAndSettle();
      expect(find.byType(NibMotion), findsWidgets);
    });

    testWidgets('NibTabsController.animateTo drives the selected panel', (
      tester,
    ) async {
      final controller = NibTabsController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(NibTabs(tabs: _panels(), controller: controller)),
      );
      await tester.pumpAndSettle();

      controller.animateTo(2);
      await tester.pumpAndSettle();

      expect(controller.index, 2);
      expect(find.text('PanelC'), findsOneWidget);
    });

    testWidgets('external controller is not disposed by the widget', (
      tester,
    ) async {
      final controller = NibTabsController();
      await tester.pumpWidget(
        _host(NibTabs(tabs: _panels(), controller: controller)),
      );
      await tester.pumpAndSettle();

      // Unmount the tabs.
      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pumpAndSettle();

      // Still usable → the widget did not dispose the external controller.
      expect(() => controller.animateTo(1), returnsNormally);
      controller.dispose();
    });

    testWidgets('owns and disposes an internal controller cleanly on unmount', (
      tester,
    ) async {
      await tester.pumpWidget(_host(NibTabs(tabs: _panels())));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pumpAndSettle();
      // No exception on unmount = the owned controller disposed correctly.
      expect(tester.takeException(), isNull);
    });

    testWidgets('honours barHeight and vertically centers tab content', (
      tester,
    ) async {
      await tester.pumpWidget(_host(NibTabs(tabs: _panels(), barHeight: 60)));
      await tester.pumpAndSettle();

      final barRect = tester.getRect(
        find.byKey(const ValueKey('nib-tabs-bar')),
      );
      expect(barRect.height, 60);

      // The label sits on the bar's vertical center (not pinned to the top).
      expect(
        tester.getCenter(find.text('A')).dy,
        closeTo(barRect.center.dy, 4),
      );
    });

    testWidgets('applies backgroundColor and indicatorColor', (tester) async {
      const green = Color(0xFF00FF00);
      await tester.pumpWidget(
        _host(
          NibTabs(
            tabs: _panels(),
            backgroundColor: Colors.transparent,
            indicatorColor: green,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = tester.widget<Container>(
        find.byKey(const ValueKey('nib-tabs-bar')),
      );
      expect((bar.decoration as BoxDecoration).color, Colors.transparent);

      final indicator = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('nib-tabs-indicator')),
      );
      expect((indicator.decoration as BoxDecoration).color, green);
    });

    testWidgets('showDivider:false removes the bar border', (tester) async {
      await tester.pumpWidget(
        _host(NibTabs(tabs: _panels(), showDivider: false)),
      );
      await tester.pumpAndSettle();
      final bar = tester.widget<Container>(
        find.byKey(const ValueKey('nib-tabs-bar')),
      );
      expect((bar.decoration as BoxDecoration).border, isNull);
    });

    testWidgets('header scrolls away while the bar stays pinned', (
      tester,
    ) async {
      final tabs = [
        NibTab(
          label: 'A',
          builder: (_) => const SizedBox(height: 800, child: Text('PanelA')),
        ),
        NibTab(
          label: 'B',
          builder: (_) => const SizedBox(height: 800, child: Text('PanelB')),
        ),
      ];
      await tester.pumpWidget(
        _host(
          NibTabs(
            header: const SizedBox(height: 200, child: Text('HEADER')),
            tabs: tabs,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final barKey = find.byKey(const ValueKey('nib-tabs-bar'));
      // Initially the bar sits just below the 200px header.
      expect(tester.getTopLeft(barKey).dy, closeTo(200, 0.5));

      await tester.drag(find.text('HEADER'), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Header scrolled off (unmounted once past the cache extent); bar pinned
      // to the top.
      expect(tester.getTopLeft(barKey).dy, closeTo(0, 0.5));
      expect(find.text('HEADER'), findsNothing);
    });
  });
}
