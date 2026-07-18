import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart' show NibFlip;

import '../theme/nib_theme.dart';

/// A card that flips between [front] and [back] faces, 3D-rotated around
/// either the vertical or horizontal axis (via `nib_motion`'s [NibFlip]).
///
/// A distinct widget from [NibCard] — a flip card's whole identity is the
/// two-face flip contract ([front]/[back]/[flipAxis]/[isFlipped]), which
/// doesn't overlap with a plain card's header/footer/content slots.
///
/// Uncontrolled by default (tap either face to flip, like an
/// expand/collapse toggle): just supply [front]/[back]. Pass [isFlipped] +
/// [onFlippedChanged] for external control (the widget never mutates itself
/// once controlled — same `expanded: bool?` pattern as `NibAccordion`).
///
/// ```dart
/// NibFlipCard(front: Text('Question'), back: Text('Answer'))
///
/// bool showBack = false;
/// NibFlipCard(
///   front: const Text('Question'),
///   back: const Text('Answer'),
///   isFlipped: showBack,
///   onFlippedChanged: (v) => setState(() => showBack = v),
/// )
/// ```
class NibFlipCard extends StatefulWidget {
  /// Creates a flip card.
  const NibFlipCard({
    super.key,
    required this.front,
    required this.back,
    this.isFlipped,
    this.onFlippedChanged,
    this.flipAxis = Axis.horizontal,
    this.duration,
    this.tappable = true,
    this.padding,
    this.borderRadius,
    this.frontColor,
    this.backColor,
    this.borderColor,
    this.frontSemanticLabel,
    this.backSemanticLabel,
  });

  /// Content shown while the flip progress is below 0.5.
  final Widget front;

  /// Content shown while the flip progress is at or above 0.5.
  final Widget back;

  /// External control of which face is forward. `null` (the default) makes
  /// the card manage its own flip state internally.
  final bool? isFlipped;

  /// Called with the next flip state — on every tap (uncontrolled or
  /// controlled) and, in uncontrolled mode, right after the internal state
  /// updates.
  final ValueChanged<bool>? onFlippedChanged;

  /// Which axis the card rotates around. [Axis.horizontal] rotates around
  /// the vertical (Y) axis; [Axis.vertical] rotates around the horizontal
  /// (X) axis.
  final Axis flipAxis;

  /// How long the flip animation takes. Defaults to 600ms.
  final Duration? duration;

  /// Whether tapping a face flips the card. Defaults to true; set false to
  /// drive the flip purely via [isFlipped] (e.g. from an external button).
  final bool tappable;

  /// Padding around [front]/[back]'s content. Defaults to
  /// `EdgeInsets.all(16)`.
  final EdgeInsetsGeometry? padding;

  /// Corner radius of both faces. Defaults to `NibTheme.radiusLg`.
  final BorderRadius? borderRadius;

  /// Front face fill colour. Defaults to `NibTheme.card`.
  final Color? frontColor;

  /// Back face fill colour. Defaults to `NibTheme.card`.
  final Color? backColor;

  /// Border colour for both faces. Defaults to `NibTheme.border`.
  final Color? borderColor;

  /// Accessible name for the front face.
  final String? frontSemanticLabel;

  /// Accessible name for the back face.
  final String? backSemanticLabel;

  @override
  State<NibFlipCard> createState() => _NibFlipCardState();
}

class _NibFlipCardState extends State<NibFlipCard> {
  bool _internalFlipped = false;

  bool get _isControlled => widget.isFlipped != null;
  bool get _flipped => _isControlled ? widget.isFlipped! : _internalFlipped;

  void _toggle() {
    final next = !_flipped;
    if (!_isControlled) {
      setState(() => _internalFlipped = next);
    }
    widget.onFlippedChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(theme.radiusLg);

    return NibFlip(
      isFlipped: _flipped,
      flipAxis: widget.flipAxis,
      duration: widget.duration ?? const Duration(milliseconds: 600),
      front: _buildFace(
        theme,
        radius,
        widget.front,
        widget.frontColor,
        widget.frontSemanticLabel,
      ),
      back: _buildFace(
        theme,
        radius,
        widget.back,
        widget.backColor,
        widget.backSemanticLabel,
      ),
    );
  }

  Widget _buildFace(
    NibTheme theme,
    BorderRadius radius,
    Widget content,
    Color? color,
    String? semanticLabel,
  ) {
    final padded = Padding(
      padding: widget.padding ?? const EdgeInsets.all(16),
      child: content,
    );

    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? theme.card,
        borderRadius: radius,
        border: Border.all(color: widget.borderColor ?? theme.border),
      ),
      child: widget.tappable
          ? Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: _toggle,
                borderRadius: radius,
                child: padded,
              ),
            )
          : padded,
    );

    if (!widget.tappable) return box;

    return MergeSemantics(
      child: Semantics(
        button: true,
        toggled: _flipped,
        label: semanticLabel,
        child: box,
      ),
    );
  }
}
