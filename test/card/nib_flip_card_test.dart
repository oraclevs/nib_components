import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibFlip;

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('NibFlipCard — render', () {
    testWidgets('renders a NibFlip with the given front/back', (tester) async {
      await tester.pumpWidget(
        _wrap(const NibFlipCard(front: Text('Question'), back: Text('Answer'))),
      );
      expect(find.byType(NibFlip), findsOneWidget);
      expect(find.text('Question'), findsOneWidget);
      expect(find.text('Answer'), findsOneWidget);
    });
  });

  group('NibFlipCard — uncontrolled (tap-to-flip)', () {
    testWidgets('starts showing front, flips to back on tap', (tester) async {
      await tester.pumpWidget(
        _wrap(const NibFlipCard(front: Text('Question'), back: Text('Answer'))),
      );
      final flip = tester.widget<NibFlip>(find.byType(NibFlip));
      expect(flip.isFlipped, isFalse);

      await tester.tap(find.text('Question'));
      await tester.pump();

      final flipAfter = tester.widget<NibFlip>(find.byType(NibFlip));
      expect(flipAfter.isFlipped, isTrue);
    });

    testWidgets('tappable: false disables tap-to-flip', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibFlipCard(
            front: Text('Question'),
            back: Text('Answer'),
            tappable: false,
          ),
        ),
      );
      await tester.tap(find.text('Question'));
      await tester.pump();
      final flip = tester.widget<NibFlip>(find.byType(NibFlip));
      expect(flip.isFlipped, isFalse);
    });

    testWidgets('onFlippedChanged fires on tap even when uncontrolled', (
      tester,
    ) async {
      bool? got;
      await tester.pumpWidget(
        _wrap(
          NibFlipCard(
            front: const Text('Question'),
            back: const Text('Answer'),
            onFlippedChanged: (v) => got = v,
          ),
        ),
      );
      await tester.tap(find.text('Question'));
      await tester.pump();
      expect(got, isTrue);
    });
  });

  group('NibFlipCard — controlled', () {
    testWidgets('isFlipped drives NibFlip directly', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibFlipCard(
            front: Text('Question'),
            back: Text('Answer'),
            isFlipped: true,
          ),
        ),
      );
      final flip = tester.widget<NibFlip>(find.byType(NibFlip));
      expect(flip.isFlipped, isTrue);
    });

    testWidgets('tapping a controlled card does not flip itself — only '
        'calls onFlippedChanged', (tester) async {
      bool? got;
      await tester.pumpWidget(
        _wrap(
          NibFlipCard(
            front: const Text('Question'),
            back: const Text('Answer'),
            isFlipped: false,
            onFlippedChanged: (v) => got = v,
          ),
        ),
      );
      await tester.tap(find.text('Question'));
      await tester.pump();
      expect(got, isTrue);
      // isFlipped is still false (the consumer hasn't updated it), so the
      // widget must still report false — it never mutates itself.
      final flip = tester.widget<NibFlip>(find.byType(NibFlip));
      expect(flip.isFlipped, isFalse);
    });
  });

  group('NibFlipCard — axis', () {
    testWidgets('flipAxis passes straight through to NibFlip', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibFlipCard(
            front: Text('Question'),
            back: Text('Answer'),
            flipAxis: Axis.vertical,
          ),
        ),
      );
      final flip = tester.widget<NibFlip>(find.byType(NibFlip));
      expect(flip.flipAxis, Axis.vertical);
    });

    testWidgets('defaults to Axis.horizontal', (tester) async {
      await tester.pumpWidget(
        _wrap(const NibFlipCard(front: Text('Question'), back: Text('Answer'))),
      );
      final flip = tester.widget<NibFlip>(find.byType(NibFlip));
      expect(flip.flipAxis, Axis.horizontal);
    });
  });

  group('NibFlipCard — semantics', () {
    testWidgets('front face carries toggled + button semantics when tappable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const NibFlipCard(
            front: Text('Question'),
            back: Text('Answer'),
            frontSemanticLabel: 'Flashcard question',
          ),
        ),
      );
      final node = tester.getSemantics(find.text('Question'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isToggled, Tristate.isFalse);
      expect(node.label, contains('Flashcard question'));
    });
  });
}
