import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:nib_motion/nib_motion.dart' show NibTransition;

import 'nib_command_action.dart';
import 'nib_command_palette_content.dart';
import 'nib_command_palette_controller.dart';
import 'nib_command_palette_filter.dart';

/// A native command palette: wraps [child] and shows a searchable,
/// keyboard-navigable action list in a centered overlay, triggered by a
/// global keyboard shortcut (default `Cmd+K` on macOS/web-on-mac, `Ctrl+K`
/// elsewhere) or programmatically via [controller].
///
/// Simplest usage needs only [actions] and [child]:
///
/// ```dart
/// NibCommandPalette(
///   actions: [
///     NibCommandAction(id: 'new-file', label: 'New File'),
///   ],
///   child: MyAppContent(),
/// )
/// ```
class NibCommandPalette extends StatefulWidget {
  const NibCommandPalette({
    super.key,
    required this.child,
    required this.actions,
    this.openShortcut,
    this.filter,
    this.placeholder = 'Type a command or search…',
    this.onActionSelected,
    this.showRecent = true,
    this.maxRecent = 5,
    this.animated = false,
    this.transition,
    this.controller,
  });

  /// The wrapped subtree. Rebuilt only when an ancestor rebuilds this
  /// widget — opening/closing the palette never touches it, since the
  /// overlay lives in a separate [OverlayEntry].
  final Widget child;

  /// The full, unfiltered action list shown at the root drill-down level.
  final List<NibCommandAction> actions;

  /// The global shortcut that opens the palette. Defaults to
  /// [defaultOpenShortcut] (platform-aware Cmd+K/Ctrl+K). Fires regardless
  /// of where focus currently is, and never blocks the host app's own
  /// bindings for any other key combination.
  final ShortcutActivator? openShortcut;

  /// Overridable match predicate. Defaults to [defaultCommandActionFilter]
  /// (case-insensitive substring match on label/subtitle).
  final NibCommandActionFilter? filter;

  final String placeholder;

  /// Fires for every leaf-action selection, in addition to that action's
  /// own [NibCommandAction.onSelected].
  final ValueChanged<NibCommandAction>? onActionSelected;

  /// Whether a "Recent" section is shown at the root level when the query
  /// is empty and history is non-empty.
  final bool showRecent;

  /// How many recently-used action ids to retain.
  final int maxRecent;

  /// Opt-in entrance/exit animation for the overlay, via `nib_motion`.
  /// `false` allocates zero `NibMotion`/`MotionValue` overhead.
  final bool animated;

  /// The transition used when [animated] is `true`. `null` falls back to a
  /// short default fade+scale.
  final NibTransition? transition;

  /// Drives open/closed state and recent-action history externally. Never
  /// required for basic use — `NibCommandPalette` creates and owns its own
  /// controller when this is `null`. Pass an explicit instance to open the
  /// palette from a trigger button elsewhere in the tree.
  final NibCommandPaletteController? controller;

  /// The default open shortcut: `Cmd+K` on macOS/web-on-mac, `Ctrl+K`
  /// elsewhere.
  static ShortcutActivator defaultOpenShortcut() {
    final isApple =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return SingleActivator(
      LogicalKeyboardKey.keyK,
      meta: isApple,
      control: !isApple,
    );
  }

  @override
  State<NibCommandPalette> createState() => _NibCommandPaletteState();
}

class _NibCommandPaletteState extends State<NibCommandPalette> {
  late NibCommandPaletteController _controller;
  late bool _ownsController;
  late ShortcutActivator _openShortcut;
  OverlayEntry? _overlayEntry;
  FocusNode? _previousFocus;

  @override
  void initState() {
    super.initState();
    _openShortcut =
        widget.openShortcut ?? NibCommandPalette.defaultOpenShortcut();
    _bindController(widget.controller);
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
  }

  @override
  void didUpdateWidget(covariant NibCommandPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    _openShortcut =
        widget.openShortcut ?? NibCommandPalette.defaultOpenShortcut();
    if (widget.controller != oldWidget.controller) {
      _unbindController();
      _bindController(widget.controller);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _removeOverlay();
    _unbindController();
    super.dispose();
  }

  void _bindController(NibCommandPaletteController? external) {
    _controller = external ?? NibCommandPaletteController();
    _ownsController = external == null;
    _controller.addListener(_handleControllerChanged);
    // Deferred rather than calling `_showOverlay` (and so `Overlay.of`)
    // synchronously here: `_bindController` runs from `initState`/
    // `didUpdateWidget`, both mid-build, and inserting into the ancestor
    // Overlay mid-build is unsafe. Only matters for the edge case of a
    // caller passing a controller that's already open before this widget
    // ever builds.
    if (_controller.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleControllerChanged();
      });
    }
  }

  void _unbindController() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) _controller.dispose();
  }

  // Global, regardless-of-focus shortcut capture: a plain `Shortcuts` widget
  // only fires along the currently-focused node's ancestor chain, which
  // fails when nothing has been focused yet. `ShortcutActivator.accepts`
  // reuses Flutter's own modifier-matching logic instead of hand-rolling it.
  // Only consumes the event (returns `true`) when it both matches and the
  // palette is currently closed, so it never blocks the host app's own
  // bindings for any other combination and doesn't interfere with typing if
  // the same combo is pressed again while already open.
  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (_controller.isOpen) return false;
    if (!_openShortcut.accepts(event, HardwareKeyboard.instance)) return false;
    _controller.open();
    return true;
  }

  void _handleControllerChanged() {
    if (_controller.isOpen) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null || !mounted) return;
    _previousFocus = FocusManager.instance.primaryFocus;
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    final entry = _overlayEntry;
    if (entry == null) return;
    _overlayEntry = null;
    entry.remove();
    final previous = _previousFocus;
    _previousFocus = null;
    if (previous != null && previous.context != null) {
      previous.requestFocus();
    }
  }

  void _handleActivate(NibCommandAction action) {
    _controller.recordUsed(action.id, widget.maxRecent);
    widget.onActionSelected?.call(action);
    _controller.close();
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final screen = MediaQuery.sizeOf(overlayContext);
    final maxWidth = math.min(640.0, screen.width - 32);
    final maxHeight = math.min(420.0, screen.height * 0.7);

    return Stack(
      children: [
        // Opaque, not translucent — a tap on the barrier must not also
        // reach whatever sits beneath it (same rationale as
        // NibAnchoredOverlay's barrier).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _controller.close,
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.symmetric(vertical: 16),
          child: Align(
            alignment: const Alignment(0, -0.6),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Semantics(
                  scopesRoute: true,
                  namesRoute: true,
                  explicitChildNodes: true,
                  label: 'Command palette',
                  child: NibCommandPaletteContent(
                    actions: widget.actions,
                    placeholder: widget.placeholder,
                    filter: widget.filter ?? defaultCommandActionFilter,
                    showRecent: widget.showRecent,
                    recentActionIds: _controller.recentActionIds,
                    animated: widget.animated,
                    transition: widget.transition,
                    onActivate: _handleActivate,
                    onRequestClose: _controller.close,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
