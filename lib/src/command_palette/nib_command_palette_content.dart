import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibTransition;

import '../theme/nib_theme.dart';
import 'nib_command_action.dart';
import 'nib_command_palette_filter.dart';

/// The visible body of an open `NibCommandPalette` — search field, breadcrumb,
/// and grouped/filtered action list. Mounted inside the palette's
/// `OverlayEntry`; sizing/centering/barrier are the wrapper's responsibility,
/// this widget just fills whatever bounded box it's given.
class NibCommandPaletteContent extends StatefulWidget {
  const NibCommandPaletteContent({
    super.key,
    required this.actions,
    required this.placeholder,
    required this.filter,
    required this.showRecent,
    required this.recentActionIds,
    required this.animated,
    required this.transition,
    required this.onActivate,
    required this.onRequestClose,
    this.backgroundColor,
    this.hintStyle,
  });

  final List<NibCommandAction> actions;
  final String placeholder;
  final Color? backgroundColor;
  final TextStyle? hintStyle;
  final NibCommandActionFilter filter;
  final bool showRecent;
  final List<String> recentActionIds;
  final bool animated;
  final NibTransition? transition;

  /// Called when a leaf action (no children) is chosen, by tap or Enter.
  final ValueChanged<NibCommandAction> onActivate;

  /// Called when Escape is pressed at the root drill-down level (a deeper
  /// level pops one level instead, handled internally).
  final VoidCallback onRequestClose;

  @override
  State<NibCommandPaletteContent> createState() =>
      _NibCommandPaletteContentState();
}

class _NibCommandPaletteContentState extends State<NibCommandPaletteContent> {
  final _queryController = TextEditingController();
  final _searchFocusNode = FocusNode(debugLabel: 'nib-command-palette-search');
  final Map<String, GlobalKey> _rowKeys = {};

  final List<NibCommandAction> _stack = [];
  String? _highlightedId;

  @override
  void initState() {
    super.initState();
    // The search field's own `autofocus` isn't enough here: this widget is
    // mounted into an `OverlayEntry` alongside the host app's existing
    // routed content, whose `FocusScope` may already hold primary focus by
    // the time this overlay appears — `autofocus` only claims focus when
    // its nearest scope has none, it doesn't steal it. An explicit
    // `requestFocus` after the first frame does.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<NibCommandAction> get _currentLevelActions =>
      _stack.isEmpty ? widget.actions : _stack.last.children;

  GlobalKey _rowKeyFor(String slotId) =>
      _rowKeys.putIfAbsent(slotId, GlobalKey.new);

  // A "Recent" action and its root-list counterpart are the same
  // NibCommandAction (and id) rendered in two different rows at once, so
  // row identity (for GlobalKeys, highlight, and nav) has to be keyed by
  // (bucket, action) — bare action.id would collide across the two rows.
  String _slotIdFor(String? group, NibCommandAction action) =>
      '${group ?? ''}#${action.id}';

  List<NibCommandActionBucket> _visibleBuckets() {
    final query = _queryController.text;
    final level = _currentLevelActions;
    if (widget.showRecent &&
        _stack.isEmpty &&
        query.isEmpty &&
        widget.recentActionIds.isNotEmpty) {
      final recent = [
        for (final id in widget.recentActionIds)
          ?findActionById(widget.actions, id),
      ];
      if (recent.isNotEmpty) {
        return [(group: 'Recent', actions: recent), ...groupActions(level)];
      }
    }
    final filtered = filterActions(level, query, widget.filter);
    return groupActions(filtered);
  }

  List<_Slot> _flatEnabled(List<NibCommandActionBucket> buckets) => [
    for (final bucket in buckets)
      for (final action in bucket.actions)
        if (!action.disabled)
          (slotId: _slotIdFor(bucket.group, action), action: action),
  ];

  void _handleQueryChanged(String _) {
    setState(() {}); // recompute buckets; highlight is reconciled in build()
  }

  void _ensureHighlightValid(List<_Slot> flatEnabled) {
    if (flatEnabled.isEmpty) {
      _highlightedId = null;
      return;
    }
    if (_highlightedId == null ||
        !flatEnabled.any((s) => s.slotId == _highlightedId)) {
      _highlightedId = flatEnabled.first.slotId;
    }
  }

  void _moveHighlight(int delta, List<_Slot> flatEnabled) {
    if (flatEnabled.isEmpty) return;
    final currentIndex = flatEnabled.indexWhere(
      (s) => s.slotId == _highlightedId,
    );
    final nextIndex = currentIndex == -1
        ? 0
        : (currentIndex + delta) % flatEnabled.length;
    final wrapped = nextIndex < 0 ? flatEnabled.length + nextIndex : nextIndex;
    setState(() => _highlightedId = flatEnabled[wrapped].slotId);
    final key = _rowKeys[flatEnabled[wrapped].slotId];
    final rowContext = key?.currentContext;
    if (rowContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (rowContext.mounted) {
          Scrollable.ensureVisible(
            rowContext,
            alignment: 0.5,
            duration: const Duration(milliseconds: 100),
          );
        }
      });
    }
  }

  void _activate(NibCommandAction action) {
    if (action.disabled) return;
    if (action.hasChildren) {
      setState(() {
        _stack.add(action);
        _queryController.clear();
        _highlightedId = null;
      });
      return;
    }
    action.onSelected?.call();
    widget.onActivate(action);
  }

  void _activateHighlighted(List<_Slot> flatEnabled) {
    final id = _highlightedId;
    if (id == null) return;
    final slot = flatEnabled.firstWhere(
      (s) => s.slotId == id,
      orElse: () => flatEnabled.first,
    );
    _activate(slot.action);
  }

  void _handleEscape() {
    if (_stack.isNotEmpty) {
      setState(() {
        _stack.removeLast();
        _queryController.clear();
        _highlightedId = null;
      });
      return;
    }
    widget.onRequestClose();
  }

  void _popOneLevel() {
    if (_stack.isEmpty) return;
    setState(() {
      _stack.removeLast();
      _queryController.clear();
      _highlightedId = null;
    });
  }

  Widget _buildBreadcrumb(NibTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: InkWell(
        onTap: _popOneLevel,
        borderRadius: BorderRadius.circular(theme.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chevron_left, size: 18, color: theme.mutedForeground),
              Text(
                _stack.map((a) => a.label).join(' › '),
                style: TextStyle(color: theme.mutedForeground, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(NibTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: _queryController,
        focusNode: _searchFocusNode,
        onChanged: _handleQueryChanged,
        style: TextStyle(color: theme.foreground),
        decoration: InputDecoration(
          filled: false,
          border: InputBorder.none,
          hintText: widget.placeholder,
          hintStyle: TextStyle(
            color: theme.mutedForeground,
          ).merge(widget.hintStyle),
          prefixIcon: Icon(Icons.search, color: theme.mutedForeground),
        ),
      ),
    );
  }

  Widget _buildRow(
    NibTheme theme,
    NibCommandAction action,
    String slotId,
    bool highlighted,
  ) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            if (action.icon != null) ...[
              action.icon!,
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    style: TextStyle(
                      color: action.disabled
                          ? theme.mutedForeground
                          : theme.foreground,
                      fontWeight: highlighted
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (action.subtitle != null)
                    Text(
                      action.subtitle!,
                      style: TextStyle(
                        color: theme.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (action.shortcutLabel != null) ...[
              const SizedBox(width: 8),
              Text(
                action.shortcutLabel!,
                style: TextStyle(color: theme.mutedForeground, fontSize: 12),
              ),
            ],
            if (action.hasChildren) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 16, color: theme.mutedForeground),
            ],
          ],
        ),
      ),
    );

    return KeyedSubtree(
      key: _rowKeyFor(slotId),
      child: Semantics(
        button: true,
        enabled: !action.disabled,
        selected: highlighted,
        label: action.label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: highlighted ? theme.secondary : null,
            borderRadius: BorderRadius.circular(theme.radiusSm),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: action.disabled ? null : () => _activate(action),
              borderRadius: BorderRadius.circular(theme.radiusSm),
              excludeFromSemantics: true,
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(NibTheme theme, List<NibCommandActionBucket> buckets) {
    if (buckets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No results',
          style: TextStyle(color: theme.mutedForeground),
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        for (final bucket in buckets) ...[
          if (bucket.group != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                bucket.group!,
                style: TextStyle(
                  color: theme.mutedForeground,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          for (final action in bucket.actions)
            _buildRow(
              theme,
              action,
              _slotIdFor(bucket.group, action),
              _slotIdFor(bucket.group, action) == _highlightedId,
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final buckets = _visibleBuckets();
    final flatEnabled = _flatEnabled(buckets);
    _ensureHighlightValid(flatEnabled);

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_stack.isNotEmpty) _buildBreadcrumb(theme),
        _buildSearchField(theme),
        Divider(height: 1, color: theme.border),
        Flexible(child: _buildList(theme, buckets)),
      ],
    );

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _MoveHighlightIntent(
          1,
        ),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _MoveHighlightIntent(
          -1,
        ),
        LogicalKeySet(LogicalKeyboardKey.escape): const _EscapeIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter):
            const _ActivateHighlightedIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter):
            const _ActivateHighlightedIntent(),
      },
      child: Actions(
        actions: {
          _MoveHighlightIntent: CallbackAction<_MoveHighlightIntent>(
            onInvoke: (intent) {
              _moveHighlight(intent.delta, flatEnabled);
              return null;
            },
          ),
          _EscapeIntent: CallbackAction<_EscapeIntent>(
            onInvoke: (intent) {
              _handleEscape();
              return null;
            },
          ),
          _ActivateHighlightedIntent:
              CallbackAction<_ActivateHighlightedIntent>(
                onInvoke: (intent) {
                  _activateHighlighted(flatEnabled);
                  return null;
                },
              ),
        },
        child: Material(
          color: widget.backgroundColor ?? theme.card,
          elevation: 8,
          borderRadius: BorderRadius.circular(theme.radiusLg),
          clipBehavior: Clip.antiAlias,
          child: widget.animated
              ? NibMotion(
                  initial: const NibAnim(opacity: 0, scale: 0.96, y: -8),
                  animate: const NibAnim(opacity: 1, scale: 1, y: 0),
                  transition:
                      widget.transition ??
                      const NibTransition(
                        duration: Duration(milliseconds: 160),
                      ),
                  child: body,
                )
              : body,
        ),
      ),
    );
  }
}

class _MoveHighlightIntent extends Intent {
  const _MoveHighlightIntent(this.delta);
  final int delta;
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

class _ActivateHighlightedIntent extends Intent {
  const _ActivateHighlightedIntent();
}

/// One keyboard-navigable row: an action paired with its render-position
/// identity (see `_slotIdFor`), since the same action can appear twice at
/// once (its "Recent" copy and its root-list copy).
typedef _Slot = ({String slotId, NibCommandAction action});
