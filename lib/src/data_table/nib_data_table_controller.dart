import 'package:flutter/foundation.dart';

import 'nib_data_table_types.dart';

/// Optional external controller for a `NibDataTable<T>`'s sort and
/// selection state. Never required for basic use — `NibDataTable` owns its
/// own controller internally when none is supplied.
class NibDataTableController<T> extends ChangeNotifier {
  NibDataTableController({
    NibDataTableSort sort = const NibDataTableSort(),
    Set<T>? selected,
  }) : _sort = sort,
       _selected = Set<T>.of(selected ?? const {});

  NibDataTableSort _sort;

  /// The current sort state.
  NibDataTableSort get sort => _sort;

  final Set<T> _selected;

  /// The currently-selected rows. Unmodifiable — use [setSelected],
  /// [toggleSelected], or [clearSelection] to change it.
  Set<T> get selected => Set<T>.unmodifiable(_selected);

  /// Replaces the sort state and notifies listeners.
  void setSort(NibDataTableSort sort) {
    _sort = sort;
    notifyListeners();
  }

  /// Replaces the whole selection set and notifies listeners.
  void setSelected(Set<T> rows) {
    _selected
      ..clear()
      ..addAll(rows);
    notifyListeners();
  }

  /// Adds [row] if not selected, removes it if it is. Notifies listeners.
  void toggleSelected(T row) {
    if (!_selected.remove(row)) {
      _selected.add(row);
    }
    notifyListeners();
  }

  /// Empties the selection. No-op (does not notify) if already empty.
  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }
}
