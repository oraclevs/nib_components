import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibTransition;

import '../theme/nib_theme.dart';

/// A content container with optional header/footer slots and an opt-in
/// pressable variant.
///
/// Plain by default (no gesture wrapper at all — zero overhead); set
/// [interactive] to true for a tappable card with native ripple/hover/focus.
///
/// ```dart
/// NibCard(child: Text('Plain content'))
/// NibCard(
///   header: Text('Title'),
///   child: Text('Body'),
///   interactive: true,
///   onTap: () {},
/// )
/// ```
class NibCard extends StatefulWidget {
  /// Creates a card. At least one of [header]/[child]/[footer] is required.
  const NibCard({
    super.key,
    this.child,
    this.header,
    this.footer,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.interactive = false,
    this.onTap,
    this.disabled = false,
    this.semanticLabel,
    this.animated = false,
    this.transition,
  }) : assert(
         child != null || header != null || footer != null,
         'NibCard requires at least one of header/child/footer.',
       );

  /// The card's main content.
  final Widget? child;

  /// An optional slot above [child], separated by a divider when [child] or
  /// [footer] is also set.
  final Widget? header;

  /// An optional slot below [child], separated by a divider when [child] or
  /// [header] is also set.
  final Widget? footer;

  /// Padding around [child]. Defaults to `EdgeInsets.all(16)`.
  final EdgeInsetsGeometry? padding;

  /// Corner radius. Defaults to `NibTheme.radiusLg`.
  final BorderRadius? borderRadius;

  /// Fill colour. Defaults to `NibTheme.card`.
  final Color? backgroundColor;

  /// Border colour. Defaults to `NibTheme.border`.
  final Color? borderColor;

  /// Makes the card tappable — native ripple/hover/focus via an internal
  /// `InkWell`. `false` (the default) renders a plain static container.
  final bool interactive;

  /// Called on tap when [interactive] is true. `null` renders it disabled.
  final VoidCallback? onTap;

  /// Disables interaction and dims the card regardless of [onTap].
  final bool disabled;

  /// Accessible name for the whole card.
  final String? semanticLabel;

  /// Opt-in `nib_motion`: a press scale-pop on [interactive] cards. `false`
  /// (or a non-interactive card) builds **zero** [NibMotion].
  final bool animated;

  /// Timing/curve for [animated]. `null` → a short ~150ms ease.
  final NibTransition? transition;

  @override
  State<NibCard> createState() => _NibCardState();
}

class _NibCardState extends State<NibCard> {
  int _tapCount = 0;

  bool get _enabled =>
      widget.interactive && !widget.disabled && widget.onTap != null;

  NibTransition get _transition =>
      widget.transition ??
      const NibTransition(duration: Duration(milliseconds: 150));

  void _handleTap() {
    widget.onTap!();
    setState(() => _tapCount++);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(theme.radiusLg);

    final content = _buildContent(theme);

    Widget box = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? theme.card,
        borderRadius: radius,
        border: Border.all(color: widget.borderColor ?? theme.border),
      ),
      child: widget.interactive
          ? Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: _enabled ? _handleTap : null,
                borderRadius: radius,
                child: content,
              ),
            )
          : content,
    );

    if (widget.animated && widget.interactive) {
      box = NibMotion(
        key: ValueKey(_tapCount),
        initial: _tapCount == 0 ? NibAnim.identity : const NibAnim(scale: 0.97),
        animate: NibAnim.identity,
        transition: _transition,
        child: box,
      );
    }

    if (widget.semanticLabel == null) return box;
    return Semantics(
      label: widget.semanticLabel,
      button: widget.interactive,
      child: box,
    );
  }

  Widget _buildContent(NibTheme theme) {
    final divider = Divider(height: 1, thickness: 1, color: theme.border);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: widget.header,
          ),
        if (widget.header != null &&
            (widget.child != null || widget.footer != null))
          divider,
        if (widget.child != null)
          Padding(
            padding: widget.padding ?? const EdgeInsets.all(16),
            child: widget.child,
          ),
        if (widget.footer != null &&
            (widget.child != null || widget.header != null))
          divider,
        if (widget.footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: widget.footer,
          ),
      ],
    );
  }
}
