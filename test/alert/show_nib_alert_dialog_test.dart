import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('showNibAlertDialog — Material (default)', () {
    testWidgets('renders title, description, and default OK/Cancel', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    title: 'Delete file?',
                    description: 'This cannot be undone.',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      expect(find.text('Delete file?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      // No corner close-X — Cancel already covers explicit dismissal,
      // matching Flutter's own AlertDialog (never shows one).
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('confirm resolves true and calls onConfirm', (tester) async {
      bool? result = false;
      var confirmed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () async {
                    result = await showNibAlertDialog(
                      ctx,
                      description: 'Proceed?',
                      onConfirm: () => confirmed++,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(confirmed, 1);
    });

    testWidgets('cancel resolves false and calls onCancel', (tester) async {
      bool? result = true;
      var cancelled = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () async {
                    result = await showNibAlertDialog(
                      ctx,
                      description: 'Proceed?',
                      onCancel: () => cancelled++,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(cancelled, 1);
    });

    testWidgets('barrier dismiss resolves null', (tester) async {
      Object? result = 'unset';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () async {
                    result = await showNibAlertDialog(ctx, description: 'Hi');
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('cancelText: null renders a single confirm-only button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    description: 'Got it?',
                    cancelText: null,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('content overrides title/description', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    title: 'Ignored',
                    content: const Text('Custom body'),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      expect(find.text('Ignored'), findsNothing);
      expect(find.text('Custom body'), findsOneWidget);
    });

    testWidgets('actions overrides the whole button row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    description: 'Custom actions',
                    actions: [
                      Builder(
                        builder: (dctx) => TextButton(
                          onPressed: () => NibDialogScope.of(dctx).close('x'),
                          child: const Text('Custom'),
                        ),
                      ),
                    ],
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      expect(find.text('OK'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('severity: error switches the confirm button to destructive', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    description: 'Delete?',
                    severity: NibAlertSeverity.error,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      final confirm = tester.widget<NibButton>(
        find.widgetWithText(NibButton, 'OK'),
      );
      expect(confirm.variant, NibButtonVariant.destructive);
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    });

    testWidgets('icon overrides the severity default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    description: 'Custom icon',
                    severity: NibAlertSeverity.error,
                    icon: const Icon(Icons.star),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.error_rounded), findsNothing);
    });

    testWidgets('iconColor tints the severity default icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    description: 'Tinted icon',
                    severity: NibAlertSeverity.error,
                    iconColor: Colors.purple,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_rounded));
      expect(icon.color, Colors.purple);
    });

    testWidgets('titleTextStyle/descriptionTextStyle merge onto the defaults', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    title: 'Styled title',
                    description: 'Styled description',
                    titleTextStyle: const TextStyle(
                      fontStyle: FontStyle.italic,
                    ),
                    descriptionTextStyle: const TextStyle(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      final title = tester.widget<Text>(find.text('Styled title'));
      final description = tester.widget<Text>(find.text('Styled description'));
      expect(title.style?.fontStyle, FontStyle.italic);
      // The default bold weight survives the merge (not clobbered).
      expect(title.style?.fontWeight, FontWeight.w600);
      expect(description.style?.decoration, TextDecoration.underline);
    });

    testWidgets('actionsAlignment applies to the default action row', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    description: 'Centered actions',
                    actionsAlignment: MainAxisAlignment.center,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      final bar = tester.widget<OverflowBar>(find.byType(OverflowBar));
      expect(bar.alignment, MainAxisAlignment.center);
    });

    testWidgets(
      'a wide custom actions row does not overflow at the dialog width',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => showNibAlertDialog(
                      ctx,
                      description: 'Many actions',
                      actions: [
                        for (final label in [
                          'Save as draft',
                          'Save and publish',
                          'Discard changes',
                          'Cancel',
                        ])
                          Builder(
                            builder: (dctx) => NibButton(
                              label: label,
                              onPressed: () =>
                                  NibDialogScope.of(dctx).close(true),
                            ),
                          ),
                      ],
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await _open(tester);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('cancelVariant/confirmVariant override the default button '
        'styles', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    description: 'Proceed?',
                    cancelVariant: NibButtonVariant.ghost,
                    confirmVariant: NibButtonVariant.secondary,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      final cancel = tester.widget<NibButton>(
        find.widgetWithText(NibButton, 'Cancel'),
      );
      final confirm = tester.widget<NibButton>(
        find.widgetWithText(NibButton, 'OK'),
      );
      expect(cancel.variant, NibButtonVariant.ghost);
      expect(confirm.variant, NibButtonVariant.secondary);
    });

    testWidgets(
      'confirmVariant overrides the severity-driven destructive default',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => showNibAlertDialog(
                      ctx,
                      description: 'Delete?',
                      severity: NibAlertSeverity.error,
                      confirmVariant: NibButtonVariant.primary,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await _open(tester);

        final confirm = tester.widget<NibButton>(
          find.widgetWithText(NibButton, 'OK'),
        );
        expect(confirm.variant, NibButtonVariant.primary);
      },
    );

    testWidgets('buttonPadding applies to both default actions', (
      tester,
    ) async {
      const padding = EdgeInsets.symmetric(horizontal: 24, vertical: 10);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    description: 'Proceed?',
                    buttonPadding: padding,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      final cancel = tester.widget<NibButton>(
        find.widgetWithText(NibButton, 'Cancel'),
      );
      final confirm = tester.widget<NibButton>(
        find.widgetWithText(NibButton, 'OK'),
      );
      expect(cancel.padding, padding);
      expect(confirm.padding, padding);
    });

    testWidgets('buttonWidth forces both default actions to the same width', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    title: 'Delete file?',
                    description: 'This cannot be undone.',
                    confirmText: 'Delete',
                    buttonWidth: 120,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      final cancelWidth = tester
          .getSize(find.widgetWithText(NibButton, 'Cancel'))
          .width;
      final confirmWidth = tester
          .getSize(find.widgetWithText(NibButton, 'Delete'))
          .width;
      expect(cancelWidth, 120);
      expect(confirmWidth, 120);
    });

    testWidgets('cancelFirst: false puts Confirm before Cancel', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    description: 'Proceed?',
                    cancelFirst: false,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      final confirmX = tester
          .getTopLeft(find.widgetWithText(NibButton, 'OK'))
          .dx;
      final cancelX = tester
          .getTopLeft(find.widgetWithText(NibButton, 'Cancel'))
          .dx;
      expect(confirmX, lessThan(cancelX));
    });

    testWidgets('adaptive: true on Android keeps the Material layout', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    description: 'Proceed?',
                    adaptive: true,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      expect(find.byType(NibButton), findsNWidgets(2));
      expect(find.byIcon(Icons.close), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('showNibAlertDialog — Cupertino (adaptive: true on iOS/macOS)', () {
    testWidgets('renders centered title/description, no close button, no '
        'NibButton row', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    title: 'Delete file?',
                    description: 'This cannot be undone.',
                    adaptive: true,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      expect(find.text('Delete file?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byType(NibButton), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('confirm resolves true, cancel resolves false', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () async {
                    result = await showNibAlertDialog(
                      ctx,
                      description: 'Proceed?',
                      adaptive: true,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('keyboard Enter activates a focused Cupertino action', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () async {
                    result = await showNibAlertDialog(
                      ctx,
                      description: 'Proceed?',
                      adaptive: true,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      // Focus the confirm action directly (roving focus not required here —
      // just prove ActivateIntent wiring works).
      final focusNode = Focus.of(tester.element(find.text('OK')));
      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(result, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('cancelText: null renders a single full-width action', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    description: 'Got it?',
                    cancelText: null,
                    adaptive: true,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Cupertino actions have button semantics', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    description: 'Proceed?',
                    adaptive: true,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      expect(find.bySemanticsLabel('OK'), findsOneWidget);
      expect(find.bySemanticsLabel('Cancel'), findsOneWidget);
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('cancelFirst: false swaps the Cupertino action order too', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    description: 'Proceed?',
                    adaptive: true,
                    cancelFirst: false,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      final confirmX = tester.getTopLeft(find.text('OK')).dx;
      final cancelX = tester.getTopLeft(find.text('Cancel')).dx;
      expect(confirmX, lessThan(cancelX));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('buttonPadding applies to the Cupertino action row', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(
                    ctx,
                    description: 'Proceed?',
                    adaptive: true,
                    buttonPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 24,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      final padding = tester.widget<Padding>(
        find
            .ancestor(of: find.text('OK'), matching: find.byType(Padding))
            .first,
      );
      expect(
        padding.padding,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      );
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('showNibAlertDialog — validation', () {
    testWidgets('asserts when title/description/content are all null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showNibAlertDialog(ctx),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      expect(tester.takeException(), isAssertionError);
    });
  });

  group('showNibAlertDialog — no unwanted autofocus ring', () {
    testWidgets('nothing is focused (no ring/highlight) immediately after the '
        'dialog opens — Material', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () =>
                      showNibAlertDialog(ctx, description: 'Proceed?'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      // Neither action button holds focus — the invisible sink absorbed
      // showNibDialog's initial autofocus instead, so no NibButton shows a
      // focus ring on open.
      final focused = FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<NibButton>();
      expect(focused, isNull);
    });

    testWidgets('the first Tab press still focuses Cancel normally', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () =>
                      showNibAlertDialog(ctx, description: 'Proceed?'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final focused = FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<NibButton>();
      expect(focused?.label, 'Cancel');
    });

    testWidgets(
      'nothing is focused immediately after the dialog opens — Cupertino',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => showNibAlertDialog(
                      ctx,
                      description: 'Proceed?',
                      adaptive: true,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await _open(tester);

        // Neither Cupertino action shows its focus/hover highlight (a
        // ColoredBox tinted `theme.muted`) right after opening.
        final theme = NibTheme.of(tester.element(find.text('OK')));
        for (final label in ['OK', 'Cancel']) {
          final box = tester.widget<ColoredBox>(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(ColoredBox),
                )
                .first,
          );
          expect(box.color, isNot(theme.muted));
        }
        debugDefaultTargetPlatformOverride = null;
      },
    );
  });
}
