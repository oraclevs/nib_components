import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// The single fill/border [DecoratedBox] that is the button's *visual* box
/// (not the focus-ring overlay, which only exists while focused).
Finder _visualBox() => find
    .descendant(
      of: find.byType(NibButton),
      matching: find.byWidgetPredicate(
        (w) => w is DecoratedBox && w.decoration is BoxDecoration,
      ),
    )
    .first;

BoxDecoration _deco(WidgetTester t) =>
    t.widget<DecoratedBox>(_visualBox()).decoration as BoxDecoration;

void main() {
  group('NibButton — basics', () {
    testWidgets('renders its label', (tester) async {
      await tester.pumpWidget(
        _wrap(NibButton(label: 'Save', onPressed: () {})),
      );
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(NibButton(label: 'Save', onPressed: () => taps++)),
      );
      await tester.tap(find.byType(NibButton));
      expect(taps, 1);
    });

    testWidgets('long label ellipsizes in a narrow parent (no overflow)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 80,
            child: NibButton(
              label: 'A very long label that far exceeds the width',
              onPressed: () {},
            ),
          ),
        ),
      );
      // A RenderFlex overflow throws in tests; reaching here means it didn't.
      expect(tester.takeException(), isNull);
    });
  });

  group('NibButton — variants', () {
    testWidgets('primary fills with the primary token', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibButton(
            label: 'x',
            onPressed: () {},
            variant: NibButtonVariant.primary,
          ),
        ),
      );
      expect(_deco(tester).color, NibTheme.light.primary);
    });

    testWidgets('outline is transparent with a border token', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibButton(
            label: 'x',
            onPressed: () {},
            variant: NibButtonVariant.outline,
          ),
        ),
      );
      final d = _deco(tester);
      expect(d.color, Colors.transparent);
      expect(d.border!.top.color, NibTheme.light.border);
    });

    testWidgets('destructive fills with the destructive token', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibButton(
            label: 'x',
            onPressed: () {},
            variant: NibButtonVariant.destructive,
          ),
        ),
      );
      expect(_deco(tester).color, NibTheme.light.destructive);
    });

    testWidgets('every variant renders without error', (tester) async {
      for (final v in NibButtonVariant.values) {
        await tester.pumpWidget(
          _wrap(NibButton(label: v.name, onPressed: () {}, variant: v)),
        );
        expect(find.text(v.name), findsOneWidget);
      }
    });
  });

  group('NibButton — sizing & geometry', () {
    testWidgets('md preset renders a 44px-tall visual box', (tester) async {
      await tester.pumpWidget(_wrap(NibButton(label: 'x', onPressed: () {})));
      expect(tester.getSize(_visualBox()).height, 44);
    });

    testWidgets('sm/md keep a >=48px tap target despite a shorter visual', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NibButton(label: 'x', onPressed: () {}, size: NibButtonSize.sm)),
      );
      expect(tester.getSize(_visualBox()).height, 36);
      expect(
        tester.getSize(find.byType(NibButton)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('custom height/width sets the visual box exactly', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NibButton(label: 'x', onPressed: () {}, height: 60, width: 200)),
      );
      expect(tester.getSize(_visualBox()), const Size(200, 60));
    });

    testWidgets('filled 44x44 and outline 44x44 are the identical size', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibButton(
            label: 'x',
            onPressed: () {},
            width: 44,
            height: 44,
            variant: NibButtonVariant.primary,
          ),
        ),
      );
      final filled = tester.getSize(_visualBox());

      await tester.pumpWidget(
        _wrap(
          NibButton(
            label: 'x',
            onPressed: () {},
            width: 44,
            height: 44,
            variant: NibButtonVariant.outline,
          ),
        ),
      );
      final outline = tester.getSize(_visualBox());

      expect(filled, const Size(44, 44));
      expect(outline, filled); // border is inset — never grows the box
    });

    testWidgets('expand stretches to the parent width', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 300,
            child: NibButton(label: 'x', onPressed: () {}, expand: true),
          ),
        ),
      );
      expect(tester.getSize(_visualBox()).width, 300);
    });

    testWidgets('pill uses the pill radius', (tester) async {
      await tester.pumpWidget(
        _wrap(NibButton(label: 'x', onPressed: () {}, pill: true)),
      );
      final r = _deco(tester).borderRadius as BorderRadius;
      expect(r.topLeft.x, NibTheme.light.radiusPill);
    });

    testWidgets('custom borderRadius overrides the default and pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibButton(
            label: 'x',
            onPressed: () {},
            pill: true,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
      final r = _deco(tester).borderRadius as BorderRadius;
      expect(r.topLeft.x, 2);
    });

    testWidgets('custom padding is applied to the content', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibButton(
            label: 'x',
            onPressed: () {},
            padding: const EdgeInsets.all(24),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(NibButton),
          matching: find.byWidgetPredicate(
            (w) => w is Padding && w.padding == const EdgeInsets.all(24),
          ),
        ),
        findsOneWidget,
      );
    });
  });

  group('NibButton — loading', () {
    testWidgets('shows the loader and hides — but keeps — the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NibButton(label: 'Save', onPressed: () {}, loading: true)),
      );
      expect(find.byType(NibCircularLoader), findsOneWidget);
      // The label is kept in the tree (to reserve the button's width) but is
      // not painted.
      final vis = tester.widget<Visibility>(
        find.ancestor(of: find.text('Save'), matching: find.byType(Visibility)),
      );
      expect(vis.visible, isFalse);
    });

    testWidgets('keeps its content-sized width when it starts loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NibButton(label: 'Save changes', onPressed: () {})),
      );
      final normal = tester.getSize(_visualBox());

      await tester.pumpWidget(
        _wrap(
          NibButton(label: 'Save changes', onPressed: () {}, loading: true),
        ),
      );
      final loading = tester.getSize(_visualBox());

      expect(loading, normal); // no shrink when the loader appears
    });

    testWidgets('blocks taps while loading', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(NibButton(label: 'Save', onPressed: () => taps++, loading: true)),
      );
      await tester.tap(find.byType(NibButton), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('loadingWidget only overrides the built-in loader', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibButton(
            label: 'Save',
            onPressed: () {},
            loading: true,
            loadingWidget: const Icon(Icons.sync),
          ),
        ),
      );
      expect(find.byType(NibCircularLoader), findsNothing);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('loadingText renders beside the default spinner', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibButton(
            label: 'Save',
            onPressed: () {},
            loading: true,
            loadingText: 'Saving…',
          ),
        ),
      );
      expect(find.byType(NibCircularLoader), findsOneWidget);
      expect(find.text('Saving…'), findsOneWidget);
    });

    testWidgets(
      'loadingWidget + loadingText render together (no default spinner)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            NibButton(
              label: 'Save',
              onPressed: () {},
              loading: true,
              loadingWidget: const Icon(Icons.sync),
              loadingText: 'Syncing',
            ),
          ),
        );
        expect(find.byType(NibCircularLoader), findsNothing);
        expect(find.byIcon(Icons.sync), findsOneWidget);
        expect(find.text('Syncing'), findsOneWidget);
      },
    );
  });

  group('NibButton — disabled', () {
    testWidgets('disabled blocks taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          NibButton(label: 'Save', onPressed: () => taps++, disabled: true),
        ),
      );
      await tester.tap(find.byType(NibButton), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('null onPressed is treated as disabled', (tester) async {
      await tester.pumpWidget(
        _wrap(const NibButton(label: 'Save', onPressed: null)),
      );
      await tester.tap(find.byType(NibButton), warnIfMissed: false);
      // No callback to fire; assert the semantics report it disabled.
      expect(
        tester.getSemantics(find.byType(NibButton)),
        isSemantics(isEnabled: false),
      );
    });
  });

  group('NibButton — keyboard & semantics', () {
    testWidgets('is a semantic button carrying the label', (tester) async {
      await tester.pumpWidget(
        _wrap(NibButton(label: 'Save', onPressed: () {})),
      );
      expect(
        tester.getSemantics(find.byType(NibButton)),
        isSemantics(isButton: true, label: 'Save'),
      );
    });

    testWidgets('Enter activates a focused button', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          NibButton(label: 'Save', onPressed: () => taps++, autofocus: true),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('NibButton — icon-only', () {
    testWidgets('renders a single icon with no label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibButton(
            onPressed: () {},
            leadingIcon: const Icon(Icons.add),
            semanticLabel: 'Add',
          ),
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
      final node = tester.getSemantics(find.byType(NibButton));
      expect(node.label, 'Add');
    });

    testWidgets('asserts when nothing to render is given', (tester) async {
      expect(() => NibButton(onPressed: () {}), throwsAssertionError);
    });

    testWidgets('asserts when label is null without a semanticLabel', (
      tester,
    ) async {
      expect(
        () => NibButton(onPressed: () {}, leadingIcon: const Icon(Icons.add)),
        throwsAssertionError,
      );
    });
  });

  group('NibButton — custom content', () {
    testWidgets('renders a fully custom child', (tester) async {
      await tester.pumpWidget(
        _wrap(NibButton(onPressed: () {}, content: const Text('CUSTOM'))),
      );
      expect(find.text('CUSTOM'), findsOneWidget);
    });

    testWidgets('content takes precedence over label/icons', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibButton(
            label: 'ignored',
            leadingIcon: const Icon(Icons.star),
            onPressed: () {},
            content: const Text('CUSTOM'),
          ),
        ),
      );
      expect(find.text('CUSTOM'), findsOneWidget);
      expect(find.text('ignored'), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('a content button is still tappable', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          NibButton(
            onPressed: () => taps++,
            content: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.bolt), Text('Go')],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(NibButton));
      expect(taps, 1);
    });

    testWidgets('content alone needs no semanticLabel', (tester) async {
      // Should not throw the icon-only assertion.
      expect(
        () => NibButton(onPressed: () {}, content: const SizedBox()),
        returnsNormally,
      );
    });

    testWidgets('content keeps the button size while loading', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibButton(
            onPressed: () {},
            content: const SizedBox(width: 140, height: 40),
          ),
        ),
      );
      final normal = tester.getSize(_visualBox());

      await tester.pumpWidget(
        _wrap(
          NibButton(
            onPressed: () {},
            loading: true,
            content: const SizedBox(width: 140, height: 40),
          ),
        ),
      );
      expect(tester.getSize(_visualBox()), normal);
    });
  });

  group('NibButton — animation (opt-in)', () {
    testWidgets('builds zero NibMotion when animated is false', (tester) async {
      await tester.pumpWidget(_wrap(NibButton(label: 'x', onPressed: () {})));
      expect(find.byType(NibMotion), findsNothing);
      await tester.tap(find.byType(NibButton));
      await tester.pump();
      expect(find.byType(NibMotion), findsNothing);
    });

    testWidgets('wraps content in NibMotion when animated', (tester) async {
      await tester.pumpWidget(
        _wrap(NibButton(label: 'x', onPressed: () {}, animated: true)),
      );
      expect(find.byType(NibMotion), findsOneWidget);
    });
  });
}
