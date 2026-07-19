import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

/// Pumps an app whose single "open" button shows a dialog with the given params.
Widget _app({
  String? title,
  String? description,
  required Widget content,
  Widget? footer,
  bool barrierDismissible = true,
  bool showCloseButton = true,
  bool animated = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showNibDialog<Object?>(
              ctx,
              title: title,
              description: description,
              content: content,
              footer: footer,
              barrierDismissible: barrierDismissible,
              showCloseButton: showCloseButton,
              animated: animated,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

bool _focusInsideDialog() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  return ctx != null &&
      ctx.findAncestorWidgetOfExactType<NibDialogScope>() != null;
}

void main() {
  testWidgets('renders title, content, footer, and a close button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        title: 'Delete?',
        content: const Text('body'),
        footer: const Text('foot'),
      ),
    );
    await _open(tester);

    expect(find.text('Delete?'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
    expect(find.text('foot'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('close button dismisses the dialog', (tester) async {
    await tester.pumpWidget(_app(content: const Text('body')));
    await _open(tester);
    expect(find.text('body'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('body'), findsNothing);
  });

  testWidgets('barrier tap dismisses when barrierDismissible', (tester) async {
    await tester.pumpWidget(_app(content: const Text('body')));
    await _open(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('body'), findsNothing);
  });

  testWidgets('barrier tap does nothing when not dismissible', (tester) async {
    await tester.pumpWidget(
      _app(content: const Text('body'), barrierDismissible: false),
    );
    await _open(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('Escape dismisses when dismissible', (tester) async {
    await tester.pumpWidget(_app(content: const Text('body')));
    await _open(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('body'), findsNothing);
  });

  testWidgets('Escape does nothing when not dismissible', (tester) async {
    await tester.pumpWidget(
      _app(content: const Text('body'), barrierDismissible: false),
    );
    await _open(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('traps focus inside the dialog on Tab', (tester) async {
    await tester.pumpWidget(
      _app(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: () {}, child: const Text('one')),
            TextButton(onPressed: () {}, child: const Text('two')),
          ],
        ),
      ),
    );
    await _open(tester);

    expect(
      _focusInsideDialog(),
      isTrue,
      reason: 'autofocus should land inside the dialog',
    );
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        _focusInsideDialog(),
        isTrue,
        reason: 'Tab must not escape the dialog',
      );
    }
  });

  testWidgets('stacking: Escape closes only the topmost dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        content: Builder(
          builder: (ctx) => TextButton(
            onPressed: () =>
                showNibDialog<void>(ctx, content: const Text('B body')),
            child: const Text('open B'),
          ),
        ),
      ),
    );
    // Dialog A is opened by the app's "open" button; give A a marker too.
    await _open(tester);
    await tester.tap(find.text('open B'));
    await tester.pumpAndSettle();

    expect(find.text('open B'), findsOneWidget); // A still there
    expect(find.text('B body'), findsOneWidget); // B on top

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('B body'), findsNothing); // B closed
    expect(find.text('open B'), findsOneWidget); // A survives
  });

  testWidgets('animated:false builds zero NibMotion widgets', (tester) async {
    await tester.pumpWidget(_app(content: const Text('body'), animated: false));
    await _open(tester);
    expect(find.byType(NibMotion), findsNothing);
  });

  testWidgets('animated:true builds NibMotion widgets', (tester) async {
    await tester.pumpWidget(_app(content: const Text('body'), animated: true));
    await tester.tap(find.text('open'));
    await tester.pump(); // first frame of the entrance
    expect(find.byType(NibMotion), findsWidgets);
    await tester.pumpAndSettle();
  });

  testWidgets('tall content scrolls without overflowing', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(content: const SizedBox(height: 2000, child: Text('tall'))),
    );
    await _open(tester);
    expect(find.byType(Scrollable), findsWidgets);
  });

  testWidgets('clamps width to a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(300, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        content: const SizedBox(
          key: Key('body'),
          width: double.infinity,
          height: 40,
        ),
      ),
    );
    await _open(tester);

    // card maxWidth <= 300 - 48 margins = 252; body inner = card - 40 padding.
    final w = tester.getSize(find.byKey(const Key('body'))).width;
    expect(w, lessThanOrEqualTo(212.5));
  });

  testWidgets('respects the size ceiling on a wide viewport', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        content: const SizedBox(
          key: Key('body'),
          width: double.infinity,
          height: 40,
        ),
      ),
    );
    await _open(tester);

    // md ceiling 512, minus 40 card padding = 472.
    final w = tester.getSize(find.byKey(const Key('body'))).width;
    expect(w, closeTo(472, 1));
  });

  testWidgets('showNibDialog completes with the scope close result', (
    tester,
  ) async {
    Object? result = 'unset';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await showNibDialog<bool>(
                    ctx,
                    content: Builder(
                      builder: (dctx) => TextButton(
                        onPressed: () => NibDialogScope.of(dctx).close(true),
                        child: const Text('confirm'),
                      ),
                    ),
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
    await tester.tap(find.text('confirm'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('openNibDialog handle reports isOpen and closes with a result', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final handle = openNibDialog<int>(ctx, content: const Text('x'));
    await tester.pumpAndSettle();
    expect(handle.isOpen, isTrue);

    handle.close(42);
    await tester.pumpAndSettle();
    expect(await handle.closed, 42);
    expect(handle.isOpen, isFalse);
  });
}
