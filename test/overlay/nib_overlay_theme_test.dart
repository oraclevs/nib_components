import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

const _nestedPrimary = Color(0xFFEA7C21);

Widget _host(void Function(BuildContext) open) => MaterialApp(
  theme: ThemeData(extensions: const [NibTheme.light]),
  home: Theme(
    data: ThemeData(
      extensions: [NibTheme.light.copyWith(primary: _nestedPrimary)],
    ),
    child: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => open(context),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

Widget _switchingHost(
  ValueNotifier<NibTheme> palette,
  void Function(BuildContext) open,
) => ValueListenableBuilder<NibTheme>(
  valueListenable: palette,
  builder: (context, value, _) => MaterialApp(
    theme: ThemeData(extensions: [value]),
    home: Theme(
      data: ThemeData(extensions: [value.copyWith(primary: _nestedPrimary)]),
      child: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

Widget _removableHost(
  ValueNotifier<NibTheme> palette,
  ValueNotifier<bool> showingOpener,
  void Function(BuildContext) open,
) => ValueListenableBuilder<NibTheme>(
  valueListenable: palette,
  builder: (context, value, _) => MaterialApp(
    theme: ThemeData(extensions: [value]),
    home: ValueListenableBuilder<bool>(
      valueListenable: showingOpener,
      builder: (context, showing, _) => Scaffold(
        body: showing
            ? Theme(
                data: ThemeData(
                  extensions: [value.copyWith(primary: _nestedPrimary)],
                ),
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => open(context),
                    child: const Text('open'),
                  ),
                ),
              )
            : const Text('opener removed'),
      ),
    ),
  ),
);

void _expectLiveNestedTheme(WidgetTester tester, String text, NibTheme theme) {
  final overlayTheme = NibTheme.of(tester.element(find.text(text)));
  expect(overlayTheme.card, theme.card);
  expect(overlayTheme.foreground, theme.foreground);
  expect(overlayTheme.primary, _nestedPrimary);
}

void main() {
  testWidgets('dialog follows root theme changes while open', (tester) async {
    final palette = ValueNotifier<NibTheme>(NibTheme.light);
    await tester.pumpWidget(
      _switchingHost(palette, (context) {
        showNibDialog<void>(context, content: const Text('live dialog'));
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    _expectLiveNestedTheme(tester, 'live dialog', NibTheme.light);
    palette.value = NibTheme.dark;
    await tester.pumpAndSettle();
    _expectLiveNestedTheme(tester, 'live dialog', NibTheme.dark);
    palette.dispose();
  });

  testWidgets('bottom sheet follows root theme changes while open', (
    tester,
  ) async {
    final palette = ValueNotifier<NibTheme>(NibTheme.light);
    await tester.pumpWidget(
      _switchingHost(palette, (context) {
        showNibBottomSheet<void>(context, content: const Text('live sheet'));
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    _expectLiveNestedTheme(tester, 'live sheet', NibTheme.light);
    palette.value = NibTheme.dark;
    await tester.pumpAndSettle();
    _expectLiveNestedTheme(tester, 'live sheet', NibTheme.dark);
    palette.dispose();
  });

  testWidgets('toast follows root theme changes while visible', (tester) async {
    final palette = ValueNotifier<NibTheme>(NibTheme.light);
    await tester.pumpWidget(
      _switchingHost(palette, (context) {
        showNibToast(
          context: context,
          title: 'live toast',
          duration: Duration.zero,
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    _expectLiveNestedTheme(tester, 'live toast', NibTheme.light);
    palette.value = NibTheme.dark;
    await tester.pumpAndSettle();
    _expectLiveNestedTheme(tester, 'live toast', NibTheme.dark);
    dismissAllNibToasts();
    await tester.pump();
    palette.dispose();
  });

  for (final kind in ['dialog', 'sheet', 'toast']) {
    testWidgets('$kind falls back to live root theme after opener unmounts', (
      tester,
    ) async {
      final palette = ValueNotifier<NibTheme>(NibTheme.light);
      final showingOpener = ValueNotifier<bool>(true);
      await tester.pumpWidget(
        _removableHost(palette, showingOpener, (context) {
          switch (kind) {
            case 'dialog':
              showNibDialog<void>(context, content: const Text('open overlay'));
            case 'sheet':
              showNibBottomSheet<void>(
                context,
                content: const Text('open overlay'),
              );
            case 'toast':
              showNibToast(
                context: context,
                title: 'open overlay',
                duration: Duration.zero,
              );
          }
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      showingOpener.value = false;
      await tester.pumpAndSettle();
      palette.value = NibTheme.dark;
      await tester.pumpAndSettle();
      final theme = NibTheme.of(tester.element(find.text('open overlay')));
      expect(theme.card, NibTheme.dark.card);
      expect(theme.primary, NibTheme.dark.primary);
      if (kind == 'toast') {
        dismissAllNibToasts();
        await tester.pump();
      }
      showingOpener.dispose();
      palette.dispose();
    });
  }

  for (final kind in ['dialog', 'sheet']) {
    testWidgets('$kind retains focused input across a root theme change', (
      tester,
    ) async {
      final palette = ValueNotifier<NibTheme>(NibTheme.light);
      await tester.pumpWidget(
        _switchingHost(palette, (context) {
          if (kind == 'dialog') {
            showNibDialog<void>(
              context,
              content: const TextField(key: ValueKey('overlay-input')),
            );
          } else {
            showNibBottomSheet<void>(
              context,
              content: const TextField(key: ValueKey('overlay-input')),
            );
          }
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overlay-input')));
      await tester.enterText(
        find.byKey(const ValueKey('overlay-input')),
        'draft',
      );
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        true,
      );
      palette.value = NibTheme.dark;
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        true,
      );
      expect(find.text('draft'), findsOneWidget);
      palette.dispose();
    });
  }

  testWidgets('toast inherits the caller route NibTheme', (tester) async {
    await tester.pumpWidget(
      _host(
        (context) => showNibToast(
          context: context,
          title: 'nested toast',
          duration: Duration.zero,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();

    expect(
      NibTheme.of(tester.element(find.text('nested toast'))).primary,
      _nestedPrimary,
    );
    dismissAllNibToasts();
    await tester.pump();
  });

  testWidgets('dialog inherits the caller route NibTheme', (tester) async {
    await tester.pumpWidget(
      _host(
        (context) =>
            showNibDialog<void>(context, content: const Text('nested dialog')),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      NibTheme.of(tester.element(find.text('nested dialog'))).primary,
      _nestedPrimary,
    );
  });

  testWidgets('bottom sheet inherits the caller route NibTheme', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        (context) => showNibBottomSheet<void>(
          context,
          content: const Text('nested sheet'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      NibTheme.of(tester.element(find.text('nested sheet'))).primary,
      _nestedPrimary,
    );
  });
}
