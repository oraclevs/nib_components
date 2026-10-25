import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibPresence, NibTransition;

import '../theme/nib_theme.dart';
import 'nib_dialog_types.dart';

/// Exposes the enclosing dialog's [close] callback to its `content`/`footer`
/// subtree, so a button inside the dialog can dismiss it (optionally with a
/// result) without the consumer wiring a controller:
///
/// ```dart
/// NibButton(
///   label: 'Confirm',
///   onPressed: () => NibDialogScope.of(context).close(true),
/// )
/// ```
class NibDialogScope extends InheritedWidget {
  const NibDialogScope({
    super.key,
    required this.close,
    required this.isOpen,
    required super.child,
  });

  /// Closes the dialog, optionally completing [showNibDialog]'s future with
  /// [result].
  final void Function([Object? result]) close;

  /// Whether the dialog is still open (not mid-close).
  final bool isOpen;

  /// The nearest enclosing dialog scope. Asserts if called outside a dialog.
  static NibDialogScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NibDialogScope>();
    assert(
      scope != null,
      'NibDialogScope.of() called outside a NibDialog/showNibDialog.',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(NibDialogScope oldWidget) =>
      isOpen != oldWidget.isOpen || close != oldWidget.close;
}

/// A handle to an open dialog returned by [openNibDialog]. [showNibDialog]
/// hands back its [closed] future directly; the declarative `NibDialog` widget
/// keeps the whole handle so it can [close] the dialog when its controller flips.
class NibDialogHandle<T> {
  NibDialogHandle._(this._closed, this._requestClose, this._isOpen);

  final Future<T?> _closed;
  final void Function(Object? result) _requestClose;
  final bool Function() _isOpen;

  /// Completes with the dialog's result when it closes (`null` if dismissed via
  /// the barrier, Escape, or the close button).
  Future<T?> get closed => _closed;

  /// Whether the dialog is still mounted (not yet fully removed).
  bool get isOpen => _isOpen();

  /// Requests a close, optionally completing [closed] with [result].
  void close([Object? result]) => _requestClose(result);
}

/// Imperative entry point: opens a modal dialog over the root [Overlay] and
/// returns a future that completes with the dialog's result (or `null` when
/// dismissed). See [NibDialogSize]/[NibDialogAnimation] for sizing/motion, and
/// [NibDialogScope] for closing from inside the content.
Future<T?> showNibDialog<T>(
  BuildContext context, {
  String? title,
  String? description,
  Widget? header,
  required Widget content,
  Widget? footer,
  NibDialogSize size = NibDialogSize.md,
  double? width,
  bool barrierDismissible = true,
  bool showCloseButton = true,
  Color? barrierColor,
  bool animated = false,
  NibDialogAnimation animation = NibDialogAnimation.fadeScale,
  NibTransition? transition,
  VoidCallback? onClose,
}) {
  return openNibDialog<T>(
    context,
    title: title,
    description: description,
    header: header,
    content: content,
    footer: footer,
    size: size,
    width: width,
    barrierDismissible: barrierDismissible,
    showCloseButton: showCloseButton,
    barrierColor: barrierColor,
    animated: animated,
    animation: animation,
    transition: transition,
    onClose: onClose,
  ).closed;
}

/// Lower-level primitive behind [showNibDialog] and `NibDialog`: inserts the
/// dialog into the root overlay and returns a [NibDialogHandle] that can both
/// await the result and programmatically close it. Prefer [showNibDialog] for
/// fire-and-forget use.
NibDialogHandle<T> openNibDialog<T>(
  BuildContext context, {
  String? title,
  String? description,
  Widget? header,
  required Widget content,
  Widget? footer,
  NibDialogSize size = NibDialogSize.md,
  double? width,
  bool barrierDismissible = true,
  bool showCloseButton = true,
  Color? barrierColor,
  bool animated = false,
  NibDialogAnimation animation = NibDialogAnimation.fadeScale,
  NibTransition? transition,
  VoidCallback? onClose,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final themes = InheritedTheme.capture(from: context, to: overlay.context);
  final completer = Completer<T?>();
  // Captured so focus returns to whatever opened the dialog (its trigger, or a
  // button in a parent dialog when stacking) once this one closes.
  final previousFocus = FocusManager.instance.primaryFocus;
  final surfaceKey = GlobalKey<_NibDialogSurfaceState>();
  var finished = false;
  late OverlayEntry entry;

  void handleResult(Object? result) {
    if (completer.isCompleted) return;
    completer.complete(result == null ? null : result as T);
    onClose?.call();
  }

  void handleRemoved() {
    if (finished) return;
    finished = true;
    entry.remove();
    previousFocus?.requestFocus();
  }

  entry = OverlayEntry(
    builder: (_) => themes.wrap(
      _NibDialogSurface(
        key: surfaceKey,
        title: title,
        description: description,
        header: header,
        content: content,
        footer: footer,
        size: size,
        width: width,
        barrierDismissible: barrierDismissible,
        showCloseButton: showCloseButton,
        barrierColor: barrierColor,
        animated: animated,
        animation: animation,
        transition: transition,
        onResult: handleResult,
        onRemoved: handleRemoved,
      ),
    ),
  );

  final handle = NibDialogHandle<T>._(
    completer.future,
    (result) => surfaceKey.currentState?.requestClose(result),
    () => !finished,
  );
  overlay.insert(entry);
  return handle;
}

/// The visual + interactive body of a dialog, mounted inside an [OverlayEntry]:
/// barrier, focus trap, animated card, and header/body/footer slots. Stacking
/// is handled by the overlay itself (each dialog is its own entry, z-ordered by
/// insertion) plus focus ordering — the topmost dialog holds focus, so Escape
/// and outside-taps resolve to it alone; no separate stack registry is needed.
class _NibDialogSurface extends StatefulWidget {
  const _NibDialogSurface({
    super.key,
    required this.title,
    required this.description,
    required this.header,
    required this.content,
    required this.footer,
    required this.size,
    required this.width,
    required this.barrierDismissible,
    required this.showCloseButton,
    required this.barrierColor,
    required this.animated,
    required this.animation,
    required this.transition,
    required this.onResult,
    required this.onRemoved,
  });

  final String? title;
  final String? description;
  final Widget? header;
  final Widget content;
  final Widget? footer;
  final NibDialogSize size;
  final double? width;
  final bool barrierDismissible;
  final bool showCloseButton;
  final Color? barrierColor;
  final bool animated;
  final NibDialogAnimation animation;
  final NibTransition? transition;

  /// Called once when a close is requested, with the result to complete the
  /// dialog's future.
  final void Function(Object? result) onResult;

  /// Called once the surface should be fully removed (immediately when
  /// unanimated; after the exit motion when animated).
  final VoidCallback onRemoved;

  @override
  State<_NibDialogSurface> createState() => _NibDialogSurfaceState();
}

class _NibDialogSurfaceState extends State<_NibDialogSurface> {
  final _focusScopeNode = FocusScopeNode(debugLabel: 'nib-dialog');
  final _scrimKey = const ValueKey<String>('nib-dialog-scrim');
  final _cardKey = const ValueKey<String>('nib-dialog-card');

  static const double _screenMargin = 24;

  bool _closing = false;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    // Move focus off the bare scope node onto the first focusable control in
    // the dialog, so keyboard shortcuts (Escape, Tab) route through the
    // dialog's Shortcuts/Actions (which sit below the FocusScope) and the trap
    // is active immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusScopeNode.nextFocus();
    });
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _focusScopeNode.dispose();
    super.dispose();
  }

  /// Whether the surface builds `nib_motion` widgets at all. `false` keeps the
  /// `animated: false` / [NibDialogAnimation.none] paths overhead-free.
  bool get _animated =>
      widget.animated && widget.animation != NibDialogAnimation.none;

  NibTransition _effectiveTransition() =>
      widget.transition ??
      const NibTransition(duration: Duration(milliseconds: 160));

  /// How long to keep the surface mounted after a close so the exit motion can
  /// finish before removal. Springs have no fixed duration, so estimate — same
  /// approach (and same deferred-refinement caveat) as `NibSelect`.
  Duration _exitDuration() {
    final t = _effectiveTransition();
    final base = t.spring != null
        ? const Duration(milliseconds: 450)
        : t.duration;
    return base + t.delay + const Duration(milliseconds: 40);
  }

  /// Requests a close. Reports the result immediately; removes the overlay now
  /// when unanimated, or after the exit motion when animated.
  void requestClose([Object? result]) {
    if (_closing) return;
    widget.onResult(result);
    if (!_animated) {
      widget.onRemoved();
      return;
    }
    setState(() => _closing = true);
    _exitTimer?.cancel();
    _exitTimer = Timer(_exitDuration(), widget.onRemoved);
  }

  void _dismissByBarrier() {
    if (widget.barrierDismissible) requestClose();
  }

  // --- Card ------------------------------------------------------------------

  Widget _buildCloseButton(NibTheme theme) {
    return Semantics(
      button: true,
      label: 'Close',
      child: Tooltip(
        message: 'Close',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => requestClose(),
            borderRadius: BorderRadius.circular(theme.radiusPill),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.close, size: 20, color: theme.mutedForeground),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildHeader(NibTheme theme) {
    if (widget.header != null) return widget.header;
    final hasText = widget.title != null || widget.description != null;
    if (!hasText && !widget.showCloseButton) return null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, widget.showCloseButton ? 10 : 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.title != null)
                  Text(
                    widget.title!,
                    style: TextStyle(
                      color: theme.foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (widget.description != null)
                  Padding(
                    padding: EdgeInsets.only(top: widget.title != null ? 4 : 0),
                    child: Text(
                      widget.description!,
                      style: TextStyle(
                        color: theme.mutedForeground,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.showCloseButton) _buildCloseButton(theme),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, NibTheme theme) {
    final fullscreen = widget.size == NibDialogSize.fullscreen;
    final header = _buildHeader(theme);

    final body = Flexible(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          header == null ? 20 : 4,
          20,
          widget.footer == null ? 20 : 8,
        ),
        child: widget.content,
      ),
    );

    final footer = widget.footer == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: widget.footer,
          );

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [?header, body, ?footer],
    );

    final radius = fullscreen
        ? BorderRadius.zero
        : BorderRadius.circular(theme.radiusLg);
    Widget card = Material(
      color: theme.card,
      elevation: fullscreen ? 0 : 8,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: fullscreen ? null : Border.all(color: theme.border),
          borderRadius: radius,
        ),
        child: column,
      ),
    );

    if (fullscreen) {
      return SizedBox.expand(child: card);
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final ceiling = widget.width ?? nibDialogMaxWidth(widget.size)!;
    final maxWidth = math.min(ceiling, screenWidth - _screenMargin * 2);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: card,
    );
  }

  // --- Enter/exit motion -----------------------------------------------------

  Widget _wrapScrim(Widget barrier) {
    if (!_animated) return barrier;
    final motion = NibMotion(
      key: _scrimKey,
      initial: const NibAnim(opacity: 0),
      animate: NibAnim.identity,
      exit: const NibAnim(opacity: 0),
      transition: _effectiveTransition(),
      child: barrier,
    );
    return NibPresence(children: _closing ? const [] : [motion]);
  }

  Widget _wrapCard(Widget card) {
    if (!_animated) return card;
    final from = resolveNibDialogEnter(widget.animation);
    final motion = NibMotion(
      key: _cardKey,
      initial: from,
      animate: NibAnim.identity,
      exit: from,
      transition: _effectiveTransition(),
      child: card,
    );
    return NibPresence(children: _closing ? const [] : [motion]);
  }

  // --- Focus trap / shortcuts ------------------------------------------------

  Map<ShortcutActivator, Intent> get _shortcuts => const {
    SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
    SingleActivator(LogicalKeyboardKey.tab, shift: true): PreviousFocusIntent(),
    SingleActivator(LogicalKeyboardKey.escape): _DismissDialogIntent(),
  };

  Map<Type, Action<Intent>> get _actions => {
    // Route Tab through the dialog's own scope so traversal wraps within it
    // (reaching the last field and Tabbing again returns to the first) —
    // the focus trap. `previousFocus`/`nextFocus` on a FocusScopeNode wrap
    // at the scope boundary rather than escaping to the app behind.
    NextFocusIntent: CallbackAction<NextFocusIntent>(
      onInvoke: (_) {
        _focusScopeNode.nextFocus();
        return null;
      },
    ),
    PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(
      onInvoke: (_) {
        _focusScopeNode.previousFocus();
        return null;
      },
    ),
    _DismissDialogIntent: CallbackAction<_DismissDialogIntent>(
      onInvoke: (_) {
        if (widget.barrierDismissible) requestClose();
        return null;
      },
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final scrim = widget.barrierColor ?? const Color(0x73000000);
    final fullscreen = widget.size == NibDialogSize.fullscreen;

    final barrier = _wrapScrim(
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismissByBarrier,
        child: ColoredBox(color: scrim, child: const SizedBox.expand()),
      ),
    );

    final cardLayer = FocusScope(
      node: _focusScopeNode,
      autofocus: true,
      child: Shortcuts(
        shortcuts: _shortcuts,
        child: Actions(
          actions: _actions,
          child: Semantics(
            scopesRoute: true,
            namesRoute: widget.title != null,
            explicitChildNodes: true,
            label: widget.title,
            child: NibDialogScope(
              close: ([result]) => requestClose(result),
              isOpen: !_closing,
              child: _wrapCard(_buildCard(context, theme)),
            ),
          ),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Hide everything beneath this dialog from the semantics tree.
        const BlockSemantics(),
        Positioned.fill(child: barrier),
        Positioned.fill(
          child: SafeArea(
            child: Align(
              alignment: fullscreen ? Alignment.topCenter : Alignment.center,
              child: cardLayer,
            ),
          ),
        ),
      ],
    );
  }
}

class _DismissDialogIntent extends Intent {
  const _DismissDialogIntent();
}
