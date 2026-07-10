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

  testWidgets('tapping a sortable header sorts rows ascending, then descending, then unsorted', (
    tester,
  ) async {
    const people = [
      _Person('Charlie', 'c@example.com'),
      _Person('Ada', 'a@example.com'),
      _Person('Bob', 'b@example.com'),
    ];
    await tester.pumpWidget(
      _wrap(NibDataTable<_Person>(columns: _columns(), rows: people)),
    );

    Text firstRowName() {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      return Text(texts.firstWhere((t) => people.any((p) => p.name == t))!);
    }

    // Unsorted: input order.
    expect(firstRowName().data, 'Charlie');

    await tester.tap(find.text('Name')); // -> ascending
    await tester.pumpAndSettle();
    expect(firstRowName().data, 'Ada');

    await tester.tap(find.text('Name')); // -> descending
    await tester.pumpAndSettle();
    expect(firstRowName().data, 'Charlie');

    await tester.tap(find.text('Name')); // -> none
    await tester.pumpAndSettle();
    expect(firstRowName().data, 'Charlie');
  });

  testWidgets('a non-sortable column header does nothing when tapped', (
    tester,
  ) async {
    const people = [
      _Person('Charlie', 'c@example.com'),
      _Person('Ada', 'a@example.com'),
    ];
    await tester.pumpWidget(
      _wrap(NibDataTable<_Person>(columns: _columns(), rows: people)),
    );
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    // Order unchanged (Email column has no sortValue).
    expect(find.text('Charlie'), findsOneWidget);
  });

  testWidgets('onSort is called with the new column/direction instead of self-sorting', (
    tester,
  ) async {
    const people = [
      _Person('Charlie', 'c@example.com'),
      _Person('Ada', 'a@example.com'),
    ];
    int? sortedColumn;
    NibSortDirection? sortedDirection;
    await tester.pumpWidget(
      _wrap(
        NibDataTable<_Person>(
          columns: _columns(),
          rows: people,
          onSort: (columnIndex, direction) {
            sortedColumn = columnIndex;
            sortedDirection = direction;
          },
        ),
      ),
    );
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    expect(sortedColumn, 0);
    expect(sortedDirection, NibSortDirection.ascending);
    // NibDataTable does not reorder rows itself in onSort mode.
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    expect(texts.indexOf('Charlie') < texts.indexOf('Ada'), isTrue);
  });

  testWidgets('multi selection: per-row checkbox toggles selection and calls onSelectionChanged', (
    tester,
  ) async {
    const people = [
      _Person('Ada Lovelace', 'ada@example.com'),
      _Person('Alan Turing', 'alan@example.com'),
    ];
    Set<_Person>? lastSelection;
    await tester.pumpWidget(
      _wrap(
        NibDataTable<_Person>(
          columns: _columns(),
          rows: people,
          selectionMode: NibDataTableSelectionMode.multi,
          onSelectionChanged: (selection) => lastSelection = selection,
        ),
      ),
    );

    final rowCheckboxes = find.byType(Checkbox);
    // First checkbox is the header select-all; row checkboxes follow.
    await tester.tap(rowCheckboxes.at(1));
    await tester.pumpAndSettle();
    expect(lastSelection, {people[0]});

    await tester.tap(rowCheckboxes.at(1));
    await tester.pumpAndSettle();
    expect(lastSelection, isEmpty);
  });

  testWidgets('multi selection: header checkbox selects/deselects all', (
    tester,
  ) async {
    const people = [
      _Person('Ada Lovelace', 'ada@example.com'),
      _Person('Alan Turing', 'alan@example.com'),
    ];
    Set<_Person>? lastSelection;
    await tester.pumpWidget(
      _wrap(
        NibDataTable<_Person>(
          columns: _columns(),
          rows: people,
          selectionMode: NibDataTableSelectionMode.multi,
          onSelectionChanged: (selection) => lastSelection = selection,
        ),
      ),
    );

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(lastSelection, people.toSet());

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(lastSelection, isEmpty);
  });

  testWidgets('single selection: tapping a row selects it and replaces prior selection', (
    tester,
  ) async {
    const people = [
      _Person('Ada Lovelace', 'ada@example.com'),
      _Person('Alan Turing', 'alan@example.com'),
    ];
    Set<_Person>? lastSelection;
    await tester.pumpWidget(
      _wrap(
        NibDataTable<_Person>(
          columns: _columns(),
          rows: people,
          selectionMode: NibDataTableSelectionMode.single,
          onSelectionChanged: (selection) => lastSelection = selection,
        ),
      ),
    );

    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.text('Ada Lovelace'));
    await tester.pumpAndSettle();
    expect(lastSelection, {people[0]});

    await tester.tap(find.text('Alan Turing'));
    await tester.pumpAndSettle();
    expect(lastSelection, {people[1]});
  });
}
