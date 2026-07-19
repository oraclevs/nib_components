import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibPresence, NibTransition;

import '../overlay/measure_size.dart';
import '../overlay/overlay_positioning.dart';
import '../theme/nib_theme.dart';
import 'nib_hover_card_controller.dart';

/// Which side of the trigger a [NibHoverCard] prefers to open toward. Flips to
/// the opposite side automatically when there isn't room, and clamps to the
/// viewport edges — the shared `NibAnchoredOverlay` positioning logic (the same
/// core `NibPopover`/`NibSelect` build on).
enum NibHoverCardPlacement { bottom, top, start, end }

NibOverlayPlacement _toOverlayPlacement(NibHoverCardPlacement p) {
  switch (p) {
    case NibHoverCardPlacement.bottom:
      return NibOverlayPlacement.bottom;
    case NibHoverCardPlacement.top:
      return NibOverlayPlacement.top;
    case NibHoverCardPlacement.start:
      return NibOverlayPlacement.start;
    case NibHoverCardPlacement.end:
      return NibOverlayPlacement.end;
  }
}

/// A native anchored hover card: a [trigger] that reveals a floating [content]
/// panel when the pointer hovers over it, and hides it again shortly after the
/// pointer leaves. Positioning reuses the shared `NibAnchoredOverlay` core
/// (auto-flip + viewport clamp) — the same primitive `NibPopover` uses.
///
/// Built for desktop/web hover, it degrades gracefully on touch: tapping the
/// trigger toggles the card (disable with [openOnTap]`: false`), and an outside
/// tap dismisses a tap-opened card. Unlike a modal, it never dims the app or
/// **steals focus** from the trigger — hovering onto the card itself keeps it
/// open, so the content stays reachable.
///
/// Simplest usage needs only [trigger] and [content]:
///
/// ```dart
/// NibHoverCard(
///   trigger: Text('@flutter'),
///   content: Text('The Flutter team account.'),
/// )
/// ```
///
/// [showDelay]/[hideDelay] tune the hover-intent timing so quick pass-overs
/// don't flicker the card. Drive it programmatically with a [controller].
class NibHoverCard extends StatefulWidget {
  const NibHoverCard({
    super.key,
    this.trigger,
    this.controller,
    required this.content,
    this.placement = NibHoverCardPlacement.bottom,
    this.showDelay = const Duration(milliseconds: 700),
    this.hideDelay = const Duration(milliseconds: 300),
    this.gap = 8,
    this.maxWidth = 320,
    this.openOnTap = true,
    this.animated = false,
    this.transition,
    this.enterFrom,
    this.onOpen,
    this.onClose,
    this.semanticLabel,
  });

  /// The widget the pointer hovers over to reveal the card. Optional — omit and
  /// drive via [controller].
  final Widget? trigger;

  /// Optional external open/closed controller. Never required — `NibHoverCard`
  /// owns one internally when this is `null`, disposing it on
  /// unmount/controller-swap. Hover/tap intent still drives it when present.
  final NibHoverCardController? controller;

  final Widget content;

  /// Preferred side to open toward (auto-flips/clamps when it doesn't fit).
  final NibHoverCardPlacement placement;

  /// How long the pointer must rest on the trigger before the card opens. Tuned
  /// so a quick pass-over doesn't flash the card.
  final Duration showDelay;

  /// How long after the pointer leaves both the trigger and the card before it
  /// closes. The grace period lets the pointer cross the [gap] onto the card
  /// without it closing.
  final Duration hideDelay;

  /// Distance in logical pixels between the trigger and the content.
  final double gap;

  /// Ceiling width for the content panel.
  final double maxWidth;

  /// Whether tapping the trigger toggles the card — the touch-platform fallback
  /// where hover doesn't exist. `false` makes the card hover-only.
  final bool openOnTap;

  /// Opt-in enter/exit animation via `nib_motion`. `false` builds zero
  /// `NibMotion`/`NibPresence` overhead.
  final bool animated;

  /// Timing/curve/spring for the [animated] transition. `null` → a short ~140ms
  /// ease.
  final NibTransition? transition;

  /// Raw escape hatch: the [NibAnim] "from" state the panel animates out of on
  /// open and into on close, overriding the default fade+scale+slide.
  final NibAnim? enterFrom;

  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  /// Accessibility label for the trigger.
  final String? semanticLabel;

  @override
  State<NibHoverCard> createState() => _NibHoverCardState();
}

class _NibHoverCardState extends State<NibHoverCard> {
  late NibHoverCardController _controller;
  late bool _ownsController;

  final _link = LayerLink();
  OverlayEntry? _overlayEntry;

  Timer? _openTimer;
  Timer? _closeTimer;
  Timer? _exitTimer;
  bool _closing = false;

  /// Whether the current open was triggered by a tap (touch fallback) rather
  /// than a hover — a tap-opened card gets an outside-tap barrier to dismiss it;
  /// a hover-opened one relies on pointer-exit and stays fully non-modal.
  bool _openedByTap = false;

  final _cardKey = const ValueKey<String>('nib-hover-card-card');

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
    if (_controller.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showOverlay();
      });
    }
  }

  @override
  void didUpdateWidget(covariant NibHoverCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _unbindController();
      _bindController(widget.controller);
    }
  }

  @override
  void dispose() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    _exitTimer?.cancel();
    _removeOverlay();
    _unbindController();
    super.dispose();
  }

  void _bindController(NibHoverCardController? external) {
    _controller = external ?? NibHoverCardController();
    _ownsController = external == null;
    _controller.addListener(_handleControllerChanged);
  }

  void _unbindController() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) _controller.dispose();
  }

  void _handleControllerChanged() {
    if (_controller.isOpen) {
      _showOverlay();
    } else {
      _beginClose();
    }
    if (mounted) setState(() {});
  }

  // --- Hover / tap intent ----------------------------------------------------

  void _scheduleOpen() {
    _closeTimer?.cancel();
    if (_controller.isOpen && !_closing) return;
    _openTimer?.cancel();
    _openTimer = Timer(widget.showDelay, () {
      _openedByTap = false;
      _controller.open();
    });
  }

  void _scheduleClose() {
    _openTimer?.cancel();
    if (!_controller.isOpen) return;
    _closeTimer?.cancel();
    _closeTimer = Timer(widget.hideDelay, _controller.close);
  }

  void _cancelClose() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _handleTap() {
    if (!widget.openOnTap) return;
    _openTimer?.cancel();
    _closeTimer?.cancel();
    _openedByTap = !_controller.isOpen;
    _controller.toggle();
  }

  void _requestClose() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    _controller.close();
  }

  // --- Overlay lifecycle -----------------------------------------------------

  void _showOverlay() {
    if (_overlayEntry != null || !mounted) return;
    _exitTimer?.cancel();
    _closing = false;
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlayEntry!);
    widget.onOpen?.call();
  }

  void _beginClose() {
    if (_overlayEntry == null) return;
    widget.onClose?.call();
    if (!widget.animated) {
      _removeOverlay();
      return;
    }
    if (_closing) return;
    _closing = true;
    _overlayEntry?.markNeedsBuild();
    _exitTimer?.cancel();
    _exitTimer = Timer(_exitDuration(), _removeOverlay);
  }

  void _removeOverlay() {
    _exitTimer?.cancel();
    _exitTimer = null;
    _closing = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  NibTransition _effectiveTransition() =>
      widget.transition ??
      const NibTransition(duration: Duration(milliseconds: 140));

  /// How long to keep the overlay mounted after a close so the exit motion can
  /// finish before removal. Springs have no fixed duration, so estimate — same
  /// approach (and same deferred caveat) as `NibPopover`/`NibSelect`.
  Duration _exitDuration() {
    final t = _effectiveTransition();
    final base = t.spring != null
        ? const Duration(milliseconds: 450)
        : t.duration;
    return base + t.delay + const Duration(milliseconds: 40);
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return const SizedBox.shrink();
    final target = box.localToGlobal(Offset.zero) & box.size;

    return _NibHoverCardOverlay(
      link: _link,
      target: target,
      placement: _toOverlayPlacement(widget.placement),
      gap: widget.gap,
      maxWidth: widget.maxWidth,
      showBarrier: _openedByTap,
      animated: widget.animated,
      transition: _effectiveTransition(),
      enterFrom: widget.enterFrom,
      closing: _closing,
      cardKey: _cardKey,
      theme: NibTheme.of(context),
      onRequestClose: _requestClose,
      onCardEnter: _cancelClose,
      onCardExit: _scheduleClose,
      child: widget.content,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trigger == null) return const SizedBox.shrink();
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) => _scheduleOpen(),
        onExit: (_) => _scheduleClose(),
        child: Semantics(
          label: widget.semanticLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.openOnTap ? _handleTap : null,
            child: widget.trigger,
          ),
        ),
      ),
    );
  }
}

/// The floating panel: measures its content, resolves the concrete side via the
/// shared positioning core, positions itself with a `CompositedTransformFollower`,
/// and plays the `nib_motion` enter/exit. Wrapped in a `MouseRegion` so hovering
/// onto the card keeps it open. No focus scope — a hover card must not steal
/// focus from its trigger.
class _NibHoverCardOverlay extends StatefulWidget {
  const _NibHoverCardOverlay({
    required this.link,
    required this.target,
    required this.placement,
    required this.gap,
    required this.maxWidth,
    required this.showBarrier,
    required this.animated,
    required this.transition,
    required this.enterFrom,
    required this.closing,
    required this.cardKey,
    required this.theme,
    required this.onRequestClose,
    required this.onCardEnter,
    required this.onCardExit,
    required this.child,
  });

  final LayerLink link;
  final Rect target;
  final NibOverlayPlacement placement;
  final double gap;
  final double maxWidth;
  final bool showBarrier;
  final bool animated;
  final NibTransition transition;
  final NibAnim? enterFrom;
  final bool closing;
  final Key cardKey;
  final NibTheme theme;
  final VoidCallback onRequestClose;
  final VoidCallback onCardEnter;
  final VoidCallback onCardExit;
  final Widget child;

  @override
  State<_NibHoverCardOverlay> createState() => _NibHoverCardOverlayState();
}

class _NibHoverCardOverlayState extends State<_NibHoverCardOverlay> {
  Size? _contentSize;

  NibAnim _defaultEnter(NibOverlaySide side) {
    const slide = 6.0;
    double x = 0;
    double y = 0;
    switch (side) {
      case NibOverlaySide.bottom:
        y = -slide;
      case NibOverlaySide.top:
        y = slide;
      case NibOverlaySide.end:
        x = -slide;
      case NibOverlaySide.start:
        x = slide;
    }
    return NibAnim(opacity: 0, scale: 0.97, x: x, y: y);
  }

  Widget _animate(NibOverlaySide side, Widget child) {
    if (!widget.animated) return child;
    final from = widget.enterFrom ?? _defaultEnter(side);
    final motion = NibMotion(
      key: widget.cardKey,
      initial: from,
      animate: NibAnim.identity,
      exit: from,
      transition: widget.transition,
      child: child,
    );
    return NibPresence(children: widget.closing ? const [] : [motion]);
  }

  Widget _buildCard() {
    final theme = widget.theme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: Material(
        color: theme.card,
        elevation: 8,
        borderRadius: BorderRadius.circular(theme.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.border),
            borderRadius: BorderRadius.circular(theme.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: widget.child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final measuredCard = MeasureSize(
      onChange: (size) {
        if (mounted && _contentSize != size) {
          setState(() => _contentSize = size);
        }
      },
      child: MouseRegion(
        onEnter: (_) => widget.onCardEnter(),
        onExit: (_) => widget.onCardExit(),
        child: _buildCard(),
      ),
    );

    final barrier = (widget.showBarrier && !widget.closing)
        ? Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onRequestClose,
            ),
          )
        : null;

    Widget wrap(Widget positioned) => Stack(children: [?barrier, positioned]);

    if (_contentSize == null) {
      // First pass: measure invisibly before we can resolve the side.
      return wrap(
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          child: Opacity(opacity: 0, child: measuredCard),
        ),
      );
    }

    final mq = MediaQuery.of(context);
    final geo = resolveOverlayGeometry(
      placement: widget.placement,
      target: widget.target,
      content: _contentSize!,
      screen: mq.size,
      safeInsets: nibOverlaySafeInsets(mq),
      gap: widget.gap,
    );

    return wrap(
      CompositedTransformFollower(
        link: widget.link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.topLeft,
        offset: geo.offset,
        child: _animate(geo.side, measuredCard),
      ),
    );
  }
}
