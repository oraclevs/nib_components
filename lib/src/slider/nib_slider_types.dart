import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The pair of values driving a two-thumb [NibSlider.range].
///
/// Nib-prefixed and self-contained (not Material's `RangeValues`) so the
/// package stays dependency-light and can carry its own helpers ([clamp],
/// [copyWith]). By convention [start] `<=` [end]; [clamp] enforces both the
/// bounds and the ordering.
@immutable
class NibRangeValues {
  /// Creates a range. Callers should keep `start <= end`; the widget clamps
  /// this itself during interaction.
  const NibRangeValues(this.start, this.end);

  /// The lower (leading) thumb value.
  final double start;

  /// The upper (trailing) thumb value.
  final double end;

  /// Clamps both thumbs into `[min, max]` and restores `start <= end`.
  NibRangeValues clamp(double min, double max) {
    final s = start.clamp(min, max).toDouble();
    final e = end.clamp(min, max).toDouble();
    return NibRangeValues(math.min(s, e), math.max(s, e));
  }

  /// Returns a copy with the given fields replaced.
  NibRangeValues copyWith({double? start, double? end}) =>
      NibRangeValues(start ?? this.start, end ?? this.end);

  @override
  bool operator ==(Object other) =>
      other is NibRangeValues && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'NibRangeValues($start, $end)';
}

/// The live state handed to a [NibSliderThumbBuilder] so a custom thumb can
/// react to drag/focus and size itself against the slider's `thumbSize`.
@immutable
class NibSliderThumbState {
  /// Creates a thumb state snapshot.
  const NibSliderThumbState({
    required this.value,
    required this.dragging,
    required this.focused,
    required this.size,
  });

  /// The thumb's current value (in the slider's `[min, max]` domain).
  final double value;

  /// Whether this thumb is being dragged right now.
  final bool dragging;

  /// Whether this thumb holds keyboard focus.
  final bool focused;

  /// The resolved thumb diameter (the slider's `thumbSize`).
  final double size;
}

/// Builds a fully custom thumb, replacing the built-in circle. The slider still
/// owns positioning, gestures, focus and (when `animated`) the press-pop — the
/// builder only paints the knob.
typedef NibSliderThumbBuilder =
    Widget Function(BuildContext context, NibSliderThumbState state);
