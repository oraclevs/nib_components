import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibTransition;

import '../overlay/measure_size.dart';
import '../overlay/overlay_positioning.dart';
import '../theme/nib_theme.dart';
import 'nib_menu_entry.dart';

/// Imperative entry point: opens a context menu at [globalPosition] (a screen
/// coordinate, e.g. a right-click or long-press point) and returns a future
/// that completes with the chosen [NibMenuItem], or `null` when dismissed.
///
/// `NibContextMenu` wraps this with right-click / long-press triggers; call this
/// directly to open a menu from your own gesture or shortcut.
Future<NibMenuItem?> showNibContextMenu(
  BuildContext context, {
  required Offset globalPosition,
  required List<NibMenuEntry> items,
  ValueChanged<NibMenuItem>? onItemSelected,
  bool animated = false,
  NibTransition? transition,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final theme = NibTheme.of(context);
  final completer = Completer<NibMenuItem?>();
  final previousFocus = FocusManager.instance.primaryFocus;

  final session = _MenuSession(
    overlay: overlay,
    theme: theme,
    onItemSelected: onItemSelected,
    animated: animated,
    transition:
        transition ??
        const NibTransition(duration: Duration(milliseconds: 140)),
    onClosed: (selected) {
      if (!completer.isCompleted) completer.complete(selected);
      previousFocus?.requestFocus();
    },
  );
  session.openRoot(globalPosition, items);
  return completer.future;
}

/// One open level in the menu chain: its overlay entry and a key to its panel
/// state (used to return keyboard focus when a deeper level closes).
class _Level {
  _Level(this.entry, this.key);
  final OverlayEntry entry;
  final GlobalKey<_MenuPanelState> key;
}

/// Owns the chain of open menu overlays: the root (positioned at the pointer,
/// with the dismiss barrier) plus any open submenus (anchored to their parent
/// item, no barrier — the root's barrier dismisses the whole chain).
class _MenuSession {
  _MenuSession({
    required this.overlay,
    required this.theme,
    required this.onItemSelected,
    required this.animated,
    required this.transition,
    required this.onClosed,
  });

  final OverlayState overlay;
  final NibTheme theme;
  final ValueChanged<NibMenuItem>? onItemSelected;
  final bool animated;
  final NibTransition transition;
  final void Function(NibMenuItem? selected) onClosed;

  final List<_Level> _levels = [];
  bool _finished = false;

  void openRoot(Offset position, List<NibMenuEntry> entries) {
    _insertLevel(
      (key) => _MenuPanel(
        key: key,
        session: this,
        level: 0,
        entries: entries,
        rootPosition: position,
        withBarrier: true,
      ),
    );
  }

  void openSubmenu(
    int parentLevel,
    List<NibMenuEntry> entries,
    LayerLink link,
    Rect anchorRect,
  ) {
    _closeToLevel(parentLevel);
    _insertLevel(
      (key) => _MenuPanel(
        key: key,
        session: this,
        level: parentLevel + 1,
        entries: entries,
        anchorLink: link,
        anchorRect: anchorRect,
        withBarrier: false,
      ),
    );
  }

  void _insertLevel(_MenuPanel Function(GlobalKey<_MenuPanelState>) build) {
    final key = GlobalKey<_MenuPanelState>();
    final entry = OverlayEntry(builder: (_) => build(key));
    _levels.add(_Level(entry, key));
    overlay.insert(entry);
  }

  /// Removes every level deeper than [level], then returns focus to the
  /// now-deepest panel.
  void _closeToLevel(int level) {
    while (_levels.length - 1 > level) {
      _levels.removeLast().entry.remove();
    }
    if (_levels.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _levels.last.key.currentState?.focusSelf();
      });
    }
  }

  /// Backs out of [level]: closes it (and anything deeper). Closing level 0
  /// dismisses the whole menu.
  void back(int level) {
    if (level <= 0) {
      closeAll(null);
      return;
    }
    _closeToLevel(level - 1);
  }

  void selectLeaf(NibMenuItem item) {
    item.onSelected?.call();
    onItemSelected?.call(item);
    closeAll(item);
  }

  void closeAll(NibMenuItem? selected) {
    if (_finished) return;
    _finished = true;
    for (final lvl in _levels) {
      lvl.entry.remove();
    }
    _levels.clear();
    onClosed(selected);
  }
}

/// The visual + keyboard body of one menu level.
class _MenuPanel extends StatefulWidget {
  const _MenuPanel({
    super.key,
    required this.session,
    required this.level,
    required this.entries,
    required this.withBarrier,
    this.rootPosition,
    this.anchorLink,
    this.anchorRect,
  });

  final _MenuSession session;
  final int level;
  final List<NibMenuEntry> entries;
  final bool withBarrier;

  /// Level 0: the pointer point the root menu positions itself at.
  final Offset? rootPosition;

  /// Submenu levels: the parent item's link + global rect for anchoring.
  final LayerLink? anchorLink;
  final Rect? anchorRect;

  @override
  State<_MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<_MenuPanel> {
  static const double _screenPad = 8;

  final _focusScopeNode = FocusScopeNode(debugLabel: 'nib-context-menu-scope');
  final _focusNode = FocusNode(debugLabel: 'nib-context-menu');
  final Map<int, LayerLink> _links = {};
  final Map<int, GlobalKey> _itemKeys = {};
  Size? _cardSize;
  int _highlight = -1;

  NibTheme get _theme => widget.session.theme;

  @override
  void dispose() {
    _focusNode.dispose();
    _focusScopeNode.dispose();
    super.dispose();
  }

  void focusSelf() {
    if (mounted) _focusNode.requestFocus();
  }

  LayerLink _linkFor(int i) => _links.putIfAbsent(i, LayerLink.new);
  GlobalKey _keyFor(int i) => _itemKeys.putIfAbsent(i, GlobalKey.new);

  List<int> get _itemIndices => [
    for (var i = 0; i < widget.entries.length; i++)
      if (widget.entries[i] case NibMenuItem(enabled: true)) i,
  ];

  void _move(int delta) {
    final indices = _itemIndices;
    if (indices.isEmpty) return;
    final pos = indices.indexOf(_highlight);
    final next = pos == -1
        ? (delta > 0 ? 0 : indices.length - 1)
        : (pos + delta + indices.length) % indices.length;
    setState(() => _highlight = indices[next]);
  }

  void _activateHighlighted({required bool submenuOnly}) {
    if (_highlight < 0) return;
    final entry = widget.entries[_highlight];
    if (entry is! NibMenuItem || !entry.enabled) return;
    if (entry.hasSubmenu) {
      _openSubmenu(_highlight, entry);
    } else if (!submenuOnly) {
      widget.session.selectLeaf(entry);
    }
  }

  void _openSubmenu(int index, NibMenuItem item) {
    final box = _keyFor(index).currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _highlight = index);
    widget.session.openSubmenu(
      widget.level,
      item.submenu!,
      _linkFor(index),
      rect,
    );
  }

  void _tapItem(int index, NibMenuItem item) {
    if (!item.enabled) return;
    _focusNode.requestFocus();
    setState(() => _highlight = index);
    if (item.hasSubmenu) {
      _openSubmenu(index, item);
    } else {
      widget.session.selectLeaf(item);
    }
  }

  // --- Card ------------------------------------------------------------------

  Widget _buildRow(int index, NibMenuEntry entry) {
    final theme = _theme;
    switch (entry) {
      case NibMenuDivider():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(height: 1, thickness: 1, color: theme.border),
        );
      case NibMenuSection(:final label):
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(
            label,
            style: TextStyle(
              color: theme.mutedForeground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        );
      case NibMenuItem():
        return _buildItemRow(index, entry);
    }
  }

  Widget _buildItemRow(int index, NibMenuItem item) {
    final theme = _theme;
    final highlighted = index == _highlight;
    final color = !item.enabled
        ? theme.mutedForeground
        : (item.destructive ? theme.destructive : theme.foreground);

    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            if (item.icon != null) ...[
              IconTheme.merge(
                data: IconThemeData(size: 18, color: color),
                child: item.icon!,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color),
              ),
            ),
            if (item.hasSubmenu)
              Icon(Icons.chevron_right, size: 18, color: theme.mutedForeground)
            else if (item.trailing != null) ...[
              const SizedBox(width: 12),
              DefaultTextStyle.merge(
                style: TextStyle(color: theme.mutedForeground, fontSize: 12),
                child: item.trailing!,
              ),
            ],
          ],
        ),
      ),
    );

    row = DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted ? theme.secondary : null,
        borderRadius: BorderRadius.circular(theme.radiusSm),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: item.enabled ? () => _tapItem(index, item) : null,
          onHover: item.enabled
              ? (h) {
                  if (h) setState(() => _highlight = index);
                }
              : null,
          borderRadius: BorderRadius.circular(theme.radiusSm),
          excludeFromSemantics: true,
          child: row,
        ),
      ),
    );

    row = Semantics(
      button: true,
      enabled: item.enabled,
      label: item.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: row,
      ),
    );

    if (!item.hasSubmenu) return row;
    // Submenu parents anchor their child overlay via a link + measurable box.
    return CompositedTransformTarget(
      link: _linkFor(index),
      child: KeyedSubtree(key: _keyFor(index), child: row),
    );
  }

  Widget _buildCard() {
    final theme = _theme;
    Widget card = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 300),
      child: Material(
        color: theme.card,
        elevation: 8,
        borderRadius: BorderRadius.circular(theme.radiusDefault),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.border),
            borderRadius: BorderRadius.circular(theme.radiusDefault),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < widget.entries.length; i++)
                  _buildRow(i, widget.entries[i]),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.session.animated) {
      card = NibMotion(
        initial: const NibAnim(opacity: 0, scale: 0.96),
        animate: NibAnim.identity,
        transition: widget.session.transition,
        child: card,
      );
    }
    return card;
  }

  // --- Keyboard --------------------------------------------------------------

  Map<ShortcutActivator, Intent> get _shortcuts => const {
    SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
    SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
    SingleActivator(LogicalKeyboardKey.arrowRight): _EnterSubmenuIntent(),
    SingleActivator(LogicalKeyboardKey.arrowLeft): _BackIntent(),
    SingleActivator(LogicalKeyboardKey.enter): _ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): _ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): _ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.escape): _BackIntent(),
  };

  Map<Type, Action<Intent>> get _actions => {
    _MoveIntent: CallbackAction<_MoveIntent>(
      onInvoke: (i) {
        _move(i.delta);
        return null;
      },
    ),
    _EnterSubmenuIntent: CallbackAction<_EnterSubmenuIntent>(
      onInvoke: (_) {
        _activateHighlighted(submenuOnly: true);
        return null;
      },
    ),
    _ActivateIntent: CallbackAction<_ActivateIntent>(
      onInvoke: (_) {
        _activateHighlighted(submenuOnly: false);
        return null;
      },
    ),
    _BackIntent: CallbackAction<_BackIntent>(
      onInvoke: (_) {
        widget.session.back(widget.level);
        return null;
      },
    ),
  };

  // --- Positioning -----------------------------------------------------------

  Widget _positioned(Widget card) {
    if (widget.rootPosition != null) {
      // Root: place the card at the pointer, clamped inside the *usable*
      // viewport (screen minus the status bar / nav bar / keyboard insets).
      final mq = MediaQuery.of(context);
      return CustomSingleChildLayout(
        delegate: _MenuPositionDelegate(
          widget.rootPosition!,
          _screenPad,
          nibOverlaySafeInsets(mq),
        ),
        child: card,
      );
    }

    // Submenu: measure, then anchor to the parent item (opens to the end,
    // flips to the start, clamps vertically) via the shared positioning core.
    final measured = MeasureSize(
      onChange: (size) {
        if (mounted && _cardSize != size) setState(() => _cardSize = size);
      },
      child: card,
    );
    if (_cardSize == null) {
      return CompositedTransformFollower(
        link: widget.anchorLink!,
        showWhenUnlinked: false,
        child: Opacity(opacity: 0, child: measured),
      );
    }
    final mq = MediaQuery.of(context);
    final geo = resolveOverlayGeometry(
      placement: NibOverlayPlacement.end,
      target: widget.anchorRect!,
      content: _cardSize!,
      screen: mq.size,
      safeInsets: nibOverlaySafeInsets(mq),
    );
    return CompositedTransformFollower(
      link: widget.anchorLink!,
      showWhenUnlinked: false,
      targetAnchor: Alignment.topLeft,
      followerAnchor: Alignment.topLeft,
      offset: geo.offset,
      child: measured,
    );
  }

  @override
  Widget build(BuildContext context) {
    final barrier = widget.withBarrier
        ? Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.session.closeAll(null),
              // Right-clicking the barrier also dismisses (rather than opening
              // the browser/native menu behind it).
              onSecondaryTap: () => widget.session.closeAll(null),
            ),
          )
        : null;

    return FocusScope(
      node: _focusScopeNode,
      autofocus: true,
      child: Shortcuts(
        shortcuts: _shortcuts,
        child: Actions(
          actions: _actions,
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            child: Stack(children: [?barrier, _positioned(_buildCard())]),
          ),
        ),
      ),
    );
  }
}

/// Positions the root menu at the pointer, nudged back inside the viewport
/// (with an [_screenPad] margin) when it would overflow the right/bottom edge.
class _MenuPositionDelegate extends SingleChildLayoutDelegate {
  _MenuPositionDelegate(this.target, this.pad, this.safeInsets);

  final Offset target;
  final double pad;
  final EdgeInsets safeInsets;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final minX = safeInsets.left + pad;
    final minY = safeInsets.top + pad;
    final maxX = size.width - safeInsets.right - pad;
    final maxY = size.height - safeInsets.bottom - pad;
    var x = target.dx;
    var y = target.dy;
    if (x + childSize.width > maxX) x = maxX - childSize.width;
    if (y + childSize.height > maxY) y = maxY - childSize.height;
    if (x < minX) x = minX;
    if (y < minY) y = minY;
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuPositionDelegate old) =>
      old.target != target || old.pad != pad || old.safeInsets != safeInsets;
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);
  final int delta;
}

class _EnterSubmenuIntent extends Intent {
  const _EnterSubmenuIntent();
}

class _BackIntent extends Intent {
  const _BackIntent();
}

class _ActivateIntent extends Intent {
  const _ActivateIntent();
}
