import 'package:flutter/foundation.dart';

/// Optional external controller for a [NibCombobox]'s selection, query text,
/// and open/closed state. Never required for basic use — `NibCombobox`
/// creates and owns its own controller internally when none is supplied, and
/// disposes it on unmount/controller-swap. Pass an explicit instance to read
/// or drive the combobox from elsewhere in the tree (e.g. a "clear filters"
/// button, or reading the current selection for a form).
class NibComboboxController<T> extends ChangeNotifier {
  final List<T> _selectedValues = [];
  String _query = '';
  bool _isOpen = false;

  /// The currently-selected values, in selection order (a single-element list
  /// in single-select mode). Unmodifiable — mutate via [selectOnly] /
  /// [toggle] / [clear].
  List<T> get selectedValues => List<T>.unmodifiable(_selectedValues);

  /// Convenience accessor for single-select use: the first selected value, or
  /// `null` if nothing is selected.
  T? get selectedValue =>
      _selectedValues.isEmpty ? null : _selectedValues.first;

  /// The current query text mirrored from the field. Read-only here; set it
  /// through the field itself.
  String get query => _query;

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

  /// Mirrors the field's current query text into the controller so external
  /// readers see it. Called by the widget on each text change; does not notify
  /// by default since the widget already rebuilds itself on text change.
  void setQuery(String value, {bool notify = false}) {
    if (_query == value) return;
    _query = value;
    if (notify) notifyListeners();
  }
}
