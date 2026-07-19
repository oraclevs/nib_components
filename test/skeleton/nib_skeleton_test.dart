import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart'
    show NibMotion, NibShimmer, NibPresence;

Widget _wrap(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('NibSkeleton — loading passthrough', () {
    testWidgets('loading: false renders child untouched, no bone boxes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const NibSkeleton(loading: false, child: Text('real content'))),
      );
      expect(find.text('real content'), findsOneWidget);
      expect(find.byType(DecoratedBox), findsNothing);
    });

    testWidgets('loading: true shades the child into bone boxes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const NibSkeleton(loading: true, child: Text('real content'))),
      );
      expect(find.text('real content'), findsNothing);
      expect(find.byType(DecoratedBox), findsOneWidget);
    });
  });

  group('NibSkeleton — animated contract', () {
    testWidgets(
      'animated: false builds zero NibMotion/NibShimmer/NibPresence, loading or not',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const NibSkeleton(loading: true, child: Text('x'))),
        );
        expect(find.byType(NibMotion), findsNothing);
        expect(find.byType(NibShimmer), findsNothing);
        expect(find.byType(NibPresence), findsNothing);

        await tester.pumpWidget(
          _wrap(const NibSkeleton(loading: false, child: Text('x'))),
        );
        expect(find.byType(NibMotion), findsNothing);
        expect(find.byType(NibShimmer), findsNothing);
        expect(find.byType(NibPresence), findsNothing);
      },
    );

    testWidgets(
      'animated: true wraps the bone tree in NibShimmer while loading',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const NibSkeleton(loading: true, animated: true, child: Text('x')),
          ),
        );
        expect(find.byType(NibShimmer), findsOneWidget);
        expect(find.byType(NibPresence), findsOneWidget);
      },
    );

    testWidgets(
      'animated: true gives each bone box its own NibShimmer, not one around the whole tree '
      '(regression for the "flattens into one rectangle" bug)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const NibSkeleton(
              loading: true,
              animated: true,
              child: Row(
                children: [
                  CircleAvatar(radius: 20),
                  Text('Name'),
                  Text('Subtitle'),
                ],
              ),
            ),
          ),
        );
        // 3 leaves (CircleAvatar + 2 Text) -> 3 independent bone boxes, each
        // with its own NibShimmer.
        expect(find.byType(NibShimmer), findsNWidgets(3));
        expect(find.byType(DecoratedBox), findsNWidgets(3));
      },
    );

    testWidgets('animated: true still uses NibPresence when not loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const NibSkeleton(loading: false, animated: true, child: Text('x')),
        ),
      );
      expect(find.byType(NibPresence), findsOneWidget);
      expect(find.byType(NibShimmer), findsNothing);
      expect(find.text('x'), findsOneWidget);
    });
  });

  group('NibSkeleton — theme defaults', () {
    testWidgets(
      'default baseColor/shimmerColor resolve from NibTheme, not a hardcoded hex',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const NibSkeleton(loading: true, child: Text('x'))),
        );
        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox).first,
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.color, NibTheme.light.muted);
      },
    );

    testWidgets('explicit baseColor overrides the theme default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const NibSkeleton(
            loading: true,
            baseColor: Color(0xFF123456),
            child: Text('x'),
          ),
        ),
      );
      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF123456));
    });
  });

  group('NibSkeleton — interaction gating', () {
    testWidgets('taps inside the bone tree are inert while loading', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          NibSkeleton(
            loading: true,
            child: GestureDetector(
              onTap: () => tapped = true,
              child: const Text('tap me'),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(IgnorePointer).first, warnIfMissed: false);
      expect(tapped, isFalse);
    });

    testWidgets('taps work normally once not loading', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          NibSkeleton(
            loading: false,
            child: GestureDetector(
              onTap: () => tapped = true,
              child: const Text('tap me'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('tap me'));
      expect(tapped, isTrue);
    });
  });
}
