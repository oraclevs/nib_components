import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibGlass, NibMotion, NibTransition;

import '../theme/nib_theme.dart';

/// Unit direction (center → [pointer]) used to aim the glass's specular
/// highlight at the pointer. Falls back to "from the top" when the size is empty
/// or the pointer sits exactly at the center. Pure — unit-tested directly.
Offset glassLightFromPointer(Offset pointer, Size size) {
  if (size.isEmpty || !size.isFinite) return const Offset(0, -1);
  final v = pointer - size.center(Offset.zero);
  final len = v.distance;
  if (len == 0 || !len.isFinite) return const Offset(0, -1);
  return v / len;
}

/// A "liquid glass" container — Apple's Liquid Glass material as a Flutter box.
///
/// Built on `nib_motion`'s [NibGlass] engine (which models the glass as a
/// [thickness]-px-deep dome and bends the backdrop through it with real
/// Snell's-law refraction — plus chromatic dispersion, a saturation boost and
/// background-derived rim lighting — via the bundled `liquid_glass.frag`
/// shader on Impeller, and falls back to a frosted blur +
/// painted rim elsewhere). This component adds the
/// ergonomic layer: `NibTheme` token defaults, an [interactive] mode where the
/// specular highlight tracks the pointer and a press gives a subtle scale (via
/// `nib_motion`, under the [animated] contract), and full shape control through
/// [borderRadius] or a custom [clipper].
///
/// Simplest usage wraps any content over a busy background:
///
/// ```dart
/// NibLiquidGlass(
///   child: Padding(padding: EdgeInsets.all(20), child: Text('Glass')),
/// )
/// ```
class NibLiquidGlass extends StatefulWidget {
  const NibLiquidGlass({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius,
    this.clipper,
    this.blurSigma = 1,
    this.tint,
    this.thickness = 24,
    this.refractiveIndex = 1.2,
    this.chromaticAberration = 0.03,
    this.saturation = 1.3,
    this.highlight = 0.5,
    this.showBorder = true,
    this.interactive = true,
    this.restLightDirection = const Offset(-0.4, -1),
    this.animated = false,
    this.transition,
  });

  /// Content painted on top of the glass.
  final Widget child;

  /// Optional explicit size for the glass box.
  final double? width;
  final double? height;

  /// Inset around [child].
  final EdgeInsetsGeometry padding;

  /// Corner radius (ignored when [clipper] is set). Defaults to a rounded 24px.
  final BorderRadius? borderRadius;

  /// Custom shape (capsule, blob, arbitrary path) — overrides [borderRadius].
  final CustomClipper<Path>? clipper;

  /// Backdrop blur amount. Near zero by default — liquid glass is clear, not
  /// frosted; the edge refraction ring carries the effect.
  final double blurSigma;

  /// Tint over the backdrop. Defaults to a very subtle brightness-aware white
  /// sheen — the glass stays mostly clear.
  final Color? tint;

  /// Depth of the glass dome, logical px. The center of the glass stays
  /// optically flat; the surface curves to the rim over this band, so thicker
  /// glass refracts a wider, stronger edge. Shader path only.
  final double thickness;

  /// Index of refraction — 1.0 is no bending, ~1.2 is Apple-style liquid
  /// glass. Shader path only.
  final double refractiveIndex;

  /// Red/blue dispersion strength at the refracting rim (0 disables).
  /// Shader path only.
  final double chromaticAberration;

  /// Saturation boost for the backdrop seen through the glass (1.0 = none).
  /// Shader path only.
  final double saturation;

  /// Rim-highlight (edge lighting) intensity, 0..1.
  final double highlight;

  /// Whether to stroke a subtle glass rim on top of the surface.
  final bool showBorder;

  /// Whether the pointer drives the highlight direction and a press scales the
  /// glass slightly.
  final bool interactive;

  /// Highlight direction at rest (no pointer). Points toward the light.
  final Offset restLightDirection;

  /// Opt-in press animation via `nib_motion`. `false` builds zero `NibMotion`.
  final bool animated;

  /// Timing/curve/spring for the press animation. `null` → a short ease.
  final NibTransition? transition;

  @override
  State<NibLiquidGlass> createState() => _NibLiquidGlassState();
}

class _NibLiquidGlassState extends State<NibLiquidGlass> {
  late Offset _light = widget.restLightDirection;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant NibLiquidGlass oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_pressed &&
        widget.restLightDirection != oldWidget.restLightDirection) {
      _light = widget.restLightDirection;
    }
  }

  void _aim(Offset localPosition) {
    if (!widget.interactive) return;
    // Measure from the laid-out render box (always finite) rather than a
    // LayoutBuilder's constraints, which can be unbounded inside a Row/ListView
    // and would produce a NaN light vector (blanking the shader layer).
    final size = context.size;
    if (size == null || size.isEmpty || !size.isFinite) return;
    final light = glassLightFromPointer(localPosition, size);
    if (light == _light) return;
    setState(() => _light = light);
  }

  void _reset() {
    if (!widget.interactive) return;
    setState(() {
      _light = widget.restLightDirection;
      _pressed = false;
    });
  }

  void _setPressed(bool pressed) {
    if (!widget.interactive || _pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  BorderRadius _radius(NibTheme theme) =>
      widget.borderRadius ?? const BorderRadius.all(Radius.circular(24));

  Color _tint(BuildContext context) {
    if (widget.tint != null) return widget.tint!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Barely-there tint — real liquid glass is nearly invisible; the refraction
    // and rim carry the look, not a tint wash.
    return dark ? const Color(0x0AFFFFFF) : const Color(0x0DFFFFFF);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final radius = _radius(theme);

    Widget content = Padding(padding: widget.padding, child: widget.child);
    if (widget.showBorder) {
      content = Stack(
        fit: StackFit.passthrough,
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.clipper == null ? radius : null,
                  border: Border.all(color: const Color(0x26FFFFFF), width: 1),
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget glass = NibGlass(
      borderRadius: radius,
      clipper: widget.clipper,
      blurSigma: widget.blurSigma,
      tint: _tint(context),
      thickness: widget.thickness,
      refractiveIndex: widget.refractiveIndex,
      chromaticAberration: widget.chromaticAberration,
      saturation: widget.saturation,
      highlight: widget.highlight,
      lightDirection: _light,
      child: content,
    );

    if (widget.animated) {
      glass = NibMotion(
        initial: NibAnim.identity,
        animate: NibAnim(scale: _pressed ? 0.98 : 1.0),
        transition:
            widget.transition ??
            const NibTransition(duration: Duration(milliseconds: 140)),
        child: glass,
      );
    }

    Widget sized = (widget.width != null || widget.height != null)
        ? SizedBox(width: widget.width, height: widget.height, child: glass)
        : glass;

    if (!widget.interactive) return sized;

    return MouseRegion(
      onHover: (e) => _aim(e.localPosition),
      onExit: (_) => _reset(),
      child: Listener(
        onPointerDown: (e) {
          _setPressed(true);
          _aim(e.localPosition);
        },
        onPointerMove: (e) => _aim(e.localPosition),
        onPointerUp: (_) => _reset(),
        onPointerCancel: (_) => _reset(),
        child: sized,
      ),
    );
  }
}
