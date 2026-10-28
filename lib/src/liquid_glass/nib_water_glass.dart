import 'package:flutter/widgets.dart';
import 'package:nib_motion/nib_motion.dart';
import '../theme/nib_theme.dart';

/// Experimental water material with sharp, independently accessible content.
///
/// This additive component leaves NibLiquidGlass unchanged. It captures only
/// [background] through NibMotion. Give it finite bounds. An external
/// [controller] owns configuration and disposal; otherwise this widget owns one.
class NibWaterGlass extends StatefulWidget {
  /// Creates a water scene. Set [animated] for evolving waves/body transitions.
  const NibWaterGlass({
    super.key,
    required this.background,
    this.child,
    this.controller,
    this.config = const NibWaterConfig(),
    this.drops = const [
      NibWaterDrop(id: 0, center: Offset(130, 150)),
      NibWaterDrop(id: 1, center: Offset(340, 150)),
    ],
    this.interaction = NibWaterInteraction.disturb,
    this.surface = false,
    this.paused = false,
    this.reducedMotion = false,
    this.animated = false,
    this.captureScale = 1,
    this.borderRadius,
    this.onStatus,
    this.backgroundChanges,
  });

  /// Sole sampled subtree, excluding the water and foreground.
  final Widget background;

  /// Optional invalidation for independently composited background animations.
  /// Descendant scrolling refreshes automatically. The caller owns this signal.
  final Listenable? backgroundChanges;

  /// Sharp foreground with its own application semantics and focus.
  final Widget? child;

  /// Optional externally owned controller; its config takes precedence.
  final NibWaterController? controller;

  /// Config for an internally owned controller.
  final NibWaterConfig config;

  /// Initial bodies for an owned controller; changing this list resets it.
  final List<NibWaterDrop> drops;

  /// Disturb the surface or move a droplet body explicitly.
  final NibWaterInteraction interaction;

  /// Fills the material box instead of individual drops.
  final bool surface;

  /// Suspends simulation and capture, preserving state.
  final bool paused;

  /// Static response policy. System policy takes precedence.
  final bool reducedMotion;

  /// Enables evolving motion. False applies final states immediately.
  final bool animated;

  /// Capture pixels/logical pixel, .5..2, capped to two million pixels.
  final double captureScale;

  /// Optional radius; otherwise reads NibTheme.radiusDefault.
  final BorderRadius? borderRadius;

  /// Actual resource-path report.
  final ValueChanged<NibWaterRenderStatus>? onStatus;
  @override
  State<NibWaterGlass> createState() => _NibWaterGlassState();
}

class _NibWaterGlassState extends State<NibWaterGlass> {
  NibWaterController? _owned;
  NibWaterController get _controller => widget.controller ?? _owned!;
  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _create();
  }

  void _create() =>
      _owned = NibWaterController(drops: widget.drops, config: widget.config);
  @override
  void didUpdateWidget(NibWaterGlass old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller ||
        (widget.controller == null && old.drops != widget.drops)) {
      final previous = _owned;
      _owned = null;
      if (widget.controller == null) _create();
      if (previous != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      }
    } else if (_owned != null && old.config != widget.config) {
      _owned!.configure(widget.config);
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius:
        widget.borderRadius ??
        BorderRadius.circular(NibTheme.of(context).radiusDefault),
    child: NibWaterSurface(
      controller: _controller,
      background: widget.background,
      backgroundChanges: widget.backgroundChanges,
      interaction: widget.interaction,
      surface: widget.surface,
      paused: widget.paused,
      reducedMotion: widget.reducedMotion || !widget.animated,
      captureScale: widget.captureScale,
      onStatus: widget.onStatus,
      child: widget.child,
    ),
  );
}
