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

void main() {
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
