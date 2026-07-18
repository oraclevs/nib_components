import 'package:flutter/widgets.dart';
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibPresence, NibShimmer, NibTransition;

import '../theme/nib_theme.dart';
import 'nib_skeleton_shade.dart';

/// Wraps [child] and, while [loading], renders an automatically-detected
/// bone/skeleton version of it instead of a hand-rebuilt parallel skeleton
/// tree — see `docs/superpowers/specs/2026-07-18-skeleton-design.md` for the
/// detection algorithm.
///
/// ```dart
/// NibSkeleton(
///   loading: isLoading,
///   animated: true,
///   child: ProfileHeader(user: user),
/// )
/// ```
class NibSkeleton extends StatelessWidget {
  /// Creates a skeleton wrapper around [child].
  const NibSkeleton({
    super.key,
    required this.loading,
    required this.child,
    this.animated = false,
    this.transition,
    this.baseColor,
    this.shimmerColor,
    this.fallbackWidth = 80,
    this.fallbackHeight = 16,
    this.borderRadius,
  });

  /// Whether to render the shaded bone tree instead of [child].
  final bool loading;

  /// The real widget tree. Rendered untouched whenever [loading] is false
  /// and [animated] is false.
  final Widget child;

  /// Opt-in `nib_motion`: a shimmer sweep on the bone tree, and an opacity
  /// dissolve when [loading] flips. `false` (default) builds **zero**
  /// `NibMotion`/`NibShimmer`/`NibPresence` widgets — the bone/real tree
  /// swap instantly.
  final bool animated;

  /// Timing/curve for the [animated] dissolve. `null` -> a short ~220ms ease.
  final NibTransition? transition;

  /// The bone fill colour. Defaults to `NibTheme.muted`.
  final Color? baseColor;

  /// The shimmer sweep's highlight colour. Defaults to a slight lightening
  /// of the resolved [baseColor] toward `NibTheme.foreground`.
  final Color? shimmerColor;

  /// Size of the fallback bone box used for any node the detector can't
  /// identify (a `StatefulWidget`, a custom-painted widget, etc).
  final double fallbackWidth;

  /// See [fallbackWidth].
  final double fallbackHeight;

  /// Overrides the default corner radius applied to generic box bones.
  /// Text-line bones (always fully rounded) and `CircleAvatar`-derived
  /// bones (always circular) ignore this.
  final BorderRadius? borderRadius;

  NibTransition get _transition =>
      transition ?? const NibTransition(duration: Duration(milliseconds: 220));

  NibSkeletonPalette _palette(BuildContext context) {
    final theme = NibTheme.of(context);
    final resolvedBase = baseColor ?? theme.muted;
    final resolvedShimmer =
        shimmerColor ?? Color.lerp(resolvedBase, theme.foreground, 0.12)!;
    return NibSkeletonPalette(
      baseColor: resolvedBase,
      shimmerColor: resolvedShimmer,
      radiusSm: theme.radiusSm,
      radiusDefault: theme.radiusDefault,
      fallbackWidth: fallbackWidth,
      fallbackHeight: fallbackHeight,
      boxRadius: borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!animated) {
      if (!loading) return child;
      return IgnorePointer(
        child: shadeWidget(context, child, _palette(context)),
      );
    }

    final palette = _palette(context);
    final bone = IgnorePointer(
      child: NibShimmer(
        enabled: true,
        baseColor: palette.baseColor,
        shimmerColor: palette.shimmerColor,
        child: shadeWidget(context, child, palette),
      ),
    );

    return NibPresence(
      children: [
        if (loading)
          NibMotion(
            key: const ValueKey('nib-skeleton-bone'),
            initial: const NibAnim(opacity: 0),
            animate: const NibAnim(opacity: 1),
            exit: const NibAnim(opacity: 0),
            transition: _transition,
            child: bone,
          )
        else
          NibMotion(
            key: const ValueKey('nib-skeleton-content'),
            initial: const NibAnim(opacity: 0),
            animate: const NibAnim(opacity: 1),
            exit: const NibAnim(opacity: 0),
            transition: _transition,
            child: child,
          ),
      ],
    );
  }
}
