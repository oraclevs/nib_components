import 'package:flutter/material.dart' show CircleAvatar, SelectableText;
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

const _maxTextBoneWidth = 240.0;

Widget _boneForTextLike(
  BuildContext context, {
  required String? data,
  required InlineSpan? textSpan,
  required TextStyle? style,
  required int? maxLines,
  required NibSkeletonPalette palette,
}) {
  final resolvedStyle = style ?? const TextStyle(fontSize: 14);
  final span = textSpan ?? TextSpan(text: data ?? '', style: resolvedStyle);
  final painter = TextPainter(
    text: span,
    textDirection: Directionality.of(context),
    maxLines: maxLines,
  )..layout();
  final lineHeight = painter.preferredLineHeight;
  final lineCount = maxLines ?? 1;
  final rawWidth = painter.width;
  final width = (rawWidth.isFinite && rawWidth > 0)
      ? rawWidth.clamp(0.0, _maxTextBoneWidth)
      : palette.fallbackWidth;
  final height = lineHeight * lineCount;
  return buildBoneBox(
    palette: palette,
    width: width,
    height: height,
    radius: BorderRadius.circular(height / 2),
  );
}

NibSkeletonShape? _containerShape(Decoration? decoration) {
  if (decoration is BoxDecoration && decoration.shape == BoxShape.circle) {
    return NibSkeletonShape.circle;
  }
  return null;
}

BorderRadius? _containerRadius(Decoration? decoration) {
  if (decoration is BoxDecoration && decoration.borderRadius is BorderRadius) {
    return decoration.borderRadius as BorderRadius;
  }
  return null;
}

Widget _boneForChildlessContainer(Container node, NibSkeletonPalette palette) {
  final decoration = node.decoration;
  final constraints = node.constraints;
  final width = (constraints != null && constraints.hasTightWidth) ? constraints.maxWidth : null;
  final height = (constraints != null && constraints.hasTightHeight) ? constraints.maxHeight : null;
  return buildBoneBox(
    palette: palette,
    width: width,
    height: height,
    shape: _containerShape(decoration) ?? NibSkeletonShape.rectangle,
    radius: _containerRadius(decoration),
  );
}

Widget _boneForChildlessDecoratedBox(DecoratedBox node, NibSkeletonPalette palette) {
  return buildBoneBox(
    palette: palette,
    shape: _containerShape(node.decoration) ?? NibSkeletonShape.rectangle,
    radius: _containerRadius(node.decoration),
  );
}

/// Recognized leaf widget types → a bone shape sized from the node's own
/// constructor params. Returns `null` when [node] isn't a recognized leaf,
/// so [shadeWidget] can try the next bucket.
Widget? shadeLeaf(BuildContext context, Widget node, NibSkeletonPalette palette) {
  if (node is Text) {
    return _boneForTextLike(
      context,
      data: node.data,
      textSpan: node.textSpan,
      style: node.style,
      maxLines: node.maxLines,
      palette: palette,
    );
  }
  if (node is SelectableText) {
    return _boneForTextLike(
      context,
      data: node.data,
      textSpan: node.textSpan,
      style: node.style,
      maxLines: node.maxLines,
      palette: palette,
    );
  }
  if (node is RichText) {
    return _boneForTextLike(
      context,
      data: null,
      textSpan: node.text,
      style: null,
      maxLines: node.maxLines,
      palette: palette,
    );
  }
  if (node is Icon) {
    final size = node.size ?? 24.0;
    return buildBoneBox(
      palette: palette,
      width: size,
      height: size,
      radius: BorderRadius.circular(palette.radiusSm),
    );
  }
  if (node is CircleAvatar) {
    final diameter = node.radius != null
        ? node.radius! * 2
        : ((node.minRadius ?? 20.0) + (node.maxRadius ?? 20.0));
    return buildBoneBox(
      palette: palette,
      width: diameter,
      height: diameter,
      shape: NibSkeletonShape.circle,
    );
  }
  if (node is Image) {
    return buildBoneBox(palette: palette, width: node.width, height: node.height);
  }
  if (node is Container && node.child == null) {
    return _boneForChildlessContainer(node, palette);
  }
  if (node is DecoratedBox && node.child == null) {
    return _boneForChildlessDecoratedBox(node, palette);
  }
  if (node is ColoredBox && node.child == null) {
    return buildBoneBox(palette: palette);
  }
  if (node is SizedBox && node.child == null) {
    return buildBoneBox(palette: palette, width: node.width, height: node.height);
  }
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
      // @protected is a convention (package:meta lint), not a language rule —
      // calling build() ourselves ahead of the normal Element is how an
      // unrecognized composite widget gets transparently expanded (see the
      // design spec's bucket-3 rationale).
      // ignore: invalid_use_of_protected_member
      final built = node.build(context);
      return shadeWidget(context, built, palette);
    } catch (_) {
      return buildBoneBox(palette: palette);
    }
  }

  return buildBoneBox(palette: palette);
}
