import 'package:flutter/widgets.dart';

/// The live state handed to a [NibSwitchThumbBuilder] so a custom thumb can
/// react to the switch's value/enabled/loading and size itself against the
/// switch's thumb diameter.
@immutable
class NibSwitchThumbState {
  /// Creates a thumb state snapshot.
  const NibSwitchThumbState({
    required this.value,
    required this.enabled,
    required this.loading,
    required this.size,
  });

  /// Whether the switch is currently on.
  final bool value;

  /// Whether the switch is interactive right now (not disabled/loading and
  /// has an [onChanged]).
  final bool enabled;

  /// Whether the switch is awaiting an async-confirmed toggle.
  final bool loading;

  /// The resolved thumb diameter (the switch's track height minus its
  /// vertical inset).
  final double size;
}

/// Builds a fully custom thumb, replacing the built-in shape/colour/icon.
/// The switch still owns the thumb's position, size and (when `animated`)
/// its glide — the builder only paints the knob.
typedef NibSwitchThumbBuilder = Widget Function(
  BuildContext context,
  NibSwitchThumbState state,
);
