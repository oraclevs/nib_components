import 'dart:ui' show FragmentProgram, FragmentShader;

import 'package:flutter/material.dart' show CircleAvatar, SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';
import 'package:nib_motion/nib_motion.dart' show MotionValue, NibShaderLoader;

import 'nib_skeleton_shade.dart';
import 'nib_skeleton_types.dart';

// RenderNibSkeletonMount deliberately takes public `palette`/`time`/`program`
// constructor params and maps them to private fields (clean internal API);
// initializing formals would expose the underscored names.
// ignore_for_file: prefer_initializing_formals

/// What one [BonePaintCommand] does when drawn.
enum BonePaintKind {
  /// Paint a solid bone-coloured shape.
  bone,

  /// Paint a real [Decoration] (a `DecoratedBox`/`ColoredBox`'s own chrome —
  /// preserved so a card's background/border survives even while its content
  /// bones).
  decoration,

  /// Paint the real, already-mounted content normally (`NibSkeletonIgnore`).
  realPaintThrough,
}

/// One instruction produced by [computeBonePaintCommands]. Deliberately a
/// plain data class, not a direct `Canvas` draw call — this is what makes the
/// walker unit-testable without a real `Canvas`/golden image: tests call
/// [computeBonePaintCommands] directly and assert on the returned commands.
class BonePaintCommand {
  const BonePaintCommand.bone({
    required this.rect,
    required this.shape,
    this.radius,
  }) : kind = BonePaintKind.bone,
       decoration = null,
       renderBox = null;

  const BonePaintCommand.decoration({
    required this.rect,
    required this.decoration,
  }) : kind = BonePaintKind.decoration,
       shape = NibSkeletonShape.rectangle,
       radius = null,
       renderBox = null;

  const BonePaintCommand.realPaintThrough({
    required this.rect,
    required this.renderBox,
  }) : kind = BonePaintKind.realPaintThrough,
       shape = NibSkeletonShape.rectangle,
       radius = null,
       decoration = null;

  final BonePaintKind kind;
  final Rect rect;
  final NibSkeletonShape shape;
  final BorderRadius? radius;
  final Decoration? decoration;
  final RenderBox? renderBox;
}

Rect _rectOf(RenderBox box, RenderBox rootBox, Offset base) {
  final position = MatrixUtils.transformPoint(
    box.getTransformTo(rootBox),
    Offset.zero,
  );
  return (base + position) & box.size;
}

List<BonePaintCommand> _recurseChildren(
  Element element,
  RenderBox rootBox,
  Offset base,
  NibSkeletonPalette palette,
) {
  final commands = <BonePaintCommand>[];
  element.visitChildren((child) {
    commands.addAll(_walk(child, rootBox, base, palette));
  });
  return commands;
}

/// Walks the real, already-mounted [element] tree (built and laid out
/// normally by Flutter — including any `StatefulWidget`, with its real
/// lifecycle) and decides what to paint: a bone box, a real decoration,
/// real paint-through, or recursion into children. Every command's rect is
/// derived from the render tree's own geometry ([RenderBox.getTransformTo]
/// against the walked root's render box) rather than accumulated while
/// walking — Element hops don't map 1:1 to render hops, so accumulating
/// `parentData.offset` per hop re-adds the same offset once per
/// `ComponentElement` in a chain. See
/// `docs/superpowers/specs/2026-07-19-skeleton-mount-offsets-chrome-shimmer-design.md`.
List<BonePaintCommand> computeBonePaintCommands(
  Element element,
  Offset offset,
  NibSkeletonPalette palette,
) {
  final rootBox = element.renderObject;
  if (rootBox is! RenderBox) return const [];
  return _walk(element, rootBox, offset, palette);
}

List<BonePaintCommand> _walk(
  Element element,
  RenderBox rootBox,
  Offset base,
  NibSkeletonPalette palette,
) {
  final widget = element.widget;
  final renderObject = element.renderObject;
  final box = renderObject is RenderBox ? renderObject : null;

  if (widget is NibSkeletonIgnore) {
    if (box != null) {
      return [
        BonePaintCommand.realPaintThrough(
          rect: _rectOf(box, rootBox, base),
          renderBox: box,
        ),
      ];
    }
    return const [];
  }

  if (widget is NibSkeletonBone) {
    final realSize = box?.size;
    final size = Size(
      widget.width ?? realSize?.width ?? palette.fallbackWidth,
      widget.height ?? realSize?.height ?? palette.fallbackHeight,
    );
    final origin = box != null ? _rectOf(box, rootBox, base).topLeft : base;
    return [BonePaintCommand.bone(rect: origin & size, shape: widget.shape)];
  }

  if (widget is Text || widget is RichText || widget is SelectableText) {
    if (box != null) {
      final rect = _rectOf(box, rootBox, base);
      return [
        BonePaintCommand.bone(
          rect: rect,
          shape: NibSkeletonShape.rectangle,
          radius: BorderRadius.circular(rect.height / 2),
        ),
      ];
    }
  }

  if (widget is Icon) {
    if (box != null) {
      return [
        BonePaintCommand.bone(
          rect: _rectOf(box, rootBox, base),
          shape: NibSkeletonShape.rectangle,
          radius: BorderRadius.circular(palette.radiusSm),
        ),
      ];
    }
  }

  if (widget is CircleAvatar) {
    if (box != null) {
      return [
        BonePaintCommand.bone(
          rect: _rectOf(box, rootBox, base),
          shape: NibSkeletonShape.circle,
        ),
      ];
    }
  }

  if (widget is DecoratedBox) {
    if (box != null) {
      final chrome = BonePaintCommand.decoration(
        rect: _rectOf(box, rootBox, base),
        decoration: widget.decoration,
      );
      return [chrome, ..._recurseChildren(element, rootBox, base, palette)];
    }
  }

  if (widget is ColoredBox) {
    if (box != null) {
      final chrome = BonePaintCommand.decoration(
        rect: _rectOf(box, rootBox, base),
        decoration: BoxDecoration(color: widget.color),
      );
      return [chrome, ..._recurseChildren(element, rootBox, base, palette)];
    }
  }

  if (widget is PhysicalModel) {
    if (box != null) {
      final chrome = BonePaintCommand.decoration(
        rect: _rectOf(box, rootBox, base),
        decoration: BoxDecoration(
          color: widget.color,
          shape: widget.shape,
          borderRadius: widget.shape == BoxShape.rectangle
              ? widget.borderRadius
              : null,
        ),
      );
      return [chrome, ..._recurseChildren(element, rootBox, base, palette)];
    }
  }

  if (widget is PhysicalShape) {
    if (box != null) {
      final clipper = widget.clipper;
      // Elevation shadows are deliberately not synthesized — bones are flat.
      final chrome = BonePaintCommand.decoration(
        rect: _rectOf(box, rootBox, base),
        decoration: clipper is ShapeBorderClipper
            ? ShapeDecoration(color: widget.color, shape: clipper.shape)
            : BoxDecoration(color: widget.color),
      );
      return [chrome, ..._recurseChildren(element, rootBox, base, palette)];
    }
  }

  final recursed = _recurseChildren(element, rootBox, base, palette);
  if (recursed.isNotEmpty) return recursed;

  if (box != null) {
    return [
      BonePaintCommand.bone(
        rect: _rectOf(box, rootBox, base),
        shape: NibSkeletonShape.rectangle,
        radius: palette.boxRadius,
      ),
    ];
  }
  return const [];
}

/// Mounts [child] completely normally (real `initState`, real tickers — any
/// `StatefulWidget` resolves exactly as it would anywhere else), but paints
/// [computeBonePaintCommands]'s decision instead of the child's real pixels.
///
/// Extends [RenderObjectWidget] directly rather than
/// [SingleChildRenderObjectWidget] — the latter's `createElement()` is
/// declared to return exactly `SingleChildRenderObjectElement`, which
/// `_NibSkeletonMountElement` (a `RenderObjectElement` subclass, needed since
/// `SingleChildRenderObjectElement`'s own child tracking is private to
/// `framework.dart`) isn't a subtype of.
class NibSkeletonRenderMount extends RenderObjectWidget {
  const NibSkeletonRenderMount({
    super.key,
    required this.child,
    required this.palette,
    this.time,
    this.program,
  });

  final Widget child;
  final NibSkeletonPalette palette;

  /// Elapsed-seconds driver for the shimmer sweep — `null` when shimmer is
  /// off ([NibSkeletonPalette.shimmerEnabled] false), in which case bones
  /// paint static.
  final MotionValue<double>? time;

  /// The compiled shimmer shader — `null` until [NibShaderLoader] resolves
  /// it (or forever, in environments without shader support).
  final FragmentProgram? program;

  @override
  RenderObjectElement createElement() => _NibSkeletonMountElement(this);

  @override
  RenderNibSkeletonMount createRenderObject(BuildContext context) {
    return RenderNibSkeletonMount(
      palette: palette,
      time: time,
      program: program,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderNibSkeletonMount renderObject,
  ) {
    renderObject
      ..palette = palette
      ..time = time
      ..program = program;
  }
}

/// Re-implements `SingleChildRenderObjectElement`'s mount/update/child-slot
/// wiring (its `_child` field isn't reachable from outside `framework.dart`)
/// so the tracked child [Element] can be pushed to [RenderNibSkeletonMount]
/// for [computeBonePaintCommands] to walk during paint.
class _NibSkeletonMountElement extends RenderObjectElement {
  _NibSkeletonMountElement(NibSkeletonRenderMount super.widget);

  Element? _child;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) visitor(_child!);
  }

  @override
  void forgetChild(Element child) {
    assert(child == _child);
    _child = null;
    super.forgetChild(child);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _child = updateChild(
      _child,
      (widget as NibSkeletonRenderMount).child,
      null,
    );
    _pushRoot();
  }

  @override
  void update(NibSkeletonRenderMount newWidget) {
    super.update(newWidget);
    _child = updateChild(
      _child,
      (widget as NibSkeletonRenderMount).child,
      null,
    );
    _pushRoot();
  }

  void _pushRoot() {
    (renderObject as RenderNibSkeletonMount)
      ..rootElement = _child
      ..palette = (widget as NibSkeletonRenderMount).palette
      ..textDirection = Directionality.maybeOf(this);
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    (renderObject as RenderNibSkeletonMount).child = child as RenderBox;
  }

  @override
  void moveRenderObjectChild(
    RenderObject child,
    Object? oldSlot,
    Object? newSlot,
  ) {
    assert(false, 'NibSkeletonRenderMount has a single child slot.');
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    (renderObject as RenderNibSkeletonMount).child = null;
  }
}

/// Paints [computeBonePaintCommands]'s decision instead of delegating to the
/// real child's own `paint()`. Layout/size are inherited from
/// [RenderProxyBox] unchanged — this render object's size is always exactly
/// its child's real, normally-computed size.
class RenderNibSkeletonMount extends RenderProxyBox {
  RenderNibSkeletonMount({
    required NibSkeletonPalette palette,
    MotionValue<double>? time,
    FragmentProgram? program,
  }) : _palette = palette,
       _time = time,
       _program = program {
    _time?.addListener(_onTimeChanged);
    _shader = _program?.fragmentShader();
  }

  // NibShimmer's constructor defaults, mirrored so a render-mounted bone
  // sweeps identically to a widget-path bone wrapped in its own NibShimmer.
  static const double _shimmerSpeed = 1.5;
  static const double _shimmerAngle = -0.3;

  NibSkeletonPalette _palette;
  set palette(NibSkeletonPalette value) {
    if (_palette == value) return;
    _palette = value;
    markNeedsPaint();
  }

  TextDirection? _textDirection;

  /// The ambient [Directionality] captured by the mount's Element — used to
  /// resolve directional [Decoration]s when painting preserved chrome.
  TextDirection? get textDirection => _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsPaint();
  }

  MotionValue<double>? _time;

  /// The shimmer sweep's elapsed-time driver; `null` paints static bones.
  MotionValue<double>? get time => _time;
  set time(MotionValue<double>? value) {
    if (_time == value) return;
    _time?.removeListener(_onTimeChanged);
    _time = value;
    _time?.addListener(_onTimeChanged);
    markNeedsPaint();
  }

  FragmentProgram? _program;
  FragmentShader? _shader;
  set program(FragmentProgram? value) {
    if (_program == value) return;
    _program = value;
    _shader?.dispose();
    _shader = value?.fragmentShader();
    markNeedsPaint();
  }

  Element? rootElement;

  void _onTimeChanged() => markNeedsPaint();

  @override
  void dispose() {
    _time?.removeListener(_onTimeChanged);
    _shader?.dispose();
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final root = rootElement;
    if (root == null) return;
    for (final command in computeBonePaintCommands(root, offset, _palette)) {
      switch (command.kind) {
        case BonePaintKind.realPaintThrough:
          if (command.renderBox != null) {
            context.paintChild(command.renderBox!, command.rect.topLeft);
          }
        case BonePaintKind.decoration:
          final painter = command.decoration!.createBoxPainter();
          painter.paint(
            context.canvas,
            command.rect.topLeft,
            ImageConfiguration(
              size: command.rect.size,
              textDirection: _textDirection,
            ),
          );
          painter.dispose();
        case BonePaintKind.bone:
          _paintBone(context.canvas, command);
      }
    }
  }

  void _paintBone(Canvas canvas, BonePaintCommand command) {
    final rect = command.rect;
    final shader = _shader;
    final time = _time;
    if (shader == null || time == null) {
      final paint = Paint()..color = _palette.baseColor;
      if (command.shape == NibSkeletonShape.circle) {
        canvas.drawOval(rect, paint);
      } else if (command.radius != null) {
        canvas.drawRRect(command.radius!.toRRect(rect), paint);
      } else {
        canvas.drawRect(rect, paint);
      }
      return;
    }

    shader
      ..setFloat(0, time.value)
      ..setFloat(1, _shimmerSpeed)
      ..setFloat(2, _palette.baseColor.r)
      ..setFloat(3, _palette.baseColor.g)
      ..setFloat(4, _palette.baseColor.b)
      ..setFloat(5, _palette.baseColor.a)
      ..setFloat(6, _palette.shimmerColor.r)
      ..setFloat(7, _palette.shimmerColor.g)
      ..setFloat(8, _palette.shimmerColor.b)
      ..setFloat(9, _palette.shimmerColor.a)
      ..setFloat(10, rect.width)
      ..setFloat(11, rect.height)
      ..setFloat(12, _shimmerAngle);

    // Origin-normalized: translate so the draw's coordinates are bone-local
    // (shimmer.frag computes its band from FlutterFragCoord against uWidth,
    // with no origin uniform — drawing at a large canvas offset would shift
    // or park the band outside the bone). The shader paints base fill +
    // sweep band, so no separate solid fill is needed under it.
    final local = Offset.zero & rect.size;
    canvas.save();
    canvas.translate(rect.left, rect.top);
    if (command.shape == NibSkeletonShape.circle) {
      canvas.clipPath(Path()..addOval(local));
    } else if (command.radius != null) {
      canvas.clipRRect(command.radius!.toRRect(local));
    }
    canvas.drawRect(local, Paint()..shader = shader);
    canvas.restore();
  }
}

/// Drives the shimmer sweep for one [NibSkeletonRenderMount]: a ticker
/// writes elapsed seconds into a [MotionValue] (no widget rebuild per frame
/// — [RenderNibSkeletonMount] listens and repaints), and the shared shimmer
/// [FragmentProgram] resolves async via [NibShaderLoader] (staying `null` —
/// static bones — where shaders can't compile, e.g. `flutter test`).
/// Replicates `NibShimmer`'s own State pattern. Internal plumbing — not
/// exported from the package barrel (same convention as
/// [NibSkeletonPalette]); `shadeWidget` builds it only when
/// [NibSkeletonPalette.shimmerEnabled].
class NibSkeletonMountShimmerDriver extends StatefulWidget {
  const NibSkeletonMountShimmerDriver({
    super.key,
    required this.palette,
    required this.child,
  });

  final NibSkeletonPalette palette;
  final Widget child;

  @override
  State<NibSkeletonMountShimmerDriver> createState() =>
      _NibSkeletonMountShimmerDriverState();
}

class _NibSkeletonMountShimmerDriverState
    extends State<NibSkeletonMountShimmerDriver>
    with SingleTickerProviderStateMixin {
  final MotionValue<double> _time = MotionValue<double>(0);
  Ticker? _ticker;
  FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _loadProgram();
    _ticker = createTicker(_onTick);
    _ticker!.start();
  }

  Future<void> _loadProgram() async {
    try {
      final program = await NibShaderLoader.shimmer();
      if (!mounted) return;
      setState(() => _program = program);
    } catch (_) {
      // Shader unavailable (not bundled, or no compilation support in this
      // environment) — the mount keeps painting static bones.
    }
  }

  void _onTick(Duration elapsed) {
    _time.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NibSkeletonRenderMount(
      palette: widget.palette,
      time: _time,
      program: _program,
      child: widget.child,
    );
  }
}
