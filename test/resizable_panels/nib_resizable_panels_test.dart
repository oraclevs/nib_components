import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

Widget _wrap(Widget child, {double width = 400, double height = 300}) {
  return MaterialApp(
    theme: ThemeData(extensions: const [NibTheme.light]),
    home: Scaffold(body: SizedBox(width: width, height: height, child: child)),
  );
}

void main() {
  testWidgets('renders every panel child and (panels.length - 1) handles', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NibResizablePanels(
          direction: Axis.horizontal,
          panels: [
            NibResizablePanel(child: const Text('A')),
            NibResizablePanel(child: const Text('B')),
            NibResizablePanel(child: const Text('C')),
          ],
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.byType(NibResizablePanelsHandle), findsNWidgets(2));
  });

  testWidgets('default (no initialSize) splits panels evenly', (tester) async {
    final keyA = GlobalKey();
    final keyB = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        NibResizablePanels(
          direction: Axis.horizontal,
          panels: [
            NibResizablePanel(child: SizedBox.expand(key: keyA)),
            NibResizablePanel(child: SizedBox.expand(key: keyB)),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.byKey(keyA)).width, closeTo(tester.getSize(find.byKey(keyB)).width, 0.01));
  });

  testWidgets('an externally-supplied controller with initialSizes drives the initial layout', (tester) async {
    final keyA = GlobalKey();
    final keyB = GlobalKey();
    final controller = NibResizablePanelsController(initialSizes: [0.75, 0.25]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        NibResizablePanels(
          direction: Axis.horizontal,
          controller: controller,
          panels: [
            NibResizablePanel(child: SizedBox.expand(key: keyA)),
            NibResizablePanel(child: SizedBox.expand(key: keyB)),
          ],
        ),
      ),
    );

    final widthA = tester.getSize(find.byKey(keyA)).width;
    final widthB = tester.getSize(find.byKey(keyB)).width;
    expect(widthA / (widthA + widthB), closeTo(0.75, 0.01));
  });

  testWidgets('calling controller.setSizes relayouts the group', (tester) async {
    final keyA = GlobalKey();
    final keyB = GlobalKey();
    final controller = NibResizablePanelsController(initialSizes: [0.5, 0.5]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        NibResizablePanels(
          direction: Axis.horizontal,
          controller: controller,
          panels: [
            NibResizablePanel(child: SizedBox.expand(key: keyA)),
            NibResizablePanel(child: SizedBox.expand(key: keyB)),
          ],
        ),
      ),
    );

    controller.setSizes([0.2, 0.8]);
    await tester.pump();

    final widthA = tester.getSize(find.byKey(keyA)).width;
    final widthB = tester.getSize(find.byKey(keyB)).width;
    expect(widthA / (widthA + widthB), closeTo(0.2, 0.01));
  });

  testWidgets('swapping from an internal to an externally-supplied controller does not throw', (tester) async {
    final panels = [NibResizablePanel(child: const Text('A')), NibResizablePanel(child: const Text('B'))];
    await tester.pumpWidget(_wrap(NibResizablePanels(direction: Axis.horizontal, panels: panels)));

    final controller = NibResizablePanelsController(initialSizes: [0.3, 0.7]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(NibResizablePanels(direction: Axis.horizontal, controller: controller, panels: panels)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('dragging a handle resizes its two adjacent panels only', (tester) async {
    final controller = NibResizablePanelsController(initialSizes: [1 / 3, 1 / 3, 1 / 3]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        NibResizablePanels(
          direction: Axis.horizontal,
          controller: controller,
          panels: [
            NibResizablePanel(child: const SizedBox.expand()),
            NibResizablePanel(child: const SizedBox.expand()),
            NibResizablePanel(child: const SizedBox.expand()),
          ],
        ),
      ),
    );

    final before = controller.sizes;
    await tester.drag(find.byKey(const ValueKey('nib-resizable-handle-0')), const Offset(40, 0));
    await tester.pumpAndSettle();

    expect(controller.sizes[0], greaterThan(before[0]));
    expect(controller.sizes[1], lessThan(before[1]));
    expect(controller.sizes[2], closeTo(before[2], 1e-9)); // untouched
  });

  testWidgets('dragging past a minSize stops at the limit instead of cascading into the next panel', (tester) async {
    final controller = NibResizablePanelsController(initialSizes: [1 / 3, 1 / 3, 1 / 3]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        NibResizablePanels(
          direction: Axis.horizontal,
          controller: controller,
          panels: [
            NibResizablePanel(child: const SizedBox.expand(), minSize: 0.3),
            NibResizablePanel(child: const SizedBox.expand(), minSize: 0.3),
            NibResizablePanel(child: const SizedBox.expand(), minSize: 0.3),
          ],
        ),
      ),
    );

    // Drag handle 0 far enough left that panel 0 would go well under 0.3 if uncapped.
    await tester.drag(find.byKey(const ValueKey('nib-resizable-handle-0')), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(controller.sizes[0], closeTo(0.3, 0.01));
    expect(controller.sizes[2], closeTo(1 / 3, 1e-9)); // untouched
  });

  testWidgets('onLayoutChanged fires once when the drag ends, not per frame', (tester) async {
    var callCount = 0;
    List<double>? lastLayout;

    await tester.pumpWidget(
      _wrap(
        NibResizablePanels(
          direction: Axis.horizontal,
          panels: [NibResizablePanel(child: const SizedBox.expand()), NibResizablePanel(child: const SizedBox.expand())],
          onLayoutChanged: (sizes) {
            callCount++;
            lastLayout = sizes;
          },
        ),
      ),
    );

    await tester.drag(find.byKey(const ValueKey('nib-resizable-handle-0')), const Offset(40, 0));
    await tester.pumpAndSettle();

    expect(callCount, 1);
    expect(lastLayout, isNotNull);
  });

  testWidgets('double-tap a handle resets its adjacent pair, leaving other panels untouched', (tester) async {
    final controller = NibResizablePanelsController(initialSizes: [0.2, 0.3, 0.5]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        NibResizablePanels(
          direction: Axis.horizontal,
          controller: controller,
          panels: [
            NibResizablePanel(child: const SizedBox.expand(), initialSize: 0.2),
            NibResizablePanel(child: const SizedBox.expand(), initialSize: 0.3),
            NibResizablePanel(child: const SizedBox.expand(), initialSize: 0.5),
          ],
        ),
      ),
    );

    await tester.drag(find.byKey(const ValueKey('nib-resizable-handle-0')), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(controller.sizes[0], isNot(closeTo(0.2, 1e-9)));

    await tester.tap(find.byKey(const ValueKey('nib-resizable-handle-0')));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(find.byKey(const ValueKey('nib-resizable-handle-0')));
    await tester.pumpAndSettle();

    expect(controller.sizes[0], closeTo(0.2, 0.01));
    expect(controller.sizes[1], closeTo(0.3, 0.01));
    expect(controller.sizes[2], closeTo(0.5, 1e-9)); // untouched
  });

  testWidgets('arrow-key nudge on a focused handle resizes the adjacent pair by the fixed step', (tester) async {
    final controller = NibResizablePanelsController(initialSizes: [0.5, 0.5]);
    addTearDown(controller.dispose);
    List<double>? lastLayout;

    await tester.pumpWidget(
      _wrap(
        NibResizablePanels(
          direction: Axis.horizontal,
          controller: controller,
          panels: [NibResizablePanel(child: const SizedBox.expand()), NibResizablePanel(child: const SizedBox.expand())],
          onLayoutChanged: (sizes) => lastLayout = sizes,
        ),
      ),
    );

    final handleFinder = find.byKey(const ValueKey('nib-resizable-handle-0'));
    await tester.tap(handleFinder);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(controller.sizes[0], closeTo(0.5 + kNibResizablePanelsKeyboardStep, 1e-9));
    expect(lastLayout, isNotNull);
  });

  testWidgets('Home/End jump the focused handle to its adjacent pair extremes', (tester) async {
    final controller = NibResizablePanelsController(initialSizes: [0.5, 0.5]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        NibResizablePanels(
          direction: Axis.horizontal,
          controller: controller,
          panels: [
            NibResizablePanel(child: const SizedBox.expand(), minSize: 0.2, maxSize: 0.8),
            NibResizablePanel(child: const SizedBox.expand(), minSize: 0.2, maxSize: 0.8),
          ],
        ),
      ),
    );

    final handleFinder = find.byKey(const ValueKey('nib-resizable-handle-0'));
    await tester.tap(handleFinder);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(controller.sizes[0], closeTo(0.8, 0.01));

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(controller.sizes[0], closeTo(0.2, 0.01));
  });

  testWidgets('the handle exposes resize-handle semantics with a percentage value', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        NibResizablePanels(
          direction: Axis.horizontal,
          controller: NibResizablePanelsController(initialSizes: [0.5, 0.5]),
          panels: [NibResizablePanel(child: const SizedBox.expand()), NibResizablePanel(child: const SizedBox.expand())],
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byKey(const ValueKey('nib-resizable-handle-0'))),
      matchesSemantics(
        label: 'Resize handle',
        value: '50%',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
        // `Focus` contributes the focus action; `GestureDetector`'s
        // horizontal drag callbacks map to Flutter's default
        // scrollLeft/scrollRight semantic actions.
        hasFocusAction: true,
        hasScrollLeftAction: true,
        hasScrollRightAction: true,
        isFocusable: true,
      ),
    );
    handle.dispose();
  });
}
