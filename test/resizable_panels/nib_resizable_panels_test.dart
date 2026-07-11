import 'package:flutter/material.dart';
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
}
