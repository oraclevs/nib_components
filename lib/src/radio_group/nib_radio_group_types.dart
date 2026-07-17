import 'package:flutter/widgets.dart';

/// One selectable choice inside a [NibRadioGroup].
@immutable
class NibRadioOption<T> {
  /// Creates a radio option.
  const NibRadioOption({
    required this.value,
    required this.label,
    this.description,
    this.leading,
    this.disabled = false,
  });

  /// The value this option represents; compared with [NibRadioGroup.value]
  /// by `==` to determine the selected option.
  final T value;

  /// The option's primary label.
  final String label;

  /// An optional secondary line shown under [label].
  final String? description;

  /// An optional leading slot (e.g. an icon) shown before the label.
  final Widget? leading;

  /// Disables just this option — dims it and removes it from tap/keyboard
  /// interaction while the rest of the group stays interactive.
  final bool disabled;
}

/// Builds a fully custom row for one option, replacing the built-in
/// dot+label layout. The group still owns tap/ripple/focus/keyboard/shape —
/// the builder only paints the row's content.
typedef NibRadioOptionBuilder<T> = Widget Function(
  BuildContext context,
  NibRadioOption<T> option,
  bool selected,
  bool disabled,
);
