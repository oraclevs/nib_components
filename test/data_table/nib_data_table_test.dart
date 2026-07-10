import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

class _Person {
  const _Person(this.name, this.email);
  final String name;
  final String email;
}

List<NibDataColumn<_Person>> _columns() => [
  NibDataColumn<_Person>(
    label: 'Name',
    cellBuilder: (context, row) => Text(row.name),
    sortValue: (row) => row.name,
  ),
  NibDataColumn<_Person>(
    label: 'Email',
    cellBuilder: (context, row) => Text(row.email),
  ),
];

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: const [NibTheme.light]),
    home: Scaffold(body: SizedBox(height: 400, child: child)),
  );
}

void main() {
  testWidgets('renders column headers and every row cell', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NibDataTable<_Person>(
          columns: _columns(),
          rows: const [
            _Person('Ada Lovelace', 'ada@example.com'),
            _Person('Alan Turing', 'alan@example.com'),
          ],
        ),
      ),
    );

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text('Alan Turing'), findsOneWidget);
    expect(find.text('alan@example.com'), findsOneWidget);
  });

  testWidgets('shows the default empty state when rows is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(NibDataTable<_Person>(columns: _columns(), rows: const [])),
    );
    expect(find.text('No data'), findsOneWidget);
  });

  testWidgets('shows a custom empty state when provided', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NibDataTable<_Person>(
          columns: _columns(),
          rows: const [],
          emptyState: const Text('Nothing here yet'),
        ),
      ),
    );
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('No data'), findsNothing);
  });

  testWidgets('onRowTap fires with the tapped row', (tester) async {
    _Person? tapped;
    const people = [
      _Person('Ada Lovelace', 'ada@example.com'),
      _Person('Alan Turing', 'alan@example.com'),
    ];
    await tester.pumpWidget(
      _wrap(
        NibDataTable<_Person>(
          columns: _columns(),
          rows: people,
          onRowTap: (row) => tapped = row,
        ),
      ),
    );

    await tester.tap(find.text('Alan Turing'));
    await tester.pumpAndSettle();
    expect(tapped, people[1]);
  });
}
