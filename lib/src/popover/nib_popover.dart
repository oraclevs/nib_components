import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibPresence, NibTransition;

import '../overlay/measure_size.dart';
import '../overlay/overlay_positioning.dart';
import '../theme/nib_theme.dart';
import 'nib_popover_controller.dart';

/// Which side of the trigger a [NibPopover] prefers to open toward. Flips to the
/// opposite side automatically when there isn't room, and clamps to the viewport
/// edges — the shared `NibAnchoredOverlay` positioning logic.
enum NibPopoverPlacement { bottom, top, start, end }

NibOverlayPlacement _toOverlayPlacement(NibPopoverPlacement p) {
  switch (p) {
    case NibPopoverPlacement.bottom:
      return NibOverlayPlacement.bottom;
    case NibPopoverPlacement.top:
      return NibOverlayPlacement.top;
    case NibPopoverPlacement.start:
      return NibOverlayPlacement.start;
    case NibPopoverPlacement.end:
      return NibOverlayPlacement.end;
  }
}

/// Exposes the enclosing popover's [close] callback to its `content` subtree, so
/// a widget inside the popover can dismiss it without wiring a controller:
///
/// ```dart
/// TextButton(
///   onPressed: () => NibPopoverScope.of(context).close(),
///   child: const Text('Done'),
/// )
/// ```
class NibPopoverScope extends InheritedWidget {
  const NibPopoverScope({
    super.key,
    required this.close,
    required this.isOpen,
    required super.child,
  });

  /// Closes the popover.
  final VoidCallback close;

  /// Whether the popover is still open (not mid-close).
  final bool isOpen;

  /// The nearest enclosing popover scope. Asserts if called outside a popover.
  static NibPopoverScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NibPopoverScope>();
    assert(scope != null, 'NibPopoverScope.of() called outside a NibPopover.');
    return scope!;
  }

  @override
  bool updateShouldNotify(NibPopoverScope oldWidget) =>
      isOpen != oldWidget.isOpen || close != oldWidget.close;
}

/// A native anchored popover: a [trigger] whose tap opens a floating [content]
/// panel positioned next to it, auto-flipping and clamping to the viewport via
/// the shared `NibAnchoredOverlay` positioning core (the same primitive
/// `NibSelect`/`NibNavigationMenu` build on). Non-modal — it doesn't trap focus
/// or dim the app; an outside tap dismisses it unless [dismissOnOutsideTap] is
/// `false` (then close via a [controller] or [NibPopoverScope]).
///
/// Simplest usage needs only [trigger] and [content]:
///
/// ```dart
/// NibPopover(
///   trigger: const Icon(Icons.info_outline),
///   content: const Text('More info'),
/// )
/// ```
///
/// The [trigger] is wrapped in a tap handler that toggles the popover — pass a
/// non-interactive widget (text, icon, a custom chip). Drive it externally with
/// a [controller] when you need to.
class NibPopover extends StatefulWidget {
  const NibPopover({
    super.key,
    this.trigger,
    this.controller,
    required this.content,
    this.placement = NibPopoverPlacement.bottom,
    this.gap = 8,
    this.dismissOnOutsideTap = true,
    this.showArrow = false,
    this.barrierColor,
    this.maxWidth = 320,
    this.animated = false,
    this.transition,
    this.enterFrom,
    this.onOpen,
    this.onClose,
    this.semanticLabel,
  });

  /// Tapping this toggles the popover. Optional — omit and drive via
  /// [controller].
  final Widget? trigger;

  /// Optional external open/closed controller. Never required — `NibPopover`
  /// owns one internally when this is `null`, disposing it on
  /// unmount/controller-swap.
  final NibPopoverController? controller;

  final Widget content;

  /// Preferred side to open toward (auto-flips/clamps when it doesn't fit).
  final NibPopoverPlacement placement;

  /// Distance in logical pixels between the trigger and the content (the arrow,
  /// if any, sits in this gap).
  final double gap;

  /// Whether an outside tap dismisses the popover. `false` keeps it open until
  /// closed via a [controller] or [NibPopoverScope] (an invisible tap-catching
  /// barrier is then omitted, so the app behind stays interactive).
  final bool dismissOnOutsideTap;

  /// Whether to draw a small arrow on the content pointing at the trigger.
  final bool showArrow;

  /// Optional scrim painted over the app while open. Defaults to transparent —
  /// a popover is non-modal, so the barrier only catches outside taps.
  final Color? barrierColor;

  /// Ceiling width for the content panel.
  final double maxWidth;

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
  State<NibPopover> createState() => _NibPopoverState();
}

class _NibPopoverState extends State<NibPopover> {
  late NibPopoverController _controller;
  late bool _ownsController;

  final _link = LayerLink();
  OverlayEntry? _overlayEntry;

  bool _closing = false;
  Timer? _exitTimer;
  final _cardKey = const ValueKey<String>('nib-popover-card');

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
  void didUpdateWidget(covariant NibPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _unbindController();
      _bindController(widget.controller);
    }
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _removeOverlay();
    _unbindController();
    super.dispose();
  }

  void _bindController(NibPopoverController? external) {
    _controller = external ?? NibPopoverController();
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

  // --- Open / close ----------------------------------------------------------

  void _toggle() => _controller.toggle();

  void _close() {
    if (!_controller.isOpen) return;
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
  /// approach (and same deferred caveat) as `NibSelect`/`NibDialog`.
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
    final viewport = NibOverlayViewport(
      Overlay.of(context),
      MediaQuery.of(overlayContext),
    );
    final target = viewport.targetBounds(box);

    return _NibPopoverOverlay(
      link: _link,
      target: target,
      viewport: viewport,
      placement: _toOverlayPlacement(widget.placement),
      gap: widget.gap,
      showArrow: widget.showArrow,
      dismissOnOutsideTap: widget.dismissOnOutsideTap,
      barrierColor: widget.barrierColor,
      maxWidth: widget.maxWidth,
      animated: widget.animated,
      transition: _effectiveTransition(),
      enterFrom: widget.enterFrom,
      closing: _closing,
      cardKey: _cardKey,
      theme: NibTheme.of(context),
      onRequestClose: _close,
      child: NibPopoverScope(
        close: _close,
        isOpen: !_closing,
        child: widget.content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trigger == null) return const SizedBox.shrink();
    return CompositedTransformTarget(
      link: _link,
      child: Semantics(
        button: true,
        expanded: _controller.isOpen,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: widget.trigger,
        ),
      ),
    );
  }
}

/// The floating panel: measures its content, resolves the concrete side via the
/// shared positioning core, positions itself with a `CompositedTransformFollower`,
/// draws an optional arrow into the gap, and plays the `nib_motion` enter/exit.
class _NibPopoverOverlay extends StatefulWidget {
  const _NibPopoverOverlay({
    required this.link,
    required this.target,
    required this.viewport,
    required this.placement,
    required this.gap,
    required this.showArrow,
    required this.dismissOnOutsideTap,
    required this.barrierColor,
    required this.maxWidth,
    required this.animated,
    required this.transition,
    required this.enterFrom,
    required this.closing,
    required this.cardKey,
    required this.theme,
    required this.onRequestClose,
    required this.child,
  });

  final LayerLink link;
  final Rect target;
  final NibOverlayViewport viewport;
  final NibOverlayPlacement placement;
  final double gap;
  final bool showArrow;
  final bool dismissOnOutsideTap;
  final Color? barrierColor;
  final double maxWidth;
  final bool animated;
  final NibTransition transition;
  final NibAnim? enterFrom;
  final bool closing;
  final Key cardKey;
  final NibTheme theme;
  final VoidCallback onRequestClose;
  final Widget child;

  @override
  State<_NibPopoverOverlay> createState() => _NibPopoverOverlayState();
}

class _NibPopoverOverlayState extends State<_NibPopoverOverlay> {
  final _focusScopeNode = FocusScopeNode(debugLabel: 'nib-popover');
  Size? _contentSize;

  @override
  void dispose() {
    _focusScopeNode.dispose();
    super.dispose();
  }

  Widget _withArrow(NibOverlaySide side, Widget card) {
    if (!widget.showArrow) return card;
    final arrow = _PopoverArrow(side: side, color: widget.theme.card);
    switch (side) {
      case NibOverlaySide.bottom:
        return Column(mainAxisSize: MainAxisSize.min, children: [arrow, card]);
      case NibOverlaySide.top:
        return Column(mainAxisSize: MainAxisSize.min, children: [card, arrow]);
      case NibOverlaySide.end:
        return Row(mainAxisSize: MainAxisSize.min, children: [arrow, card]);
      case NibOverlaySide.start:
        return Row(mainAxisSize: MainAxisSize.min, children: [card, arrow]);
    }
  }

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

  bool get _horizontalPlacement =>
      widget.placement == NibOverlayPlacement.start ||
      widget.placement == NibOverlayPlacement.end;

  Widget _buildCard() {
    final theme = widget.theme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(
          widget.maxWidth,
          math.max(
            0,
            widget.viewport.size.width -
                widget.viewport.safeInsets.horizontal -
                16 -
                (widget.showArrow && _horizontalPlacement ? 7 : 0),
          ),
        ),
        maxHeight: math.max(
          0,
          widget.viewport.size.height -
              widget.viewport.safeInsets.vertical -
              16 -
              (widget.showArrow && !_horizontalPlacement ? 7 : 0),
        ),
      ),
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
          child: SingleChildScrollView(
            primary: false,
            padding: const EdgeInsets.all(14),
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, Intent> get _shortcuts => const {
    SingleActivator(LogicalKeyboardKey.escape): _ClosePopoverIntent(),
  };

  Map<Type, Action<Intent>> get _actions => {
    _ClosePopoverIntent: CallbackAction<_ClosePopoverIntent>(
      onInvoke: (_) {
        widget.onRequestClose();
        return null;
      },
    ),
  };

  @override
  Widget build(BuildContext context) {
    final measuredCard = MeasureSize(
      onChange: (size) {
        if (mounted && _contentSize != size) {
          setState(() => _contentSize = size);
        }
      },
      child: _buildCard(),
    );

    final barrier = (widget.dismissOnOutsideTap && !widget.closing)
        ? Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onRequestClose,
              child: widget.barrierColor != null
                  ? ColoredBox(color: widget.barrierColor!)
                  : const SizedBox.expand(),
            ),
          )
        : null;

    Widget wrap(Widget positioned) => FocusScope(
      node: _focusScopeNode,
      autofocus: true,
      child: Shortcuts(
        shortcuts: _shortcuts,
        child: Actions(
          actions: _actions,
          child: Focus(
            autofocus: true,
            child: Stack(children: [?barrier, positioned]),
          ),
        ),
      ),
    );

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

    final arrowExtent = widget.showArrow ? 7.0 : 0.0;
    final content = Size(
      _contentSize!.width + (_horizontalPlacement ? arrowExtent : 0),
      _contentSize!.height + (_horizontalPlacement ? 0 : arrowExtent),
    );
    final geo = resolveOverlayGeometry(
      placement: widget.placement,
      target: widget.target,
      content: content,
      screen: widget.viewport.size,
      safeInsets: widget.viewport.safeInsets,
      gap: widget.gap,
    );
    final side = geo.side;

    return wrap(
      CompositedTransformFollower(
        link: widget.link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.topLeft,
        offset: geo.offset,
        child: _animate(side, _withArrow(side, measuredCard)),
      ),
    );
  }
}

class _ClosePopoverIntent extends Intent {
  const _ClosePopoverIntent();
}

/// A small triangle pointing toward the trigger, drawn into the popover's gap.
class _PopoverArrow extends StatelessWidget {
  const _PopoverArrow({required this.side, required this.color});

  final NibOverlaySide side;
  final Color color;

  static const double _long = 14;
  static const double _short = 7;

  @override
  Widget build(BuildContext context) {
    final horizontal =
        side == NibOverlaySide.bottom || side == NibOverlaySide.top;
    return CustomPaint(
      size: horizontal ? const Size(_long, _short) : const Size(_short, _long),
      painter: _ArrowPainter(side, color),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.side, this.color);

  final NibOverlaySide side;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path();
    switch (side) {
      case NibOverlaySide.bottom: // apex up
        path
          ..moveTo(0, h)
          ..lineTo(w / 2, 0)
          ..lineTo(w, h);
      case NibOverlaySide.top: // apex down
        path
          ..moveTo(0, 0)
          ..lineTo(w / 2, h)
          ..lineTo(w, 0);
      case NibOverlaySide.end: // apex left
        path
          ..moveTo(w, 0)
          ..lineTo(0, h / 2)
          ..lineTo(w, h);
      case NibOverlaySide.start: // apex right
        path
          ..moveTo(0, 0)
          ..lineTo(w, h / 2)
          ..lineTo(0, h);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.side != side || old.color != color;
}
