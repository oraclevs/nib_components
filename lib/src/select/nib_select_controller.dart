import 'package:flutter/foundation.dart';

/// Optional external controller for a [NibSelect]'s selection and open/closed
/// state. Never required for basic use — `NibSelect` creates and owns its own
/// controller internally when none is supplied, and disposes it on
/// unmount/controller-swap. Pass an explicit instance to read or drive the
/// select from elsewhere in the tree (e.g. a "clear" button, or reading the
/// current selection for a form).
class NibSelectController<T> extends ChangeNotifier {
  final List<T> _selectedValues = [];
  bool _isOpen = false;

  /// The currently-selected values, in selection order (a single-element list
  /// in single-select mode). Unmodifiable — mutate via [selectOnly] /
  /// [toggle] / [clear].
  List<T> get selectedValues => List<T>.unmodifiable(_selectedValues);

  /// Convenience accessor for single-select use: the first selected value, or
  /// `null` if nothing is selected.
  T? get selectedValue =>
      _selectedValues.isEmpty ? null : _selectedValues.first;

  /// Whether the dropdown is currently open.
  bool get isOpen => _isOpen;

  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }

  /// Replaces the whole selection with just [value] (single-select semantics).
  void selectOnly(T value) {
    if (_selectedValues.length == 1 && _selectedValues.first == value) return;
    _selectedValues
      ..clear()
      ..add(value);
    notifyListeners();
  }

  /// Adds [value] if absent, removes it if present (multi-select semantics).
  void toggle(T value) {
    if (!_selectedValues.remove(value)) _selectedValues.add(value);
    notifyListeners();
  }

  /// Clears the whole selection.
  void clear() {
    if (_selectedValues.isEmpty) return;
    _selectedValues.clear();
    notifyListeners();
  }

  /// Replaces the whole selection with [values] (used to seed an initial
  /// selection). No-op if it already equals the current selection.
  void setSelection(List<T> values) {
    if (listEquals(_selectedValues, values)) return;
    _selectedValues
      ..clear()
      ..addAll(values);
    notifyListeners();
  }
}
