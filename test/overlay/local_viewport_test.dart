import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

const _hostRect = Rect.fromLTWH(400, 120, 360, 340);

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  TextDirection direction = TextDirection.ltr,
  Alignment alignment = Alignment.bottomRight,
}) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(1000, 800),
          padding: padding,
          viewInsets: viewInsets,
        ),
        child: Directionality(
          textDirection: direction,
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: _hostRect,
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => Material(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Align(
                          alignment: alignment,
                          child: SizedBox(width: 180, child: child),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _card(Finder descendant) => find
    .ancestor(
      of: descendant,
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.elevation > 0,
      ),
    )
    .first;
void _inside(WidgetTester tester, Finder finder, Rect rect) {
  final actual = tester.getRect(finder);
  expect(actual.left, greaterThanOrEqualTo(rect.left - .1));
  expect(actual.right, lessThanOrEqualTo(rect.right + .1));
  expect(actual.top, greaterThanOrEqualTo(rect.top - .1));
  expect(actual.bottom, lessThanOrEqualTo(rect.bottom + .1));
}

void main() {
  for (final direction in TextDirection.values) {
    for (final placement in NibPopoverPlacement.values) {
      testWidgets(
        'popover $placement $direction fits translated local overlay',
        (tester) async {
          final controller = NibPopoverController();
          addTearDown(controller.dispose);
          await _mount(
            tester,
            NibPopover(
              controller: controller,
              placement: placement,
              showArrow: true,
              maxWidth: 250,
              trigger: const SizedBox(height: 40, child: Text('Trigger')),
              content: const SizedBox(
                width: 200,
                height: 100,
                child: Text('Popover body'),
              ),
            ),
            direction: direction,
          );
          controller.open();
          await tester.pumpAndSettle();
          _inside(
            tester,
            _card(find.text('Popover body')),
            _hostRect.deflate(8),
          );
          controller.close();
          await tester.pumpAndSettle();
          expect(find.text('Popover body'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'popover only applies window intrusions intersecting local overlay',
    (tester) async {
      final controller = NibPopoverController();
      addTearDown(controller.dispose);
      await _mount(
        tester,
        NibPopover(
          controller: controller,
          trigger: const Text('Trigger'),
          maxWidth: 250,
          content: const SizedBox(
            width: 200,
            height: 100,
            child: Text('Safe body'),
          ),
        ),
        padding: const EdgeInsets.only(top: 180),
        viewInsets: const EdgeInsets.only(bottom: 400),
        alignment: Alignment.centerRight,
      );
      controller.open();
      await tester.pumpAndSettle();
      _inside(
        tester,
        _card(find.text('Safe body')),
        const Rect.fromLTRB(408, 188, 752, 392),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in ['select', 'combobox']) {
    testWidgets('$kind dropdown flips inside local overlay and selects', (
      tester,
    ) async {
      final select = NibSelectController<int>();
      final combo = NibComboboxController<int>();
      addTearDown(select.dispose);
      addTearDown(combo.dispose);
      int? picked;
      final widget = kind == 'select'
          ? NibSelect<int>(
              controller: select,
              options: [
                for (var i = 0; i < 8; i++)
                  NibSelectOption(value: i, label: 'Choice $i'),
              ],
              onChanged: (v) => picked = v,
            )
          : NibCombobox<int>(
              controller: combo,
              options: [
                for (var i = 0; i < 8; i++)
                  NibComboboxOption(value: i, label: 'Choice $i'),
              ],
              onChanged: (v) => picked = v,
            );
      await _mount(tester, widget);
      if (kind == 'select') {
        select.open();
      } else {
        await tester.tap(find.byType(TextField));
      }
      await tester.pumpAndSettle();
      _inside(tester, _card(find.text('Choice 0')), _hostRect.deflate(8));
      await tester.tap(find.text('Choice 0'));
      await tester.pumpAndSettle();
      expect(picked, 0);
      expect(kind == 'select' ? select.isOpen : combo.isOpen, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('navigation flyout clamps to local edge and still selects', (
    tester,
  ) async {
    String? selected;
    await _mount(
      tester,
      NibNavigationMenu(
        items: const [
          NibNavItem(
            id: 'tools',
            label: 'Tools',
            children: [
              NibNavItem(id: 'one', label: 'First destination'),
              NibNavItem(id: 'two', label: 'Second destination'),
              NibNavItem(id: 'three', label: 'Third destination'),
            ],
          ),
        ],
        onItemSelected: (item) => selected = item,
      ),
    );
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    _inside(
      tester,
      _card(find.text('First destination')),
      _hostRect.deflate(8),
    );
    await tester.tap(find.text('Second destination'));
    await tester.pumpAndSettle();
    expect(selected, 'two');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'page-modal context menu preserves pointer coordinates and submenu reachability',
    (tester) async {
      BuildContext? local;
      NibMenuItem? result;
      await _mount(
        tester,
        Builder(
          builder: (context) {
            local = context;
            return const Text('Context trigger');
          },
        ),
      );
      showNibContextMenu(
        local!,
        globalPosition: const Offset(420, 140),
        items: const [
          NibMenuItem(
            label: 'Nested',
            submenu: [NibMenuItem(label: 'Leaf')],
          ),
          NibMenuItem(label: 'Direct'),
        ],
      ).then((value) => result = value);
      await tester.pumpAndSettle();
      final root = tester.getRect(_card(find.text('Nested')));
      expect(root.topLeft, const Offset(420, 140));
      _inside(
        tester,
        _card(find.text('Nested')),
        const Rect.fromLTWH(8, 8, 984, 784),
      );
      await tester.tap(find.text('Nested'));
      await tester.pumpAndSettle();
      _inside(
        tester,
        _card(find.text('Leaf')),
        const Rect.fromLTWH(8, 8, 984, 784),
      );
      await tester.tap(find.text('Leaf'));
      await tester.pumpAndSettle();
      expect(result?.label, 'Leaf');
      expect(find.text('Nested'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final display in [
    NibDatePickerDisplayMode.popover,
    NibDatePickerDisplayMode.dialog,
  ]) {
    testWidgets('date $display keeps usable calendar inside local overlay', (
      tester,
    ) async {
      final controller = NibDatePickerController(
        displayedMonth: DateTime(2026, 10),
      );
      addTearDown(controller.dispose);
      await _mount(
        tester,
        NibDatePicker(controller: controller, displayMode: display),
      );
      controller.open();
      await tester.pumpAndSettle();
      final heading = find.text('October 2026');
      expect(heading, findsOneWidget);
      _inside(
        tester,
        _card(heading),
        display == NibDatePickerDisplayMode.dialog
            ? _hostRect
            : _hostRect.deflate(8),
      );
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      expect(controller.selectedDate, DateTime(2026, 10, 15));
      expect(controller.isOpen, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
  for (final direction in TextDirection.values) {
    for (final placement in NibHoverCardPlacement.values) {
      testWidgets(
        'hover card $placement $direction fits translated local overlay',
        (tester) async {
          final controller = NibHoverCardController();
          addTearDown(controller.dispose);
          await _mount(
            tester,
            NibHoverCard(
              controller: controller,
              placement: placement,
              trigger: const SizedBox(height: 40, child: Text('Hover trigger')),
              content: const SizedBox(
                width: 300,
                height: 90,
                child: Text('Hover body'),
              ),
            ),
            direction: direction,
          );
          controller.open();
          await tester.pumpAndSettle();
          _inside(tester, _card(find.text('Hover body')), _hostRect.deflate(8));
          controller.close();
          await tester.pumpAndSettle();
          expect(find.text('Hover body'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'command palette stays in nearest overlay and accepts typing and selection',
    (tester) async {
      final controller = NibCommandPaletteController();
      addTearDown(controller.dispose);
      String? selected;
      await _mount(
        tester,
        NibCommandPalette(
          controller: controller,
          actions: const [
            NibCommandAction(id: 'one', label: 'First local action'),
            NibCommandAction(id: 'two', label: 'Second local action'),
          ],
          onActionSelected: (action) => selected = action.id,
          child: const Text('Palette trigger'),
        ),
      );
      controller.open();
      await tester.pumpAndSettle();
      _inside(tester, _card(find.byType(TextField)), _hostRect.deflate(8));
      await tester.enterText(find.byType(TextField), 'Second');
      await tester.pump();
      expect(find.text('First local action'), findsNothing);
      await tester.tap(find.text('Second local action'));
      await tester.pumpAndSettle();
      expect(selected, 'two');
      expect(controller.isOpen, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
