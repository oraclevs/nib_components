import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('NibCard — render', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(_wrap(
        const NibCard(child: Text('Content')),
      ));
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('renders header and footer with dividers', (tester) async {
      await tester.pumpWidget(_wrap(
        const NibCard(
          header: Text('Header'),
          footer: Text('Footer'),
          child: Text('Body'),
        ),
      ));
      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('Footer'), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('no divider when only child is set', (tester) async {
      await tester.pumpWidget(_wrap(
        const NibCard(child: Text('Body')),
      ));
      expect(find.byType(Divider), findsNothing);
    });
  });

  group('NibCard — interactive', () {
    testWidgets('static (non-interactive) card has no InkWell', (tester) async {
      await tester.pumpWidget(_wrap(
        const NibCard(child: Text('Content')),
      ));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('interactive: true renders an InkWell and fires onTap',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        NibCard(
          interactive: true,
          onTap: () => taps++,
          child: const Text('Content'),
        ),
      ));
      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.text('Content'));
      expect(taps, 1);
    });

    testWidgets('disabled: true blocks onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        NibCard(
          interactive: true,
          disabled: true,
          onTap: () => taps++,
          child: const Text('Content'),
        ),
      ));
      await tester.tap(find.text('Content'));
      expect(taps, 0);
    });

    testWidgets('null onTap renders disabled (no crash on tap)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const NibCard(interactive: true, child: Text('Content')),
      ));
      await tester.tap(find.text('Content'));
      expect(tester.takeException(), isNull);
    });
  });

  group('NibCard — animated', () {
    testWidgets('animated: false builds zero NibMotion', (tester) async {
      await tester.pumpWidget(_wrap(
        NibCard(
          interactive: true,
          onTap: () {},
          child: const Text('Content'),
        ),
      ));
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('animated: true on a non-interactive card builds zero '
        'NibMotion', (tester) async {
      await tester.pumpWidget(_wrap(
        const NibCard(animated: true, child: Text('Content')),
      ));
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('animated: true + interactive: true wraps in NibMotion',
        (tester) async {
      await tester.pumpWidget(_wrap(
        NibCard(
          interactive: true,
          animated: true,
          onTap: () {},
          child: const Text('Content'),
        ),
      ));
      expect(find.byType(NibMotion), findsOneWidget);
    });
  });
}
