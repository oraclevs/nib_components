import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibPresence, NibTransition;

import '../overlay/measure_size.dart';
import '../theme/nib_theme.dart';
import 'nib_bottom_sheet_types.dart';

/// Exposes the enclosing bottom sheet's [close] callback (and snap control) to
/// its `content` subtree, so a button inside the sheet can dismiss it — or move
/// it to another snap — without the consumer wiring a controller:
///
/// ```dart
/// NibButton(
///   label: 'Done',
///   onPressed: () => NibBottomSheetScope.of(context).close(),
/// )
/// ```
class NibBottomSheetScope extends InheritedWidget {
  const NibBottomSheetScope({
    super.key,
    required this.close,
    required this.snapTo,
    required this.isOpen,
    required super.child,
  });

  /// Closes the sheet, optionally completing the future with [result].
  final void Function([Object? result]) close;

  /// Animates an open, snap-point sheet to snap [index]. No-op for a
  /// content-sized sheet.
  final void Function(int index) snapTo;

  /// Whether the sheet is still open (not mid-close).
  final bool isOpen;

  /// The nearest enclosing sheet scope. Asserts if called outside a sheet.
  static NibBottomSheetScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<NibBottomSheetScope>();
    assert(
      scope != null,
      'NibBottomSheetScope.of() called outside a NibBottomSheet/showNibBottomSheet.',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(NibBottomSheetScope oldWidget) =>
      isOpen != oldWidget.isOpen || close != oldWidget.close;
}

/// A handle to an open sheet returned by [openNibBottomSheet].
/// [showNibBottomSheet] hands back its [closed] future directly; the declarative
/// `NibBottomSheet` keeps the whole handle so it can [close]/[snapTo] the sheet
/// when its controller changes.
class NibBottomSheetHandle<T> {
  NibBottomSheetHandle._(
    this._closed,
    this._requestClose,
    this._requestSnap,
    this._isOpen,
  );

  final Future<T?> _closed;
  final void Function(Object? result) _requestClose;
  final void Function(int index) _requestSnap;
  final bool Function() _isOpen;

  /// Completes with the sheet's result when it closes (`null` when dismissed via
  /// the barrier, Escape, a drag-to-dismiss, or the drag handle).
  Future<T?> get closed => _closed;

  /// Whether the sheet is still mounted (not yet fully removed).
  bool get isOpen => _isOpen();

  /// Requests a close, optionally completing [closed] with [result].
  void close([Object? result]) => _requestClose(result);

  /// Animates an open, snap-point sheet to snap [index].
  void snapTo(int index) => _requestSnap(index);
}

/// Imperative entry point: opens a modal bottom sheet over the root [Overlay]
/// and returns a future that completes with the sheet's result (or `null` when
/// dismissed). See [NibBottomSheetScope] for closing from inside the content and
/// `snapPoints`/`initialSnap` for multi-height sheets.
Future<T?> showNibBottomSheet<T>(
  BuildContext context, {
  required Widget content,
  String? title,
  List<double>? snapPoints,
  int? initialSnap,
  ValueChanged<int>? onSnapChanged,
  bool dismissible = true,
  bool showDragHandle = true,
  Color? barrierColor,
  bool animated = false,
  NibTransition? transition,
  VoidCallback? onClose,
}) {
  return openNibBottomSheet<T>(
    context,
    content: content,
    title: title,
    snapPoints: snapPoints,
    initialSnap: initialSnap,
    onSnapChanged: onSnapChanged,
    dismissible: dismissible,
    showDragHandle: showDragHandle,
    barrierColor: barrierColor,
    animated: animated,
    transition: transition,
    onClose: onClose,
  ).closed;
}

/// Lower-level primitive behind [showNibBottomSheet] and `NibBottomSheet`:
/// inserts the sheet into the root overlay and returns a [NibBottomSheetHandle]
/// that can await the result, close it, and move it between snaps. Prefer
/// [showNibBottomSheet] for fire-and-forget use.
NibBottomSheetHandle<T> openNibBottomSheet<T>(
  BuildContext context, {
  required Widget content,
  String? title,
  List<double>? snapPoints,
  int? initialSnap,
  ValueChanged<int>? onSnapChanged,
  bool dismissible = true,
  bool showDragHandle = true,
  Color? barrierColor,
  bool animated = false,
  NibTransition? transition,
  VoidCallback? onClose,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final themes = InheritedTheme.capture(from: context, to: overlay.context);
  final completer = Completer<T?>();
  final previousFocus = FocusManager.instance.primaryFocus;
  final surfaceKey = GlobalKey<_NibBottomSheetSurfaceState>();
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
      _NibBottomSheetSurface(
        key: surfaceKey,
        title: title,
        content: content,
        snapPoints: snapPoints,
        initialSnap: initialSnap,
        onSnapChanged: onSnapChanged,
        dismissible: dismissible,
        showDragHandle: showDragHandle,
        barrierColor: barrierColor,
        animated: animated,
        transition: transition,
        onResult: handleResult,
        onRemoved: handleRemoved,
      ),
    ),
  );

  final handle = NibBottomSheetHandle<T>._(
    completer.future,
    (result) => surfaceKey.currentState?.requestClose(result),
    (index) => surfaceKey.currentState?.snapToExternally(index),
    () => !finished,
  );
  overlay.insert(entry);
  return handle;
}

/// The visual + interactive body of a bottom sheet, mounted inside an
/// [OverlayEntry]: barrier, focus trap, drag handle, and a spring-driven,
/// snap-aware surface. The sheet's position (enter, drag, snap, exit) is driven
/// by an internal [AnimationController] + [SpringSimulation] rather than a
/// `NibMotion` widget, because a continuously drag-controlled transform can't be
/// wrapped in `NibMotion`'s declarative enter/animate/exit variants without
/// fighting the gesture. Its settle physics still flow through `nib_motion` via
/// `transition.spring`, and the barrier's opt-in enter/exit fade routes through
/// `NibMotion`/`NibPresence` (so `animated: true` builds `NibMotion` and
/// `animated: false` builds none).
class _NibBottomSheetSurface extends StatefulWidget {
  const _NibBottomSheetSurface({
    super.key,
    required this.title,
    required this.content,
    required this.snapPoints,
    required this.initialSnap,
    required this.onSnapChanged,
    required this.dismissible,
    required this.showDragHandle,
    required this.barrierColor,
    required this.animated,
    required this.transition,
    required this.onResult,
    required this.onRemoved,
  });

  final String? title;
  final Widget content;
  final List<double>? snapPoints;
  final int? initialSnap;
  final ValueChanged<int>? onSnapChanged;
  final bool dismissible;
  final bool showDragHandle;
  final Color? barrierColor;
  final bool animated;
  final NibTransition? transition;

  /// Called once when a close is requested, with the result for the future.
  final void Function(Object? result) onResult;

  /// Called once the surface should be fully removed (immediately when
  /// unanimated; after the exit motion completes when animated).
  final VoidCallback onRemoved;

  @override
  State<_NibBottomSheetSurface> createState() => _NibBottomSheetSurfaceState();
}

class _NibBottomSheetSurfaceState extends State<_NibBottomSheetSurface>
    with SingleTickerProviderStateMixin {
  /// Fraction of the available height a content-sized sheet is capped at.
  static const double _maxContentExtent = 0.9;

  /// Starting off-screen offset before the real sheet height is known.
  static const double _prelayoutOffset = 5000;

  final _focusScopeNode = FocusScopeNode(debugLabel: 'nib-bottom-sheet');
  final _scrimKey = const ValueKey<String>('nib-sheet-scrim');

  /// Vertical translate of the sheet, in logical pixels: `0` = fully open at the
  /// tallest snap, `_sheetHeight` = fully off-screen (dismissed).
  late final AnimationController _offset;

  List<double>? _extents; // normalized snap extents; null = content-sized
  int _currentSnap = 0;
  double _availableHeight = 0;
  double _sheetHeight = 0;
  bool _entered = false;
  bool _closing = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _extents = normalizeSnapExtents(widget.snapPoints);
    _currentSnap = clampInitialSnapIndex(
      _extents?.length ?? 1,
      widget.initialSnap,
    );
    _offset = AnimationController.unbounded(vsync: this)
      ..value = _prelayoutOffset;
  }

  @override
  void dispose() {
    _offset.dispose();
    _focusScopeNode.dispose();
    super.dispose();
  }

  double? get _maxExtent => _extents?.last;

  NibTransition _effectiveTransition() =>
      widget.transition ??
      const NibTransition(duration: Duration(milliseconds: 220));

  SpringDescription get _spring =>
      _effectiveTransition().spring?.toFlutter() ??
      SpringDescription.withDampingRatio(mass: 1, stiffness: 600);

  double _offsetForSnap(int index) {
    if (_extents == null) return 0; // content-sized rests fully open
    return _sheetHeight - _extents![index] * _availableHeight;
  }

  // --- Sizing / enter --------------------------------------------------------

  void _applyAvailableHeight(double avail) {
    if (avail <= 0 || avail == _availableHeight) return;
    _availableHeight = avail;
    if (_extents != null) {
      _sheetHeight = _maxExtent! * avail;
      _scheduleEnter();
    }
    // Content-sized: _sheetHeight is set by _onMeasured after layout.
  }

  void _onMeasured(Size size) {
    if (!mounted || _extents != null) return;
    final capped = math.min(size.height, _availableHeight * _maxContentExtent);
    if (capped <= 0) return;
    if ((capped - _sheetHeight).abs() > 0.5) _sheetHeight = capped;
    _scheduleEnter();
  }

  void _scheduleEnter() {
    if (_entered || _sheetHeight <= 0 || _availableHeight <= 0) return;
    _entered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rest = _offsetForSnap(_currentSnap);
      _offset.value =
          _sheetHeight; // start fully off-screen at the known height
      if (widget.animated) {
        _driveTo(rest);
      } else {
        _offset.value = rest;
      }
    });
  }

  // --- Motion ----------------------------------------------------------------

  TickerFuture _driveTo(double target, {double velocity = 0}) {
    return _offset.animateWith(
      SpringSimulation(_spring, _offset.value, target, velocity),
    );
  }

  // --- Drag ------------------------------------------------------------------

  void _onDragStart(DragStartDetails _) => _offset.stop();

  void _onDragUpdate(DragUpdateDetails details) {
    _offset.value = (_offset.value + details.delta.dy).clamp(0.0, _sheetHeight);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_sheetHeight <= 0 || _availableHeight <= 0) return;
    final vyPx = details.primaryVelocity ?? 0; // + = downward
    final currentExtent = (_sheetHeight - _offset.value) / _availableHeight;
    final extents = _extents ?? [_sheetHeight / _availableHeight];
    final target = resolveSnapTarget(
      currentExtent: currentExtent,
      extents: extents,
      velocity: -vyPx / _availableHeight, // + = opening
      dismissible: widget.dismissible,
    );
    if (target == null) {
      _close();
      return;
    }
    _settleToSnap(target, vyPx);
  }

  void _settleToSnap(int index, double velocity) {
    _driveTo(_offsetForSnap(index), velocity: velocity);
    if (index != _currentSnap) {
      _currentSnap = index;
      widget.onSnapChanged?.call(index);
    }
  }

  /// Programmatic snap from the handle/controller.
  void snapToExternally(int index) {
    if (_extents == null || _sheetHeight <= 0) return;
    _settleToSnap(index.clamp(0, _extents!.length - 1), 0);
  }

  // --- Close -----------------------------------------------------------------

  void requestClose([Object? result]) => _close(result);

  void _close([Object? result]) {
    if (_closing) return;
    _closing = true;
    widget.onResult(result);
    if (!widget.animated) {
      _offset.value = _sheetHeight;
      _finish();
      return;
    }
    setState(() {}); // rebuild so the scrim plays its NibPresence exit
    _driveTo(_sheetHeight).whenCompleteOrCancel(() {
      if (mounted) _finish();
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onRemoved();
  }

  // --- Build -----------------------------------------------------------------

  Widget _wrapScrim(Widget barrier) {
    if (!widget.animated) return barrier;
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

  Widget _buildHandle(NibTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.border,
            borderRadius: BorderRadius.circular(theme.radiusPill),
          ),
        ),
      ),
    );
  }

  Widget _buildSheet(BuildContext context, NibTheme theme) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final radius = BorderRadius.vertical(top: Radius.circular(theme.radiusLg));

    final children = <Widget>[
      if (widget.showDragHandle) _buildHandle(theme),
      if (widget.title != null)
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            widget.showDragHandle ? 2 : 16,
            20,
            4,
          ),
          child: Text(
            widget.title!,
            style: TextStyle(
              color: theme.foreground,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      Flexible(
        fit: FlexFit.loose,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
          child: widget.content,
        ),
      ),
    ];

    final column = Column(
      mainAxisSize: _extents != null ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

    Widget card = Material(
      color: theme.card,
      elevation: 12,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.border)),
          borderRadius: radius,
        ),
        child: column,
      ),
    );

    if (_extents != null) {
      card = SizedBox(height: _sheetHeight, child: card);
    } else {
      card = ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: _availableHeight > 0
              ? _availableHeight * _maxContentExtent
              : double.infinity,
        ),
        child: MeasureSize(onChange: _onMeasured, child: card),
      );
    }

    // Full-width on phones, capped and centered on wide viewports.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: card,
    );
  }

  Map<ShortcutActivator, Intent> get _shortcuts => const {
    SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
    SingleActivator(LogicalKeyboardKey.tab, shift: true): PreviousFocusIntent(),
    SingleActivator(LogicalKeyboardKey.escape): _DismissSheetIntent(),
  };

  Map<Type, Action<Intent>> get _actions => {
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
    _DismissSheetIntent: CallbackAction<_DismissSheetIntent>(
      onInvoke: (_) {
        if (widget.dismissible) _close();
        return null;
      },
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final scrimColor = widget.barrierColor ?? const Color(0x73000000);

    return LayoutBuilder(
      builder: (context, constraints) {
        _applyAvailableHeight(constraints.maxHeight - topInset);

        final barrier = _wrapScrim(
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.dismissible) _close();
            },
            child: ColoredBox(
              color: scrimColor,
              child: const SizedBox.expand(),
            ),
          ),
        );

        final sheet = FocusScope(
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
                child: NibBottomSheetScope(
                  close: ([result]) => _close(result),
                  snapTo: snapToExternally,
                  isOpen: !_closing,
                  // A focusable node directly under Shortcuts, so Escape/Tab
                  // route through the sheet's Actions even when the content has
                  // no focusable widgets of its own.
                  child: Focus(
                    autofocus: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: _onDragStart,
                      onVerticalDragUpdate: _onDragUpdate,
                      onVerticalDragEnd: _onDragEnd,
                      child: _buildSheet(context, theme),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            const BlockSemantics(),
            Positioned.fill(child: barrier),
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedBuilder(
                  animation: _offset,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, math.max(0, _offset.value)),
                    child: child,
                  ),
                  child: sheet,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DismissSheetIntent extends Intent {
  const _DismissSheetIntent();
}
