import 'package:flutter/widgets.dart';

/// Overridable match predicate used by [NibCombobox]'s local filtering —
/// `true` if [option] should remain visible for the current [query].
typedef NibComboboxFilter<T> =
    bool Function(NibComboboxOption<T> option, String query);

/// Async data source for a [NibCombobox]: given the current [query], resolves
/// the options to show. Called (debounced) on each query change; the widget
/// shows an in-dropdown loading row while the future is pending and guards
/// against stale responses (only the latest request's result is applied).
typedef NibComboboxOptionsLoader<T> =
    Future<List<NibComboboxOption<T>>> Function(String query);

/// One selectable entry in a [NibCombobox].
///
/// [value] is the typed payload reported through the change callbacks and the
/// controller; [label] is the human-readable text shown in the list, used as
/// the field's text once selected, and matched against by the default filter.
@immutable
class NibComboboxOption<T> {
  const NibComboboxOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.disabled = false,
  });

  final T value;

  final String label;

  final String? subtitle;

  final Widget? icon;

  final bool disabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NibComboboxOption<T> &&
          other.value == value &&
          other.label == label &&
          other.subtitle == subtitle &&
          other.disabled == disabled;

  @override
  int get hashCode => Object.hash(value, label, subtitle, disabled);
}
