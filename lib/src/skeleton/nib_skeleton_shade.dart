import 'package:flutter/widgets.dart';

import 'nib_skeleton_types.dart';

/// Resolved bone-fill colours, theme radii, and fallback sizing for one
/// [shadeWidget] call. Internal plumbing — not exported from the package
/// barrel (same convention as `nib_resizable_panels_math.dart`).
class NibSkeletonPalette {
  const NibSkeletonPalette({
    required this.baseColor,
    required this.shimmerColor,
    required this.radiusSm,
    required this.radiusDefault,
    required this.fallbackWidth,
    required this.fallbackHeight,
    required this.boxRadius,
  });

  final Color baseColor;
  final Color shimmerColor;
  final double radiusSm;
  final double radiusDefault;
  final double fallbackWidth;
  final double fallbackHeight;

  /// Caller override for generic box bones' corner radius. `null` means
  /// "use [radiusDefault]" — text-line and circle bones ignore this
  /// entirely (they have their own fixed rule).
  final BorderRadius? boxRadius;
}

/// Builds one bone placeholder box: a coloured, optionally-circular
/// rectangle sized from [width]/[height] (falling back to
/// [NibSkeletonPalette.fallbackWidth]/[fallbackHeight] when unset).
Widget buildBoneBox({
  required NibSkeletonPalette palette,
  double? width,
  double? height,
  NibSkeletonShape shape = NibSkeletonShape.rectangle,
  BorderRadius? radius,
}) {
  final isCircle = shape == NibSkeletonShape.circle;
  return SizedBox(
    width: width ?? palette.fallbackWidth,
    height: height ?? palette.fallbackHeight,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: palette.baseColor,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle
            ? null
            : (radius ?? palette.boxRadius ?? BorderRadius.circular(palette.radiusDefault)),
      ),
    ),
  );
}

/// Recognized leaf widget types → a bone shape sized from the node's own
/// constructor params. Returns `null` when [node] isn't a recognized leaf,
/// so [shadeWidget] can try the next bucket. Implemented in Task 3.
Widget? shadeLeaf(BuildContext context, Widget node, NibSkeletonPalette palette) {
  return null;
}

/// Recognized structural widget types → the same widget type rebuilt with
/// its children individually shaded. Returns `null` when [node] isn't a
/// recognized structural type. Implemented in Task 4.
Widget? shadeStructural(BuildContext context, Widget node, NibSkeletonPalette palette) {
  return null;
}

/// Shades [node] into its bone-loading representation. Called once per
/// build by `NibSkeleton` when `loading: true`.
///
/// Dispatch order: [NibSkeletonIgnore]/[NibSkeletonBone] (explicit author
/// overrides, always win) → [shadeLeaf] → [shadeStructural] → auto-expand
/// any other `StatelessWidget` by calling its own `build(context)` and
/// recursing into the result (Task 5) → a flat fallback bone box for
/// anything else (a `StatefulWidget`, a custom-painted widget, or a
/// `build()` call that threw).
Widget shadeWidget(BuildContext context, Widget node, NibSkeletonPalette palette) {
  if (node is NibSkeletonIgnore) {
    return node.child;
  }
  if (node is NibSkeletonBone) {
    return buildBoneBox(
      palette: palette,
      width: node.width,
      height: node.height,
      shape: node.shape,
    );
  }

  final leaf = shadeLeaf(context, node, palette);
  if (leaf != null) return leaf;

  final structural = shadeStructural(context, node, palette);
  if (structural != null) return structural;

  if (node is StatelessWidget) {
    try {
      final built = node.build(context);
      return shadeWidget(context, built, palette);
    } catch (_) {
      return buildBoneBox(palette: palette);
    }
  }

  return buildBoneBox(palette: palette);
}
