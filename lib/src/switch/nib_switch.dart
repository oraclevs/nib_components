import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibTransition;

import '../loader/nib_circular_loader.dart';
import '../theme/nib_theme.dart';
import 'nib_switch_types.dart';

/// A boolean on/off switch with an optional [loading] state for
/// async-confirmed toggles (tap fires [onChanged], but the switch stays busy
/// — thumb shows a spinner, interaction blocked — until the consumer settles
/// [value]/[loading] once the change is confirmed).
///
/// ```dart
/// NibSwitch(value: wifiOn, onChanged: (v) => setState(() => wifiOn = v))
/// NibSwitch(
///   value: syncing,
///   loading: confirming,
///   label: 'Sync',
///   onChanged: (v) async {
///     setState(() => confirming = true);
///     final ok = await api.setSync(v);
///     setState(() { confirming = false; if (ok) syncing = v; });
///   },
/// )
/// NibSwitch(
///   value: isDark,
///   animated: true,
///   onThumbIcon: Image.asset('assets/images/moon.png'),
///   offThumbIcon: Image.asset('assets/images/sun.png'),
///   onChanged: (v) => setState(() => isDark = v),
/// )
/// ```
class NibSwitch extends StatelessWidget {
  /// Creates a switch.
  const NibSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.loading = false,
    this.disabled = false,
    this.label,
    this.description,
    this.activeColor,
    this.trackWidth,
    this.trackHeight,
    this.thumbShape,
    this.onThumbIcon,
    this.offThumbIcon,
    this.thumbBuilder,
    this.contentPadding,
    this.animated = false,
    this.transition,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the next value. `null` renders the switch disabled.
  final ValueChanged<bool>? onChanged;

  /// Shows a spinner in the thumb and blocks interaction — for a toggle
  /// awaiting an async confirmation. Defaults to false.
  final bool loading;

  /// Disables interaction and dims the switch regardless of [onChanged].
  final bool disabled;

  /// An optional label shown beside the track, extending the tap target to
  /// the full row.
  final String? label;

  /// An optional secondary line shown under [label].
  final String? description;

  /// The "on" track colour. Defaults to `NibTheme.primary`.
  final Color? activeColor;

  /// Track width. Defaults to 44.
  final double? trackWidth;

  /// Track height. Defaults to 24.
  final double? trackHeight;

  /// Shape of the thumb. Defaults to a full circle.
  final ShapeBorder? thumbShape;

  /// Icon/image centred in the thumb while [value] is true — e.g. a sun for
  /// a light-theme toggle. Ignored while [loading] (the spinner takes
  /// precedence) or when [thumbBuilder] is set.
  final Widget? onThumbIcon;

  /// Icon/image centred in the thumb while [value] is false — e.g. a moon
  /// for a dark-theme toggle. Same precedence rules as [onThumbIcon].
  final Widget? offThumbIcon;

  /// Replaces the built-in thumb (shape, colour, icon, spinner) entirely.
  /// The switch still owns the thumb's position, size and (when [animated])
  /// glide — the builder only paints its content.
  final NibSwitchThumbBuilder? thumbBuilder;

  /// Padding around the row's content when [label] is set. Defaults to
  /// `EdgeInsets.symmetric(vertical: 8, horizontal: 4)`.
  final EdgeInsetsGeometry? contentPadding;

  /// Opt-in `nib_motion`: the thumb glides between positions. `false` builds
  /// **zero** [NibMotion] (the thumb still jumps to the right side).
  final bool animated;

  /// Timing/curve for [animated]. `null` → a short ~150ms ease.
  final NibTransition? transition;

  /// Accessible name. Defaults to [label] when set.
  final String? semanticLabel;

  /// Passed straight through to the underlying [InkWell].
  final FocusNode? focusNode;

  /// Passed straight through to the underlying [InkWell].
  final bool autofocus;

  bool get _enabled => !disabled && !loading && onChanged != null;

  NibTransition get _transition =>
      transition ?? const NibTransition(duration: Duration(milliseconds: 150));

  void _handleTap() {
    if (!_enabled) return;
    onChanged!(!value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final enabled = _enabled;
    final track = _buildTrack(context, theme, enabled);

    final Widget core = label == null
        ? ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Align(widthFactor: 1, heightFactor: 1, child: track),
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
                track,
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
      toggled: value,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: InkWell(
        onTap: enabled ? _handleTap : null,
        focusNode: focusNode,
        autofocus: autofocus,
        customBorder: const StadiumBorder(),
        child: core,
      ),
    );
  }

  Widget _buildTrack(BuildContext context, NibTheme theme, bool enabled) {
    final w = trackWidth ?? 44;
    final h = trackHeight ?? 24;
    final thumbSize = h - 4;
    final onColor = activeColor ?? theme.primary;
    final trackColor = value ? onColor : theme.border;
    final left = value ? (w - thumbSize - 2) : 2.0;

    final thumb = _buildThumb(context, theme, thumbSize, enabled, trackColor);

    // A persisted (unkeyed) NibMotion whose `initial`/`animate` both track
    // `left` tweens smoothly across rebuilds (see nib_pagination.dart's
    // active pill for the same idiom) — it must stay at this exact tree
    // position on every build, or Flutter treats it as a brand-new widget
    // and the thumb "hops" to the new position instead of gliding.
    final Widget thumbLayer = animated
        ? Positioned(
            top: 2,
            left: 0,
            child: NibMotion(
              initial: NibAnim(x: left),
              animate: NibAnim(x: left),
              transition: _transition,
              child: thumb,
            ),
          )
        : Positioned(top: 2, left: left, child: thumb);

    final visual = SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(h / 2),
            ),
          ),
          thumbLayer,
        ],
      ),
    );

    // Opacity always wraps `visual` (only its `opacity` value changes) —
    // conditionally inserting/removing the wrapper itself would be the same
    // remount-hop bug this fixes, one level up.
    return Opacity(opacity: enabled ? 1 : 0.5, child: visual);
  }

  Widget _buildThumb(
    BuildContext context,
    NibTheme theme,
    double size,
    bool enabled,
    Color spinnerColor,
  ) {
    if (thumbBuilder != null) {
      return SizedBox(
        width: size,
        height: size,
        child: thumbBuilder!(
          context,
          NibSwitchThumbState(
            value: value,
            enabled: enabled,
            loading: loading,
            size: size,
          ),
        ),
      );
    }

    Widget? content;
    if (loading) {
      content = NibCircularLoader(
        size: size - 6,
        strokeWidth: 2,
        color: spinnerColor,
      );
    } else {
      final icon = value ? onThumbIcon : offThumbIcon;
      if (icon != null) {
        content = SizedBox(
          width: size * 0.65,
          height: size * 0.65,
          child: FittedBox(fit: BoxFit.contain, child: icon),
        );
      }
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        shape: thumbShape ?? const CircleBorder(),
        color: theme.card,
      ),
      child: content,
    );
  }
}
