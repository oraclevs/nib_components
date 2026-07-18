import 'package:flutter/widgets.dart';

/// One segment inside a [NibToggleGroup].
@immutable
class NibToggleOption<T> {
  /// Creates a toggle option. At least one of [label]/[icon] is required;
  /// [semanticLabel] is required for an icon-only option.
  const NibToggleOption({
    required this.value,
    this.label,
    this.icon,
    this.disabled = false,
    this.semanticLabel,
  })  : assert(
          label != null || icon != null,
          'NibToggleOption requires a label and/or an icon.',
        ),
        assert(
          label != null || semanticLabel != null,
          'NibToggleOption requires semanticLabel when label is null '
          '(icon-only).',
        );

  /// The value this segment represents; compared with the group's
  /// selection by `==`.
  final T value;

  /// The segment's label. Optional when [icon] is set (icon-only segment).
  final String? label;

  /// A leading icon shown before [label], or alone for an icon-only segment.
  final Widget? icon;

  /// Disables just this segment — dims it and removes it from tap/keyboard
  /// interaction while the rest of the group stays interactive.
  final bool disabled;

  /// Accessible name for an icon-only segment. Required when [label] is
  /// null.
  final String? semanticLabel;
}
