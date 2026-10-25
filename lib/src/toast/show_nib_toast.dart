import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibPresence, NibTransition;

import '../theme/nib_theme.dart';
import 'nib_toast_types.dart';

const NibTransition _defaultToastTransition = NibTransition(
  duration: Duration(milliseconds: 220),
);

/// Mutable record of one live toast. Fields the [_NibToastItem] observes for a
/// change ([dismissing], [shakeBump]) are passed to it as explicit widget props
/// (not read off this object), so `replace`/`shake`/dismiss mutations here are
/// seen across rebuilds even though the object identity stays the same.
class _ToastData {
  _ToastData({
    required this.id,
    required this.position,
    required this.duration,
    required this.animated,
    required this.transition,
    required this.title,
    required this.message,
    required this.content,
    required this.variant,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    required this.showCloseButton,
    required this.dismissible,
    required this.onDismiss,
    required this.padding,
    required this.borderRadius,
    required this.backgroundColor,
    required this.themes,
  });

  final String id;
  final NibToastPosition position;
  final bool animated;
  final NibTransition? transition;

  Duration duration;
  String? title;
  String? message;
  Widget? content;
  NibToastVariant variant;
  IconData? icon;
  String? actionLabel;
  VoidCallback? onAction;
  bool showCloseButton;
  bool dismissible;
  VoidCallback? onDismiss;
  EdgeInsetsGeometry? padding;
  BorderRadiusGeometry? borderRadius;
  Color? backgroundColor;
  CapturedThemes? themes;

  Timer? timer;
  int shakeBump = 0;
  bool dismissing = false;
}

/// Global toast controller. One host [OverlayEntry] renders every active toast,
/// grouped by position. Not exported — drive it via [showNibToast].
class _NibToastManager extends ChangeNotifier {
  _NibToastManager._();

  static const int maxVisible = 5;

  final List<_ToastData> _toasts = [];
  OverlayState? _overlay;
  OverlayState? _registeredOverlay;
  OverlayEntry? _entry;
  int _autoId = 0;

  List<_ToastData> get toasts => List.unmodifiable(_toasts);

  List<_ToastData> at(NibToastPosition position) =>
      _toasts.where((t) => t.position == position).toList(growable: false);

  /// Called by [NibToaster] so toasts can be shown context-free.
  void registerOverlay(OverlayState overlay) => _registeredOverlay = overlay;

  void unregisterOverlay(OverlayState overlay) {
    if (_registeredOverlay == overlay) _registeredOverlay = null;
  }

  OverlayState? _resolveOverlay(BuildContext? context) {
    if (context != null) {
      final o = Overlay.maybeOf(context, rootOverlay: true);
      if (o != null) return o;
    }
    return _registeredOverlay;
  }

  String show({
    BuildContext? context,
    String? id,
    String? title,
    String? message,
    Widget? content,
    NibToastVariant variant = NibToastVariant.normal,
    IconData? icon,
    NibToastPosition position = NibToastPosition.bottomRight,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
    bool showCloseButton = true,
    bool dismissible = true,
    NibToastDuplicateBehavior onDuplicateTrigger =
        NibToastDuplicateBehavior.shake,
    bool animated = false,
    NibTransition? transition,
    VoidCallback? onDismiss,
    EdgeInsetsGeometry? padding,
    BorderRadiusGeometry? borderRadius,
    Color? backgroundColor,
  }) {
    final overlay = _resolveOverlay(context);
    assert(
      overlay != null,
      'showNibToast: no Overlay found. Wrap your app in a NibToaster (e.g. via '
      'MaterialApp.builder) so toasts work anywhere without a context, or pass '
      'a `context:` that has an Overlay ancestor.',
    );
    if (overlay == null) return id ?? '';
    _overlay = overlay;
    final themes = context == null
        ? null
        : InheritedTheme.capture(from: context, to: overlay.context);
    final resolvedId = id ?? '__nib_toast_${_autoId++}';

    final existing = _liveById(resolvedId);
    if (existing != null) {
      switch (onDuplicateTrigger) {
        case NibToastDuplicateBehavior.ignore:
          return resolvedId;
        case NibToastDuplicateBehavior.shake:
          existing.shakeBump++;
          _restartTimer(existing);
          notifyListeners();
          return resolvedId;
        case NibToastDuplicateBehavior.replace:
          existing
            ..title = title
            ..message = message
            ..content = content
            ..variant = variant
            ..icon = icon
            ..actionLabel = actionLabel
            ..onAction = onAction
            ..showCloseButton = showCloseButton
            ..dismissible = dismissible
            ..duration = duration
            ..onDismiss = onDismiss
            ..padding = padding
            ..borderRadius = borderRadius
            ..backgroundColor = backgroundColor;
          existing.themes = themes;
          _restartTimer(existing);
          notifyListeners();
          return resolvedId;
      }
    }

    final data = _ToastData(
      id: resolvedId,
      position: position,
      duration: duration,
      animated: animated,
      transition: transition,
      title: title,
      message: message,
      content: content,
      variant: variant,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      showCloseButton: showCloseButton,
      dismissible: dismissible,
      onDismiss: onDismiss,
      padding: padding,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
      themes: themes,
    );
    _toasts.add(data);
    _ensureHost();
    _startTimer(data);
    _enforceMax(position);
    notifyListeners();
    return resolvedId;
  }

  void dismiss(String id) {
    final data = _liveById(id);
    if (data == null) return;
    data.timer?.cancel();
    data.dismissing = true;
    if (!data.animated) {
      _remove(data);
      return;
    }
    notifyListeners(); // item plays its exit
    Timer(_exitDuration(data), () => _remove(data));
  }

  void dismissAll() {
    for (final t in _toasts.toList()) {
      dismiss(t.id);
    }
  }

  _ToastData? _liveById(String id) {
    for (final t in _toasts) {
      if (t.id == id && !t.dismissing) return t;
    }
    return null;
  }

  void _enforceMax(NibToastPosition position) {
    final live = _toasts
        .where((t) => t.position == position && !t.dismissing)
        .toList();
    if (live.length > maxVisible) {
      dismiss(live.first.id); // oldest, FIFO
    }
  }

  void _startTimer(_ToastData d) {
    if (d.duration <= Duration.zero) return;
    d.timer = Timer(d.duration, () => dismiss(d.id));
  }

  void _restartTimer(_ToastData d) {
    d.timer?.cancel();
    _startTimer(d);
  }

  Duration _exitDuration(_ToastData d) {
    final t = d.transition ?? _defaultToastTransition;
    final base = t.spring != null
        ? const Duration(milliseconds: 450)
        : t.duration;
    return base + t.delay + const Duration(milliseconds: 40);
  }

  void _remove(_ToastData d) {
    if (!_toasts.remove(d)) return;
    d.timer?.cancel();
    d.onDismiss?.call();
    if (_toasts.isEmpty) {
      _teardownHost();
    } else {
      notifyListeners();
    }
  }

  void _ensureHost() {
    if (_entry != null) return;
    _entry = OverlayEntry(builder: (_) => const _NibToastHost());
    _overlay!.insert(_entry!);
  }

  void _teardownHost() {
    _entry?.remove();
    _entry = null;
    notifyListeners();
  }
}

final _NibToastManager _manager = _NibToastManager._();

/// Shows a toast over the root [Overlay] and returns its id (use it with
/// [dismissNibToast]). Toasts stack at their [position] and auto-dismiss after
/// [duration] (`Duration.zero` keeps it until dismissed).
///
/// **Context-free:** wrap your app in a [NibToaster] (e.g. via
/// `MaterialApp.builder`) and you can call `showNibToast(...)` from anywhere —
/// a service, a bloc, a callback — with no `context`. If you don't use a
/// [NibToaster], pass a [context] that has an [Overlay] ancestor.
///
/// Passing an [id] that is already showing applies [onDuplicateTrigger] instead
/// of stacking a duplicate — by default the existing toast [NibToastDuplicateBehavior.shake]s.
///
/// Shape it with [padding], [borderRadius], and [backgroundColor] (handy when
/// supplying your own [content]).
///
/// ```dart
/// showNibToast(
///   title: 'Saved',
///   variant: NibToastVariant.success,
///   animated: true,
/// );
/// ```
String showNibToast({
  BuildContext? context,
  String? id,
  String? title,
  String? message,
  Widget? content,
  NibToastVariant variant = NibToastVariant.normal,
  IconData? icon,
  NibToastPosition position = NibToastPosition.bottomRight,
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
  bool showCloseButton = true,
  bool dismissible = true,
  NibToastDuplicateBehavior onDuplicateTrigger =
      NibToastDuplicateBehavior.shake,
  bool animated = false,
  NibTransition? transition,
  VoidCallback? onDismiss,
  EdgeInsetsGeometry? padding,
  BorderRadiusGeometry? borderRadius,
  Color? backgroundColor,
}) {
  return _manager.show(
    context: context,
    id: id,
    title: title,
    message: message,
    content: content,
    variant: variant,
    icon: icon,
    position: position,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
    showCloseButton: showCloseButton,
    dismissible: dismissible,
    onDuplicateTrigger: onDuplicateTrigger,
    animated: animated,
    transition: transition,
    onDismiss: onDismiss,
    padding: padding,
    borderRadius: borderRadius,
    backgroundColor: backgroundColor,
  );
}

/// Wrap your app once (typically via `MaterialApp.builder`) so [showNibToast]
/// works anywhere without a `context`:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => NibToaster(child: child!),
///   home: HomePage(),
/// );
/// ```
///
/// It hosts its own [Overlay] (with the app as the base layer) and registers it
/// with the toast controller, so toasts float above the whole app. Since
/// `MaterialApp.builder` sits *above* the Navigator's overlay, `NibToaster`
/// supplies one there itself rather than borrowing an ancestor's.
class NibToaster extends StatefulWidget {
  const NibToaster({super.key, required this.child});

  final Widget child;

  @override
  State<NibToaster> createState() => _NibToasterState();
}

class _NibToasterState extends State<NibToaster> {
  final GlobalKey<OverlayState> _overlayKey = GlobalKey<OverlayState>();
  late final OverlayEntry _appEntry = OverlayEntry(
    builder: (_) => widget.child,
    maintainState: true,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _overlayKey.currentState;
      if (state != null) _manager.registerOverlay(state);
    });
  }

  @override
  void didUpdateWidget(covariant NibToaster old) {
    super.didUpdateWidget(old);
    // The wrapped app subtree can change (theme, locale…); rebuild the base entry.
    _appEntry.markNeedsBuild();
  }

  @override
  void dispose() {
    final state = _overlayKey.currentState;
    if (state != null) _manager.unregisterOverlay(state);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(key: _overlayKey, initialEntries: [_appEntry]);
  }
}

/// Dismisses the toast with [id] (no-op if it isn't showing).
void dismissNibToast(String id) => _manager.dismiss(id);

/// Dismisses every visible toast.
void dismissAllNibToasts() => _manager.dismissAll();

/// Full-screen overlay host: renders each position's stack. Rebuilds on manager
/// changes.
class _NibToastHost extends StatelessWidget {
  const _NibToastHost();

  static const double _edgeMargin = 16;
  static const double _maxWidth = 360;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final itemWidth = math.min(_maxWidth, width - _edgeMargin * 2);
        final stacks = <Widget>[];
        for (final position in NibToastPosition.values) {
          final items = _manager.at(position);
          if (items.isEmpty) continue;
          stacks.add(_buildStack(position, items, itemWidth));
        }
        return Stack(children: stacks);
      },
    );
  }

  Widget _buildStack(
    NibToastPosition position,
    List<_ToastData> items,
    double itemWidth,
  ) {
    // Newest nearest the anchor edge: top stacks put newest first, bottom stacks
    // keep insertion order and anchor to the bottom.
    final ordered = position.isTop ? items.reversed.toList() : items;
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_edgeMargin),
          child: Align(
            alignment: position.alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: itemWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final d in ordered) _buildItem(d)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(_ToastData data) {
    final item = _NibToastItem(
      key: ValueKey(data.id),
      data: data,
      dismissing: data.dismissing,
      shakeBump: data.shakeBump,
      onDismiss: () => _manager.dismiss(data.id),
    );
    return data.themes?.wrap(item) ?? item;
  }
}

class _NibToastItem extends StatefulWidget {
  const _NibToastItem({
    super.key,
    required this.data,
    required this.dismissing,
    required this.shakeBump,
    required this.onDismiss,
  });

  final _ToastData data;
  final bool dismissing;
  final int shakeBump;
  final VoidCallback onDismiss;

  @override
  State<_NibToastItem> createState() => _NibToastItemState();
}

class _NibToastItemState extends State<_NibToastItem>
    with TickerProviderStateMixin {
  static const double _dismissThreshold = 96;

  late final AnimationController _size;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _drag = AnimationController.unbounded(
    vsync: this,
  );

  int _lastShakeBump = 0;

  bool get _animated => widget.data.animated;

  NibTransition get _transition =>
      widget.data.transition ?? _defaultToastTransition;

  @override
  void initState() {
    super.initState();
    _size = AnimationController(
      vsync: this,
      duration: _animated ? _transition.duration : Duration.zero,
    )..forward();
    _lastShakeBump = widget.shakeBump;
  }

  @override
  void didUpdateWidget(covariant _NibToastItem old) {
    super.didUpdateWidget(old);
    if (widget.dismissing && !old.dismissing) {
      _size.reverse();
    }
    if (widget.shakeBump != _lastShakeBump) {
      _lastShakeBump = widget.shakeBump;
      _drag.value = 0;
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _shake.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _drag.value += d.primaryDelta ?? d.delta.dx;
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_drag.value.abs() > _dismissThreshold || v.abs() > 700) {
      widget.onDismiss();
    } else {
      _drag.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  NibAnim get _enter {
    // Start/end positions slide in from the left/right edge; centered positions
    // slide vertically. (Otherwise every toast slid only up/down.)
    final off = widget.data.position.enterOffset;
    return NibAnim(x: off.dx, y: off.dy, opacity: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    Widget card = _buildCard(theme);

    if (widget.data.dismissible) {
      card = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: card,
      );
    }

    // Swipe translate + fade.
    card = AnimatedBuilder(
      animation: _drag,
      builder: (context, child) {
        final opacity = (1 - (_drag.value.abs() / 240)).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(_drag.value, 0),
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: card,
    );

    // Duplicate shake — a decaying horizontal wobble (works with animated:false).
    card = AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = t == 0 ? 0.0 : math.sin(t * math.pi * 5) * (1 - t) * 8;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: card,
    );

    // Enter/exit slide+fade via nib_motion when animated; instant otherwise.
    if (_animated) {
      card = NibPresence(
        children: widget.dismissing
            ? const []
            : [
                NibMotion(
                  key: ValueKey('nib-toast-motion-${widget.data.id}'),
                  initial: _enter,
                  animate: NibAnim.identity,
                  exit: _enter,
                  transition: _transition,
                  child: card,
                ),
              ],
      );
    } else if (widget.dismissing) {
      card = const SizedBox.shrink();
    }

    // Height-collapse reflow so neighbours slide as this item enters/leaves.
    return ClipRect(
      child: AnimatedBuilder(
        animation: _size,
        builder: (context, child) {
          return Align(
            alignment: widget.data.position.isTop
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            heightFactor: Curves.easeOut.transform(_size.value.clamp(0.0, 1.0)),
            child: child,
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: card,
        ),
      ),
    );
  }

  Widget _buildCard(NibTheme theme) {
    final data = widget.data;
    final accent = data.variant.accent(theme);
    final icon = data.icon ?? data.variant.defaultIcon();

    final Widget body =
        data.content ??
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data.title != null)
              Text(
                data.title!,
                style: TextStyle(
                  color: theme.foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            if (data.message != null)
              Padding(
                padding: EdgeInsets.only(top: data.title != null ? 2 : 0),
                child: Text(
                  data.message!,
                  style: TextStyle(color: theme.mutedForeground, fontSize: 13),
                ),
              ),
          ],
        );

    final radius = data.borderRadius ?? BorderRadius.circular(theme.radiusLg);
    return Material(
      color: data.backgroundColor ?? theme.card,
      elevation: 6,
      shadowColor: const Color(0x33000000),
      borderRadius: radius,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.border),
          borderRadius: radius,
        ),
        padding: data.padding ?? const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: body),
            if (data.actionLabel != null) ...[
              const SizedBox(width: 8),
              _ActionButton(
                label: data.actionLabel!,
                color: accent,
                onTap: () {
                  data.onAction?.call();
                  widget.onDismiss();
                },
              ),
            ],
            if (data.showCloseButton)
              Padding(
                padding: EdgeInsets.only(
                  left: data.actionLabel != null ? 2 : 6,
                ),
                child: _CloseButton(
                  color: theme.mutedForeground,
                  onTap: widget.onDismiss,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Dismiss',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.close_rounded, size: 16, color: color),
        ),
      ),
    );
  }
}
