import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

/// Pumps a bare app with a button that opens a sheet via [open], exposing the
/// captured future through [onOpen].
Widget _host(void Function(BuildContext) open) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('showNibBottomSheet', () {
    testWidgets('opens over the root overlay and shows content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          (c) => showNibBottomSheet<void>(
            c,
            title: 'Sheet',
            content: const Text('sheet body'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Sheet'), findsOneWidget);
      expect(find.text('sheet body'), findsOneWidget);
    });

    testWidgets('barrier tap dismisses and completes the future with null', (
      tester,
    ) async {
      Future<String?>? result;
      await tester.pumpWidget(
        _host((c) {
          result = showNibBottomSheet<String>(c, content: const Text('body'));
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget);

      // Tap near the top of the screen — the barrier, above the sheet.
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();

      expect(find.text('body'), findsNothing);
      expect(await result, isNull);
    });

    testWidgets('non-dismissible ignores barrier taps', (tester) async {
      await tester.pumpWidget(
        _host(
          (c) => showNibBottomSheet<void>(
            c,
            dismissible: false,
            content: const Text('locked'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();
      expect(find.text('locked'), findsOneWidget);
    });

    testWidgets('NibBottomSheetScope.close completes with a result', (
      tester,
    ) async {
      Future<String?>? result;
      await tester.pumpWidget(
        _host((c) {
          result = showNibBottomSheet<String>(
            c,
            content: Builder(
              builder: (sctx) => TextButton(
                onPressed: () => NibBottomSheetScope.of(sctx).close('saved'),
                child: const Text('save'),
              ),
            ),
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(find.text('save'), findsNothing);
      expect(await result, 'saved');
    });

    testWidgets('Escape dismisses when dismissible', (tester) async {
      await tester.pumpWidget(
        _host(
          (c) => showNibBottomSheet<void>(c, content: const Text('esc body')),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('esc body'), findsNothing);
    });

    testWidgets('builds no NibMotion when animated is false', (tester) async {
      await tester.pumpWidget(
        _host((c) => showNibBottomSheet<void>(c, content: const Text('plain'))),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('plain'), findsOneWidget);
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('routes the barrier through NibMotion when animated', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          (c) => showNibBottomSheet<void>(
            c,
            animated: true,
            content: const Text('animated'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump(); // enter frame
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(NibMotion), findsWidgets);
      await tester.pumpAndSettle();
    });

    testWidgets('flinging the sheet down dismisses it', (tester) async {
      Future<void>? result;
      await tester.pumpWidget(
        _host((c) {
          result = showNibBottomSheet<void>(
            c,
            content: const Text('flick body'),
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('flick body'), findsOneWidget);

      await tester.fling(find.text('flick body'), const Offset(0, 400), 1200);
      await tester.pumpAndSettle();

      expect(find.text('flick body'), findsNothing);
      expect(result, completes);
    });

    testWidgets('snap-point sheet reports onSnapChanged when settling lower', (
      tester,
    ) async {
      final snaps = <int>[];
      await tester.pumpWidget(
        _host(
          (c) => showNibBottomSheet<void>(
            c,
            title: 'Snaps',
            snapPoints: const [0.3, 0.6, 0.9],
            initialSnap: 2,
            onSnapChanged: snaps.add,
            content: const Text('snap body'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Slow drag downward over the (non-scrolling) title zone, then release —
      // settles from the 0.9 snap toward a lower one. Dragging the title avoids
      // the inner scroll view claiming the vertical gesture.
      await tester.drag(find.text('Snaps'), const Offset(0, 220));
      await tester.pumpAndSettle();

      expect(find.text('snap body'), findsOneWidget); // did not dismiss
      expect(snaps, isNotEmpty);
      expect(snaps.last, lessThan(2));
    });
  });
}
