// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

late BuildContext ctx;

Widget _harness() => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (c) {
        ctx = c;
        return const SizedBox.expand();
      },
    ),
  ),
);

/// Clears global toast state between tests (a leftover host OverlayEntry would
/// break the next test) and flushes any animated exit timers.
Future<void> _cleanup(WidgetTester tester) async {
  dismissAllNibToasts();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  group('NibToast', () {
    testWidgets('shows a toast with title + message', (tester) async {
      await tester.pumpWidget(_harness());
      showNibToast(
        context: ctx,
        title: 'Saved',
        message: 'All changes stored',
        duration: Duration.zero,
      );
      await tester.pump();

      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('All changes stored'), findsOneWidget);
      await _cleanup(tester);
    });

    testWidgets('auto-dismisses after duration; Duration.zero persists', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      showNibToast(
        context: ctx,
        title: 'Bye',
        duration: const Duration(milliseconds: 100),
      );
      await tester.pump();
      expect(find.text('Bye'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.text('Bye'), findsNothing);

      showNibToast(context: ctx, title: 'Sticky', duration: Duration.zero);
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Sticky'), findsOneWidget);
      await _cleanup(tester);
    });

    testWidgets('duplicate id with shake keeps a single toast', (tester) async {
      await tester.pumpWidget(_harness());
      showNibToast(
        context: ctx,
        id: 'x',
        title: 'One',
        duration: Duration.zero,
      );
      await tester.pump();
      showNibToast(
        context: ctx,
        id: 'x',
        title: 'One',
        duration: Duration.zero,
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('One'), findsOneWidget);
      await _cleanup(tester);
    });

    testWidgets('duplicate id with ignore drops the new call', (tester) async {
      await tester.pumpWidget(_harness());
      showNibToast(
        context: ctx,
        id: 'y',
        title: 'First',
        onDuplicateTrigger: NibToastDuplicateBehavior.ignore,
        duration: Duration.zero,
      );
      await tester.pump();
      showNibToast(
        context: ctx,
        id: 'y',
        title: 'Second',
        onDuplicateTrigger: NibToastDuplicateBehavior.ignore,
        duration: Duration.zero,
      );
      await tester.pump();

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsNothing);
      await _cleanup(tester);
    });

    testWidgets('duplicate id with replace swaps the content', (tester) async {
      await tester.pumpWidget(_harness());
      showNibToast(
        context: ctx,
        id: 'z',
        title: 'Old',
        onDuplicateTrigger: NibToastDuplicateBehavior.replace,
        duration: Duration.zero,
      );
      await tester.pump();
      showNibToast(
        context: ctx,
        id: 'z',
        title: 'New',
        onDuplicateTrigger: NibToastDuplicateBehavior.replace,
        duration: Duration.zero,
      );
      await tester.pump();

      expect(find.text('New'), findsOneWidget);
      expect(find.text('Old'), findsNothing);
      await _cleanup(tester);
    });

    testWidgets('close button dismisses and fires onDismiss', (tester) async {
      await tester.pumpWidget(_harness());
      var dismissed = false;
      showNibToast(
        context: ctx,
        title: 'Close me',
        duration: Duration.zero,
        onDismiss: () => dismissed = true,
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(find.text('Close me'), findsNothing);
      expect(dismissed, isTrue);
      await _cleanup(tester);
    });

    testWidgets('swipe past threshold dismisses; short swipe stays', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      showNibToast(context: ctx, title: 'Swipe', duration: Duration.zero);
      await tester.pump();
      await tester.drag(find.text('Swipe'), const Offset(220, 0));
      await tester.pump();
      expect(find.text('Swipe'), findsNothing);

      showNibToast(context: ctx, title: 'Stay', duration: Duration.zero);
      await tester.pump();
      await tester.drag(find.text('Stay'), const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Stay'), findsOneWidget);
      await _cleanup(tester);
    });

    testWidgets('action button fires onAction and dismisses', (tester) async {
      await tester.pumpWidget(_harness());
      var acted = false;
      showNibToast(
        context: ctx,
        title: 'Deleted',
        actionLabel: 'Undo',
        onAction: () => acted = true,
        duration: Duration.zero,
      );
      await tester.pump();

      await tester.tap(find.text('Undo'));
      await tester.pump();

      expect(acted, isTrue);
      expect(find.text('Deleted'), findsNothing);
      await _cleanup(tester);
    });

    testWidgets('variant renders its icon', (tester) async {
      await tester.pumpWidget(_harness());
      showNibToast(
        context: ctx,
        title: 'Failed',
        variant: NibToastVariant.error,
        duration: Duration.zero,
      );
      await tester.pump();
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
      await _cleanup(tester);
    });

    testWidgets('different ids stack together', (tester) async {
      await tester.pumpWidget(_harness());
      showNibToast(context: ctx, id: 'a', title: 'AA', duration: Duration.zero);
      showNibToast(context: ctx, id: 'b', title: 'BB', duration: Duration.zero);
      await tester.pump();
      expect(find.text('AA'), findsOneWidget);
      expect(find.text('BB'), findsOneWidget);
      await _cleanup(tester);
    });

    testWidgets('exceeding maxVisible dismisses the oldest (FIFO)', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      for (var i = 0; i < 6; i++) {
        showNibToast(
          context: ctx,
          id: 't$i',
          title: 'T$i',
          duration: Duration.zero,
        );
      }
      await tester.pump();
      expect(find.text('T0'), findsNothing);
      expect(find.text('T5'), findsOneWidget);
      await _cleanup(tester);
    });

    testWidgets('dismissNibToast removes one; dismissAll clears', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      showNibToast(
        context: ctx,
        id: 'd1',
        title: 'D1',
        duration: Duration.zero,
      );
      showNibToast(
        context: ctx,
        id: 'd2',
        title: 'D2',
        duration: Duration.zero,
      );
      await tester.pump();

      dismissNibToast('d1');
      await tester.pump();
      expect(find.text('D1'), findsNothing);
      expect(find.text('D2'), findsOneWidget);

      dismissAllNibToasts();
      await tester.pump();
      expect(find.text('D2'), findsNothing);
    });

    testWidgets('animated:true builds NibMotion; animated:false builds none', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      showNibToast(
        context: ctx,
        title: 'NoAnim',
        animated: false,
        duration: Duration.zero,
      );
      await tester.pump();
      expect(find.byType(NibMotion), findsNothing);
      dismissAllNibToasts();
      await tester.pump();

      showNibToast(
        context: ctx,
        title: 'Anim',
        animated: true,
        duration: Duration.zero,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(NibMotion), findsWidgets);
      await _cleanup(tester);
    });

    testWidgets('position anchors the stack to the right corner', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      showNibToast(
        context: ctx,
        title: 'TL',
        position: NibToastPosition.topLeft,
        duration: Duration.zero,
      );
      await tester.pump();
      final screen = tester.getSize(find.byType(MaterialApp));
      final c = tester.getCenter(find.text('TL'));
      expect(c.dy, lessThan(screen.height / 2));
      expect(c.dx, lessThan(screen.width / 2));
      await _cleanup(tester);
    });

    test('enterOffset slides left/right horizontally and center vertically', () {
      expect(NibToastPosition.topLeft.enterOffset.dx, lessThan(0));
      expect(NibToastPosition.bottomLeft.enterOffset.dx, lessThan(0));
      expect(NibToastPosition.topRight.enterOffset.dx, greaterThan(0));
      expect(NibToastPosition.bottomRight.enterOffset.dx, greaterThan(0));
      // corners slide horizontally, not vertically
      expect(NibToastPosition.topRight.enterOffset.dy, 0);
      expect(NibToastPosition.bottomLeft.enterOffset.dy, 0);
      // centered positions slide vertically
      expect(NibToastPosition.topCenter.enterOffset, const Offset(0, -16));
      expect(NibToastPosition.bottomCenter.enterOffset.dy, greaterThan(0));
      expect(NibToastPosition.bottomCenter.enterOffset.dx, 0);
    });

    testWidgets('NibToaster enables context-free showNibToast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => NibToaster(child: child!),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );

      // No context passed — resolved via the registered NibToaster overlay.
      showNibToast(title: 'Global', duration: Duration.zero);
      await tester.pump();
      expect(find.text('Global'), findsOneWidget);
      await _cleanup(tester);
    });

    testWidgets('applies custom padding and borderRadius', (tester) async {
      await tester.pumpWidget(_harness());
      const pad = EdgeInsets.all(24);
      final radius = BorderRadius.circular(2);
      showNibToast(
        context: ctx,
        title: 'Styled',
        duration: Duration.zero,
        padding: pad,
        borderRadius: radius,
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text('Styled'), matching: find.byType(Container))
            .first,
      );
      expect(container.padding, pad);
      expect((container.decoration as BoxDecoration).borderRadius, radius);
      await _cleanup(tester);
    });
  });
}
