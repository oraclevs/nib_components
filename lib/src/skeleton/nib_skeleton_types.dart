import 'package:flutter/widgets.dart';

/// The bone shape [NibSkeletonBone] paints.
enum NibSkeletonShape {
  /// A rounded rectangle.
  rectangle,

  /// A perfect circle.
  circle,
}

/// An explicit bone-shape override for a spot in `NibSkeleton`'s child tree
/// its automatic detector can't shape correctly (e.g. a custom-painted
/// chart). While the ambient `NibSkeleton` is loading, this renders the
/// given [width]/[height]/[shape] instead of [child]; while not loading, it
/// renders [child] normally — the same "one authored tree" rule every other
/// spot in a `NibSkeleton` follows.
class NibSkeletonBone extends StatelessWidget {
  /// Creates an explicit bone override wrapping [child].
  const NibSkeletonBone({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.shape = NibSkeletonShape.rectangle,
  });

  /// The real widget shown whenever this node isn't being shaded.
  final Widget child;

  /// Bone box width. `null` falls back to the ambient `NibSkeleton`'s
  /// `fallbackWidth`.
  final double? width;

  /// Bone box height. `null` falls back to the ambient `NibSkeleton`'s
  /// `fallbackHeight`.
  final double? height;

  /// Bone box shape.
  final NibSkeletonShape shape;

  @override
  Widget build(BuildContext context) => child;
}

/// Marks [child] as always rendered as-is, loading or not — e.g. a static
/// logo/icon that isn't data-dependent and shouldn't be boned. The ambient
/// `NibSkeleton`'s shader does not recurse into [child] either, so content
/// inside stays real even while everything around it is a bone.
class NibSkeletonIgnore extends StatelessWidget {
  /// Creates a marker that always renders [child] unshaded.
  const NibSkeletonIgnore({super.key, required this.child});

  /// The widget shown unconditionally.
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
