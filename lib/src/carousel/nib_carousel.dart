import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibTransition;

import '../theme/nib_theme.dart';

part 'nib_carousel_controller.dart';

/// How a [NibCarousel] draws its page indicator.
enum NibCarouselIndicatorStyle {
  /// A row of round dots; the active page's dot is wider and accent-coloured.
  dots,

  /// A row of short pills; the active page's pill is elongated.
  line,

  /// No indicator.
  none,
}

/// A swipeable carousel of [items] with an optional dots/line indicator,
/// auto-play (paused while the user is interacting), a "peek" of the adjacent
/// slides, and infinite [loop] scrolling.
///
/// Built on a native [PageView] — physics, accessibility, and pointer handling
/// come for free. Usable with just [items]:
///
/// ```dart
/// NibCarousel(items: [Card1(), Card2(), Card3()])
/// ```
///
/// Drive it programmatically with a [NibCarouselController]; animation of the
/// active indicator is opt-in via [animated] (nothing routes through
/// `nib_motion` when it's `false`).
class NibCarousel extends StatefulWidget {
  const NibCarousel({
    super.key,
    required this.items,
    this.controller,
    this.height = 220,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.loop = false,
    this.peekExtent = 0,
    this.viewportFraction,
    this.indicatorStyle = NibCarouselIndicatorStyle.dots,
    this.padEnds = true,
    this.onPageChanged,
    this.animated = false,
    this.transition,
  });

  /// The slides. Each is laid out to fill the carousel's [height] and viewport
  /// width (minus any [peekExtent]).
  final List<Widget> items;

  /// Optional external controller. Never required — `NibCarousel` owns one
  /// internally when this is `null`, disposing it on unmount/controller-swap.
  final NibCarouselController? controller;

  /// The carousel's fixed height.
  final double height;

  /// Whether the carousel advances on its own. Pauses while the user drags and,
  /// when [loop] is `false`, stops at the last slide.
  final bool autoPlay;

  /// Delay between auto-play advances.
  final Duration autoPlayInterval;

  /// Whether scrolling wraps around infinitely (last → first and back).
  final bool loop;

  /// Logical pixels of the neighbouring slides to reveal on each side. Converted
  /// to a [PageView.viewportFraction] against the measured width. Ignored when
  /// [viewportFraction] is set.
  final double peekExtent;

  /// Explicit [PageView.viewportFraction] override (`1.0` = full width). Takes
  /// precedence over [peekExtent].
  final double? viewportFraction;

  /// How to draw the page indicator (or [NibCarouselIndicatorStyle.none]).
  final NibCarouselIndicatorStyle indicatorStyle;

  /// Forwarded to [PageView.padEnds] — whether the first/last slides are padded
  /// to centre when peeking.
  final bool padEnds;

  /// Called with the new logical page index whenever the visible slide changes.
  final ValueChanged<int>? onPageChanged;

  /// Opt-in `nib_motion` animation of the active indicator. `false` builds zero
  /// `NibMotion`.
  final bool animated;

  /// Timing/curve for the [animated] indicator pop. `null` → a short ~220ms
  /// ease.
  final NibTransition? transition;

  @override
  State<NibCarousel> createState() => _NibCarouselState();
}

class _NibCarouselState extends State<NibCarousel> {
  // A large base so infinite loop scrolling has room on both sides; kept a
  // multiple of the item count so page 0 maps to logical slide 0.
  static const _loopBase = 100000;
  static const _pageDuration = Duration(milliseconds: 320);
  static const _pageCurve = Curves.easeOutCubic;

  late NibCarouselController _controller;
  late bool _ownsController;

  PageController? _pageController;
  Timer? _autoTimer;
  bool _interacting = false;
  int _currentLogical = 0;

  int get _count => widget.items.length;

  int _initialRealPage() =>
      widget.loop && _count > 0 ? _loopBase - (_loopBase % _count) : 0;

  int _logicalOf(int real) => _count == 0 ? 0 : real % _count;

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
    _restartAutoPlay();
  }

  @override
  void didUpdateWidget(covariant NibCarousel old) {
    super.didUpdateWidget(old);
    if (widget.controller != old.controller) {
      _unbindController();
      _bindController(widget.controller);
    }
    if (widget.autoPlay != old.autoPlay ||
        widget.autoPlayInterval != old.autoPlayInterval ||
        widget.loop != old.loop) {
      _restartAutoPlay();
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController?.dispose();
    _unbindController();
    super.dispose();
  }

  // --- Controller binding ----------------------------------------------------

  void _bindController(NibCarouselController? external) {
    _controller = external ?? NibCarouselController();
    _ownsController = external == null;
    _controller._attach(this);
    _controller._sync(_currentLogical);
  }

  void _unbindController() {
    _controller._detach(this);
    if (_ownsController) _controller.dispose();
  }

  // --- Page controller / viewport --------------------------------------------

  double _resolveViewportFraction(double width) {
    if (widget.viewportFraction != null) {
      return widget.viewportFraction!.clamp(0.05, 1.0);
    }
    if (widget.peekExtent <= 0 || width <= 0) return 1.0;
    return ((width - 2 * widget.peekExtent) / width).clamp(0.2, 1.0);
  }

  PageController _ensureController(double width) {
    // Created once, on first layout, so its viewportFraction matches the peek.
    _pageController ??= PageController(
      initialPage: _initialRealPage(),
      viewportFraction: _resolveViewportFraction(width),
    );
    return _pageController!;
  }

  // --- Navigation ------------------------------------------------------------

  void _goRelative(int delta) {
    final pc = _pageController;
    if (pc == null || !pc.hasClients || _count == 0) return;
    final current = (pc.page ?? pc.initialPage.toDouble()).round();
    if (!widget.loop) {
      final targetLogical = _logicalOf(current) + delta;
      if (targetLogical < 0 || targetLogical >= _count) return;
    }
    pc.animateToPage(
      current + delta,
      duration: _pageDuration,
      curve: _pageCurve,
    );
  }

  void _goToLogical(int logical, {required bool animate}) {
    final pc = _pageController;
    if (pc == null || !pc.hasClients || _count == 0) return;
    int targetReal;
    if (widget.loop) {
      final current = (pc.page ?? pc.initialPage.toDouble()).round();
      targetReal = current + (logical - _logicalOf(current));
    } else {
      targetReal = logical.clamp(0, _count - 1);
    }
    if (animate) {
      pc.animateToPage(targetReal, duration: _pageDuration, curve: _pageCurve);
    } else {
      pc.jumpToPage(targetReal);
    }
  }

  void _onPageChanged(int real) {
    final logical = _logicalOf(real);
    if (logical == _currentLogical) return;
    setState(() => _currentLogical = logical);
    _controller._sync(logical);
    widget.onPageChanged?.call(logical);
  }

  // --- Auto-play -------------------------------------------------------------

  void _restartAutoPlay() {
    _autoTimer?.cancel();
    if (!widget.autoPlay || _count < 2) return;
    _autoTimer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (_interacting) return;
      final pc = _pageController;
      if (pc == null || !pc.hasClients) return;
      final current = (pc.page ?? pc.initialPage.toDouble()).round();
      if (!widget.loop && _logicalOf(current) >= _count - 1) {
        _autoTimer?.cancel();
        return;
      }
      pc.animateToPage(current + 1, duration: _pageDuration, curve: _pageCurve);
    });
  }

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return SizedBox(height: widget.height);
    final theme = NibTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final pc = _ensureController(constraints.maxWidth);
              return Listener(
                onPointerDown: (_) => _interacting = true,
                onPointerUp: (_) => _interacting = false,
                onPointerCancel: (_) => _interacting = false,
                child: PageView.builder(
                  controller: pc,
                  padEnds: widget.padEnds,
                  itemCount: widget.loop ? null : _count,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) =>
                      widget.items[_logicalOf(index)],
                ),
              );
            },
          ),
        ),
        if (widget.indicatorStyle != NibCarouselIndicatorStyle.none) ...[
          const SizedBox(height: 12),
          _buildIndicator(theme),
        ],
      ],
    );
  }

  Widget _buildIndicator(NibTheme theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: NibCarouselDot(
              active: i == _currentLogical,
              color: theme.primary,
              inactiveColor: theme.mutedForeground,
              radius: theme.radiusPill,
              style: widget.indicatorStyle,
              animated: widget.animated,
              transition: widget.transition,
            ),
          ),
      ],
    );
  }
}

/// A single page-indicator mark for a [NibCarousel]. Public so a consumer's
/// tests can count them; you rarely construct one directly.
class NibCarouselDot extends StatelessWidget {
  const NibCarouselDot({
    super.key,
    required this.active,
    required this.color,
    required this.inactiveColor,
    this.radius = 9999,
    this.style = NibCarouselIndicatorStyle.dots,
    this.animated = false,
    this.transition,
  });

  final bool active;
  final Color color;
  final Color inactiveColor;
  final double radius;
  final NibCarouselIndicatorStyle style;
  final bool animated;
  final NibTransition? transition;

  @override
  Widget build(BuildContext context) {
    final isLine = style == NibCarouselIndicatorStyle.line;
    final height = isLine ? 4.0 : 7.0;
    final width = active ? (isLine ? 20.0 : 9.0) : 7.0;

    final dot = SizedBox(
      height: 9,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active ? color : inactiveColor.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: SizedBox(width: width, height: height),
        ),
      ),
    );

    if (!animated) return dot;
    // Only the active dot pops in; keying by [active] replays it each time a
    // dot becomes the current page.
    return NibMotion(
      key: ValueKey(active),
      initial: NibAnim(scale: active ? 0.5 : 1, opacity: active ? 0.4 : 1),
      animate: NibAnim.identity,
      transition:
          transition ??
          const NibTransition(duration: Duration(milliseconds: 220)),
      child: dot,
    );
  }
}
