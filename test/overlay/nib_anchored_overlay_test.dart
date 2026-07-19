import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/overlay/nib_anchored_overlay.dart';

Widget _harness({
  required Widget Function(BuildContext context, GlobalKey targetKey) builder,
  Size screenSize = const Size(800, 600),
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: screenSize),
      child: Scaffold(
        body: Builder(
          builder: (context) {
            final targetKey = GlobalKey();
            return builder(context, targetKey);
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows content below the target when it fits', (tester) async {
    final link = LayerLink();
    late BuildContext ctx;
    await tester.pumpWidget(
      _harness(
        builder: (context, targetKey) {
          ctx = context;
          return Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformTarget(
              link: link,
              child: SizedBox(key: targetKey, width: 80, height: 40),
            ),
          );
        },
      ),
    );

    final box = tester.renderObject(find.byType(SizedBox).first) as RenderBox;

    NibAnchoredOverlay.show(
      ctx,
      link: link,
      targetRenderBox: box,
      contentBuilder: (context) => const SizedBox(
        key: ValueKey('content'),
        width: 100,
        height: 50,
        child: Text('flyout'),
      ),
    );
    await tester.pumpAndSettle();

    final targetBottom = tester.getBottomLeft(find.byType(SizedBox).first);
    final contentTop = tester.getTopLeft(find.byKey(const ValueKey('content')));
    expect(contentTop.dy, greaterThanOrEqualTo(targetBottom.dy));
    expect(find.text('flyout'), findsOneWidget);
  });

  testWidgets('flips to top when there is no room below', (tester) async {
    final link = LayerLink();
    late BuildContext ctx;
    await tester.pumpWidget(
      _harness(
        screenSize: const Size(800, 100),
        builder: (context, targetKey) {
          ctx = context;
          return Align(
            alignment: Alignment.bottomLeft,
            child: CompositedTransformTarget(
              link: link,
              child: SizedBox(key: targetKey, width: 80, height: 40),
            ),
          );
        },
      ),
    );

    final box = tester.renderObject(find.byType(SizedBox).first) as RenderBox;
    NibAnchoredOverlay.show(
      ctx,
      link: link,
      targetRenderBox: box,
      contentBuilder: (context) => const SizedBox(
        key: ValueKey('content'),
        width: 100,
        height: 60,
        child: Text('flyout'),
      ),
    );
    await tester.pumpAndSettle();

    final targetTop = tester.getTopLeft(find.byType(SizedBox).first);
    final contentBottom = tester.getBottomLeft(
      find.byKey(const ValueKey('content')),
    );
    expect(contentBottom.dy, lessThanOrEqualTo(targetTop.dy));
  });

  testWidgets('tapping outside dismisses and removes the content', (
    tester,
  ) async {
    final link = LayerLink();
    late BuildContext ctx;
    await tester.pumpWidget(
      _harness(
        builder: (context, targetKey) {
          ctx = context;
          return Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformTarget(
              link: link,
              child: SizedBox(key: targetKey, width: 80, height: 40),
            ),
          );
        },
      ),
    );

    final box = tester.renderObject(find.byType(SizedBox).first) as RenderBox;
    var dismissed = false;
    NibAnchoredOverlay.show(
      ctx,
      link: link,
      targetRenderBox: box,
      contentBuilder: (context) => const SizedBox(
        key: ValueKey('content'),
        width: 100,
        height: 50,
        child: Text('flyout'),
      ),
      onDismissed: () => dismissed = true,
    );
    await tester.pumpAndSettle();
    expect(find.text('flyout'), findsOneWidget);

    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
    expect(find.text('flyout'), findsNothing);
  });

  testWidgets('handle.remove() removes the content without a tap', (
    tester,
  ) async {
    final link = LayerLink();
    late BuildContext ctx;
    await tester.pumpWidget(
      _harness(
        builder: (context, targetKey) {
          ctx = context;
          return Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformTarget(
              link: link,
              child: SizedBox(key: targetKey, width: 80, height: 40),
            ),
          );
        },
      ),
    );

    final box = tester.renderObject(find.byType(SizedBox).first) as RenderBox;
    final handle = NibAnchoredOverlay.show(
      ctx,
      link: link,
      targetRenderBox: box,
      contentBuilder: (context) => const Text('flyout'),
    );
    await tester.pumpAndSettle();
    expect(find.text('flyout'), findsOneWidget);

    handle.remove();
    await tester.pumpAndSettle();
    expect(find.text('flyout'), findsNothing);
  });
}
