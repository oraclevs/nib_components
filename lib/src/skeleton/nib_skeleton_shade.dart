import 'package:flutter/material.dart' show CircleAvatar, SelectableText;
import 'package:flutter/widgets.dart';
import 'package:nib_motion/nib_motion.dart' show NibShimmer;

import 'nib_skeleton_render_mount.dart';
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
    this.shimmerEnabled = false,
    this.boneSpacing = 0,
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

  /// Whether [buildBoneBox] wraps each bone it builds in its own
  /// [NibShimmer], clipped to that bone's own shape. `false` (default)
  /// builds zero `NibShimmer` widgets.
  ///
  /// Deliberately per-box, not once around the whole shaded tree: `NibShimmer`
  /// paints its shader as a single solid rectangle across its *entire*
  /// bounding box, with no awareness of what shape is actually underneath —
  /// wrapping an assembled multi-shape tree in one `NibShimmer` flattens
  /// every distinct bone into one undifferentiated rectangle.
  final bool shimmerEnabled;

  /// Extra gap inserted between each pair of consecutive children in a
  /// shaded `Row`/`Column`/`Flex`, on top of whatever real spacing the
  /// author's own layout already has. `0` (default) adds none — the bone
  /// tree mirrors the real layout's spacing exactly.
  final double boneSpacing;
}

/// Builds one bone placeholder box: a coloured, optionally-circular
/// rectangle sized from [width]/[height] (falling back to
/// [NibSkeletonPalette.fallbackWidth]/[fallbackHeight] when unset). Wrapped
/// in its own clipped [NibShimmer] when [NibSkeletonPalette.shimmerEnabled].
Widget buildBoneBox({
  required NibSkeletonPalette palette,
  double? width,
  double? height,
  NibSkeletonShape shape = NibSkeletonShape.rectangle,
  BorderRadius? radius,
}) {
  final isCircle = shape == NibSkeletonShape.circle;
  final resolvedRadius = isCircle
      ? null
      : (radius ?? palette.boxRadius ?? BorderRadius.circular(palette.radiusDefault));
  final box = DecoratedBox(
    decoration: BoxDecoration(
      color: palette.baseColor,
      shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: resolvedRadius,
    ),
  );

  Widget content = box;
  if (palette.shimmerEnabled) {
    final shimmer = NibShimmer(
      enabled: true,
      baseColor: palette.baseColor,
      shimmerColor: palette.shimmerColor,
      child: box,
    );
    content = isCircle
        ? ClipOval(child: shimmer)
        : ClipRRect(borderRadius: resolvedRadius ?? BorderRadius.zero, child: shimmer);
  }

  return SizedBox(
    width: width ?? palette.fallbackWidth,
    height: height ?? palette.fallbackHeight,
    child: content,
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
    // Only a fully-sized childless SizedBox (both width and height set —
    // e.g. an image/avatar placeholder authored as a bare SizedBox) becomes
    // a visible bone. A single-axis SizedBox (SizedBox(width: 12)) is the
    // idiomatic Flutter spacer, not content — boning it would paint a small
    // connector block that visually merges the two bones it was meant to
    // separate, so it's returned unchanged (invisible) instead.
    if (node.width != null && node.height != null) {
      return buildBoneBox(palette: palette, width: node.width, height: node.height);
    }
    return node;
  }
  return null;
}

/// Recognized structural widget types → the same widget type rebuilt with
/// its children individually shaded. Returns `null` when [node] isn't a
/// recognized structural type.
Widget? shadeStructural(BuildContext context, Widget node, NibSkeletonPalette palette) {
  Widget rec(Widget child) => shadeWidget(context, child, palette);
  Widget? recOrNull(Widget? child) => child == null ? null : rec(child);
  List<Widget> recAll(List<Widget> children) => children.map(rec).toList(growable: false);
  List<Widget> recAllSpaced(List<Widget> children, Axis axis) {
    final shaded = recAll(children);
    if (palette.boneSpacing <= 0 || shaded.length < 2) return shaded;
    final gap = axis == Axis.horizontal
        ? SizedBox(width: palette.boneSpacing)
        : SizedBox(height: palette.boneSpacing);
    final spaced = <Widget>[];
    for (var i = 0; i < shaded.length; i++) {
      if (i > 0) spaced.add(gap);
      spaced.add(shaded[i]);
    }
    return spaced;
  }

  if (node is Padding) {
    return Padding(padding: node.padding, child: recOrNull(node.child));
  }
  if (node is Center) {
    return Center(
      widthFactor: node.widthFactor,
      heightFactor: node.heightFactor,
      child: recOrNull(node.child),
    );
  }
  if (node is Align) {
    return Align(
      alignment: node.alignment,
      widthFactor: node.widthFactor,
      heightFactor: node.heightFactor,
      child: recOrNull(node.child),
    );
  }
  if (node is Expanded) {
    return Expanded(flex: node.flex, child: rec(node.child));
  }
  if (node is Flexible) {
    return Flexible(flex: node.flex, fit: node.fit, child: rec(node.child));
  }
  if (node is Row) {
    return Row(
      mainAxisAlignment: node.mainAxisAlignment,
      mainAxisSize: node.mainAxisSize,
      crossAxisAlignment: node.crossAxisAlignment,
      textDirection: node.textDirection,
      verticalDirection: node.verticalDirection,
      textBaseline: node.textBaseline,
      children: recAllSpaced(node.children, Axis.horizontal),
    );
  }
  if (node is Column) {
    return Column(
      mainAxisAlignment: node.mainAxisAlignment,
      mainAxisSize: node.mainAxisSize,
      crossAxisAlignment: node.crossAxisAlignment,
      textDirection: node.textDirection,
      verticalDirection: node.verticalDirection,
      textBaseline: node.textBaseline,
      children: recAllSpaced(node.children, Axis.vertical),
    );
  }
  if (node is Flex) {
    return Flex(
      direction: node.direction,
      mainAxisAlignment: node.mainAxisAlignment,
      mainAxisSize: node.mainAxisSize,
      crossAxisAlignment: node.crossAxisAlignment,
      textDirection: node.textDirection,
      verticalDirection: node.verticalDirection,
      textBaseline: node.textBaseline,
      clipBehavior: node.clipBehavior,
      children: recAllSpaced(node.children, node.direction),
    );
  }
  if (node is Stack) {
    return Stack(
      alignment: node.alignment,
      textDirection: node.textDirection,
      fit: node.fit,
      clipBehavior: node.clipBehavior,
      children: recAll(node.children),
    );
  }
  if (node is Wrap) {
    return Wrap(
      direction: node.direction,
      alignment: node.alignment,
      spacing: node.spacing,
      runAlignment: node.runAlignment,
      runSpacing: node.runSpacing,
      crossAxisAlignment: node.crossAxisAlignment,
      textDirection: node.textDirection,
      verticalDirection: node.verticalDirection,
      clipBehavior: node.clipBehavior,
      children: recAll(node.children),
    );
  }
  if (node is ConstrainedBox) {
    return ConstrainedBox(constraints: node.constraints, child: recOrNull(node.child));
  }
  if (node is SizedBox && node.child != null) {
    return SizedBox(width: node.width, height: node.height, child: rec(node.child!));
  }
  if (node is Container && node.child != null) {
    return Container(
      alignment: node.alignment,
      padding: node.padding,
      color: node.color,
      decoration: node.decoration,
      foregroundDecoration: node.foregroundDecoration,
      constraints: node.constraints,
      margin: node.margin,
      transform: node.transform,
      transformAlignment: node.transformAlignment,
      clipBehavior: node.clipBehavior,
      child: rec(node.child!),
    );
  }
  if (node is DecoratedBox && node.child != null) {
    return DecoratedBox(
      decoration: node.decoration,
      position: node.position,
      child: rec(node.child!),
    );
  }
  if (node is ColoredBox && node.child != null) {
    return ColoredBox(color: node.color, child: rec(node.child!));
  }
  return null;
}

/// Shades [node] into its bone-loading representation. Called once per
/// build by `NibSkeleton` when `loading: true`.
///
/// Dispatch order: [NibSkeletonIgnore]/[NibSkeletonBone] (explicit author
/// overrides, always win) → [shadeLeaf] → [shadeStructural] → auto-expand
/// any other `StatelessWidget` by calling its own `build(context)` and
/// recursing into the result → route a `StatefulWidget` through
/// [NibSkeletonRenderMount] (mounts it for real — correct lifecycle — and
/// substitutes bone boxes only at paint time, via `computeBonePaintCommands`;
/// see `docs/superpowers/specs/2026-07-19-skeleton-render-mount.md`) → a flat
/// fallback bone box for anything else (a custom-painted widget, or a
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

  if (node is StatefulWidget) {
    return NibSkeletonRenderMount(palette: palette, child: node);
  }

  return buildBoneBox(palette: palette);
}
