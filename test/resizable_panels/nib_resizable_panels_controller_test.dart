import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/resizable_panels/nib_resizable_panel.dart';
import 'package:nib_components/src/resizable_panels/nib_resizable_panels_controller.dart';

List<NibResizablePanel> _panels(List<double?> initialSizes) {
  return [for (final size in initialSizes) NibResizablePanel(child: const SizedBox(), initialSize: size)];
}

void main() {
  test('sizes is empty before attach', () {
    final controller = NibResizablePanelsController();
    expect(controller.sizes, isEmpty);
  });

  test('attach seeds sizes from normalizedInitialSizes on first call', () {
    final controller = NibResizablePanelsController();
    controller.attach(_panels([0.25, 0.75]));
    expect(controller.sizes, [closeTo(0.25, 1e-9), closeTo(0.75, 1e-9)]);
  });

  test('attach is a no-op once already seeded with the same panel count', () {
    final controller = NibResizablePanelsController();
    controller.attach(_panels([0.25, 0.75]));
    controller.applyDelta(_panels([0.25, 0.75]), 0, 0.1);
    final afterDrag = controller.sizes;
    // A second attach call with a different (but same-length) initial split
    // must not reseed and discard the drag.
    controller.attach(_panels([0.5, 0.5]));
    expect(controller.sizes, afterDrag);
  });

  test('constructing with initialSizes seeds sizes immediately, without attach', () {
    final controller = NibResizablePanelsController(initialSizes: [0.4, 0.6]);
    expect(controller.sizes, [0.4, 0.6]);
  });

  test('setSizes normalizes to sum 1.0 and notifies listeners', () {
    final controller = NibResizablePanelsController(initialSizes: [0.5, 0.5]);
    var notified = 0;
    controller.addListener(() => notified++);
    controller.setSizes([0.6, 0.6]);
    expect(controller.sizes, [closeTo(0.5, 1e-9), closeTo(0.5, 1e-9)]);
    expect(notified, 1);
  });

  test('applyDelta updates the adjacent pair and notifies listeners', () {
    final controller = NibResizablePanelsController(initialSizes: [0.5, 0.5]);
    var notified = 0;
    controller.addListener(() => notified++);
    controller.applyDelta(_panels([null, null]), 0, 0.1);
    expect(controller.sizes, [closeTo(0.6, 1e-9), closeTo(0.4, 1e-9)]);
    expect(notified, 1);
  });

  test('resetPanelPair restores the pair to its initial ratio and notifies', () {
    final controller = NibResizablePanelsController();
    controller.attach(_panels([0.5, 0.5]));
    controller.applyDelta(_panels([null, null]), 0, 0.2);
    var notified = 0;
    controller.addListener(() => notified++);
    controller.resetPanelPair(0);
    expect(controller.sizes, [closeTo(0.5, 1e-9), closeTo(0.5, 1e-9)]);
    expect(notified, 1);
  });

  test('resetAll restores every panel to its initial fraction and notifies', () {
    final controller = NibResizablePanelsController();
    controller.attach(_panels([0.2, 0.3, 0.5]));
    controller.applyDelta(_panels([null, null, null]), 1, 0.1);
    var notified = 0;
    controller.addListener(() => notified++);
    controller.resetAll();
    expect(controller.sizes, [closeTo(0.2, 1e-9), closeTo(0.3, 1e-9), closeTo(0.5, 1e-9)]);
    expect(notified, 1);
  });
}
