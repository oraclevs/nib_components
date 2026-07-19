import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibTransition;

import '../theme/nib_theme.dart';

/// A single tri-state checkbox — mirrors Flutter's own [Checkbox] contract
/// ([tristate], the false → true → null → false tap cycle, `mixed` semantics
/// for the indeterminate state) built to Nib's design tokens, with optional
/// built-in label/description slots for a full-row tap target.
///
/// ```dart
/// NibCheckbox(value: checked, onChanged: (v) => setState(() => checked = v))
/// NibCheckbox(
///   value: checked,
///   label: 'Accept terms',
///   onChanged: (v) => setState(() => checked = v!),
/// )
/// ```
class NibCheckbox extends StatelessWidget {
  /// Creates a checkbox. [value] must not be null unless [tristate] is true.
  const NibCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.tristate = false,
    this.label,
    this.description,
    this.disabled = false,
    this.size,
    this.activeColor,
    this.contentPadding,
    this.animated = false,
    this.transition,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  }) : assert(tristate || value != null);

  /// The checkbox's value. `null` means indeterminate and is only valid
  /// when [tristate] is true.
  final bool? value;

  /// Called with the next value. `null` renders the checkbox disabled.
  final ValueChanged<bool?>? onChanged;

  /// When true, tapping cycles `false → true → null → false` and [value]
  /// may be `null` (indeterminate, shown as a dash). Defaults to false.
  final bool tristate;

  /// An optional label shown beside the box, extending the tap target to
  /// the full row.
  final String? label;

  /// An optional secondary line shown under [label].
  final String? description;

  /// Disables interaction and dims the checkbox regardless of [onChanged].
  final bool disabled;

  /// Box side length. Defaults to 20.
  final double? size;

  /// The checked/indeterminate fill colour. Defaults to `NibTheme.primary`.
  final Color? activeColor;

  /// Padding around the row's content when [label] is set. Defaults to
  /// `EdgeInsets.symmetric(vertical: 8, horizontal: 4)`.
  final EdgeInsetsGeometry? contentPadding;

  /// Opt-in `nib_motion`: the check mark / dash pops in. `false` builds
  /// **zero** [NibMotion].
  final bool animated;

  /// Timing/curve for [animated]. `null` → a short ~150ms ease.
  final NibTransition? transition;

  /// Accessible name. Defaults to [label] when set.
  final String? semanticLabel;

  /// Passed straight through to the underlying [InkWell].
  final FocusNode? focusNode;

  /// Passed straight through to the underlying [InkWell].
  final bool autofocus;

  bool get _enabled => !disabled && onChanged != null;

  NibTransition get _transition =>
      transition ?? const NibTransition(duration: Duration(milliseconds: 150));

  void _handleTap() {
    if (!_enabled) return;
    bool? next;
    if (tristate) {
      next = switch (value) {
        false => true,
        true => null,
        null => false,
      };
    } else {
      next = !(value ?? false);
    }
    onChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final enabled = _enabled;
    final box = _buildBox(theme, enabled);

    final Widget core = label == null
        ? ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(child: box),
          )
        : Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.centerLeft,
            padding:
                contentPadding ??
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                box,
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label!,
                        style: TextStyle(
                          color: enabled
                              ? theme.foreground
                              : theme.mutedForeground,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (description != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            description!,
                            style: TextStyle(
                              color: theme.mutedForeground,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );

    return Semantics(
      checked: value ?? false,
      mixed: tristate ? value == null : null,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: InkWell(
        onTap: enabled ? _handleTap : null,
        focusNode: focusNode,
        autofocus: autofocus,
        borderRadius: BorderRadius.circular(theme.radiusDefault),
        child: core,
      ),
    );
  }

  Widget _buildBox(NibTheme theme, bool enabled) {
    final boxSize = size ?? 20;
    final filled = value == true || value == null;
    final fillColor = activeColor ?? theme.primary;

    return Container(
      width: boxSize,
      height: boxSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radiusSm),
        color: filled ? (enabled ? fillColor : theme.mutedForeground) : null,
        border: Border.all(
          color: !enabled
              ? theme.border
              : filled
              ? fillColor
              : theme.mutedForeground,
          width: 2,
        ),
      ),
      child: _buildMark(theme, boxSize, enabled),
    );
  }

  Widget? _buildMark(NibTheme theme, double boxSize, bool enabled) {
    final markColor = enabled ? theme.primaryForeground : theme.background;
    final Widget mark;
    if (value == true) {
      mark = Icon(Icons.check_rounded, size: boxSize * 0.75, color: markColor);
    } else if (value == null) {
      mark = Container(width: boxSize * 0.5, height: 2, color: markColor);
    } else {
      return null;
    }

    if (!animated) return mark;
    return NibMotion(
      initial: const NibAnim(scale: 0),
      animate: const NibAnim(scale: 1),
      transition: _transition,
      child: mark,
    );
  }
}
