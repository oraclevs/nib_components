import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

Finder _visualBox() => find
    .descendant(
      of: find.byType(NibButton),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox && widget.decoration is BoxDecoration,
      ),
    )
    .first;

void main() {
  for (final width in [100.0, 1100.0]) {
    for (final expand in [false, true]) {
      testWidgets('visible button hit geometry at $width, expand $expand', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width + 80, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NibButton(
                        label: 'Run',
                        expand: expand,
                        onPressed: () => taps++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final visual = tester.getRect(_visualBox());
        expect(visual.height, 44);
        if (expand) {
          expect(visual.width, width);
        } else {
          expect(visual.width, lessThan(width));
        }
        // A stretched focus-ring Stack can be wider than this visible box.
        // Taps must use the real point before any minimum-target fallback.
        await tester.tap(find.text('Run'));
        expect(taps, 1);
        await tester.tapAt(Offset(visual.left + 2, visual.center.dy));
        expect(taps, 2);
        await tester.tapAt(Offset(visual.right - 2, visual.center.dy));
        expect(taps, 3);
        expect(
          tester.getRect(_visualBox()),
          visual,
          reason: 'Hit-test repair must preserve painted geometry.',
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'disabled button at $width stays inert and has no semantic tap',
      (tester) async {
        tester.view.physicalSize = Size(width + 80, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NibButton(
                        label: 'Run',
                        semanticLabel: 'Run local example',
                        disabled: true,
                        onPressed: () => taps++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tapAt(tester.getCenter(_visualBox()));
        expect(taps, 0);
        final node = tester.getSemantics(find.byType(NibButton));
        expect(node, isSemantics(isButton: true, isEnabled: false));
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('minimum touch padding still forwards taps to a small button', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NibButton(
              semanticLabel: 'Add',
              leadingIcon: const Icon(Icons.add, size: 12),
              width: 30,
              height: 30,
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );
    final visual = tester.getRect(_visualBox());
    final target = tester.getRect(find.byType(NibButton));
    expect(visual.size, const Size(30, 30));
    expect(target.size, const Size(48, 48));
    final paddedPoint = target.topLeft + const Offset(1, 1);
    expect(visual.contains(paddedPoint), isFalse);
    await tester.tapAt(paddedPoint);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
