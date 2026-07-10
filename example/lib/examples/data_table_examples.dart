import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

class _Employee {
  const _Employee(this.name, this.role, this.email);
  final String name;
  final String role;
  final String email;
}

const _employees = [
  _Employee('Ada Lovelace', 'Engineer', 'ada@nib.dev'),
  _Employee('Alan Turing', 'Engineer', 'alan@nib.dev'),
  _Employee('Grace Hopper', 'Manager', 'grace@nib.dev'),
  _Employee('Margaret Hamilton', 'Manager', 'margaret@nib.dev'),
  _Employee('Katherine Johnson', 'Analyst', 'katherine@nib.dev'),
];

/// 1. Minimal/default usage — just columns + rows.
class DataTableMinimalExample extends StatelessWidget {
  const DataTableMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: NibDataTable<_Employee>(
        columns: [
          NibDataColumn(
            label: 'Name',
            cellBuilder: (context, row) => Text(row.name),
          ),
          NibDataColumn(
            label: 'Role',
            cellBuilder: (context, row) => Text(row.role),
          ),
        ],
        rows: _employees,
      ),
    );
  }
}

/// 2. Common variant — sortable columns + single-row selection.
class DataTableSortableSelectableExample extends StatelessWidget {
  const DataTableSortableSelectableExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: NibDataTable<_Employee>(
        columns: [
          NibDataColumn(
            label: 'Name',
            cellBuilder: (context, row) => Text(row.name),
            sortValue: (row) => row.name,
          ),
          NibDataColumn(
            label: 'Role',
            cellBuilder: (context, row) => Text(row.role),
            sortValue: (row) => row.role,
          ),
        ],
        rows: _employees,
        selectionMode: NibDataTableSelectionMode.single,
      ),
    );
  }
}

/// 3. Advanced — multi-select with an external controller, animated row
/// entrance, and a loading toggle.
class DataTableAdvancedExample extends StatefulWidget {
  const DataTableAdvancedExample({super.key});

  @override
  State<DataTableAdvancedExample> createState() => _DataTableAdvancedExampleState();
}

class _DataTableAdvancedExampleState extends State<DataTableAdvancedExample> {
  final _controller = NibDataTableController<_Employee>();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          title: const Text('Loading'),
          value: _loading,
          onChanged: (value) => setState(() => _loading = value),
        ),
        SizedBox(
          height: 320,
          child: NibDataTable<_Employee>(
            columns: [
              NibDataColumn(
                label: 'Name',
                cellBuilder: (context, row) => Text(row.name),
                sortValue: (row) => row.name,
              ),
              NibDataColumn(
                label: 'Role',
                cellBuilder: (context, row) => Text(row.role),
                sortValue: (row) => row.role,
              ),
              NibDataColumn(
                label: 'Email',
                cellBuilder: (context, row) => Text(row.email),
              ),
            ],
            rows: _employees,
            selectionMode: NibDataTableSelectionMode.multi,
            controller: _controller,
            loading: _loading,
            animated: true,
            onSelectionChanged: (selection) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${selection.length} selected'),
                  duration: const Duration(milliseconds: 600),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
