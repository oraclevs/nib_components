import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// One selectable entry in a [NibSelect].
///
/// [value] is the typed payload reported through the change callbacks and the
/// controller; [label] is the human-readable text shown in the dropdown row,
/// joined into the closed trigger once selected, and matched against by the
/// in-list search when `searchable` is on.
@immutable
class NibSelectOption<T> {
  const NibSelectOption({
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
      other is NibSelectOption<T> &&
          other.value == value &&
          other.label == label &&
          other.subtitle == subtitle &&
          other.disabled == disabled;

  @override
  int get hashCode => Object.hash(value, label, subtitle, disabled);
}

/// A labelled section of [options] in a [NibSelect].
///
/// Passed via `NibSelect.groups` (mutually exclusive with the flat
/// `NibSelect.options`) to render section headers above each group's rows —
/// the ungrouped common case stays a plain flat `options` list.
@immutable
class NibSelectGroup<T> {
  const NibSelectGroup({required this.label, required this.options});

  /// The section-header text shown above this group's [options].
  final String label;

  final List<NibSelectOption<T>> options;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NibSelectGroup<T> &&
          other.label == label &&
          listEquals(other.options, options);

  @override
  int get hashCode => Object.hash(label, Object.hashAll(options));
}
