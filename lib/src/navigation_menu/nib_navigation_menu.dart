import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:nib_motion/nib_motion.dart' show NibAnim, NibMotion, NibPresence, NibTransition;

import '../overlay/measure_size.dart';
import '../overlay/nib_anchored_overlay.dart';
import '../theme/nib_theme.dart';
import 'nib_nav_item.dart';
import 'nib_navigation_menu_controller.dart';
import 'nib_navigation_menu_types.dart';

/// A native, recursive, multi-level navigation menu.
///
/// Simplest usage needs only [items]:
///
/// ```dart
/// NibNavigationMenu(
///   items: [
///     NibNavItem(id: 'home', label: 'Home'),
///     NibNavItem(id: 'about', label: 'About'),
///   ],
///   onItemSelected: (id) {},
/// )
/// ```
class NibNavigationMenu extends StatefulWidget {
  const NibNavigationMenu({
    super.key,
    required this.items,
    this.orientation = NibNavMenuOrientation.horizontal,
    this.activeItemId,
    this.onItemSelected,
    this.allowMultipleOpen = false,
    this.animated = false,
    this.transition,
    this.controller,
    this.semanticLabel,
  });

  /// The top-level item tree. Each item may carry further [NibNavItem]
  /// `children` of arbitrary depth.
  final List<NibNavItem> items;

  /// Whether top-level items lay out in a `Row` (cascading flyout
  /// submenus) or a `Column` (inline-expand submenus).
  final NibNavMenuOrientation orientation;

  /// The id of the item to visually mark as the current selection.
  /// Purely a visual indicator — decoupled from open/closed submenu
  /// state.
  final String? activeItemId;

  /// Called when a leaf item (or a branch item's own label, distinct from
  /// its expand/collapse affordance) is tapped.
  final ValueChanged<String>? onItemSelected;

  /// Vertical mode only: whether more than one sibling submenu can be
  /// expanded at once. `false` (default) closes other open siblings at
  /// the same depth when one opens.
  final bool allowMultipleOpen;

  /// Opt-in entrance animation for opened submenus, via `nib_motion`.
  /// `false` allocates zero `NibMotion`/`MotionValue` overhead.
  final bool animated;

  /// The transition used for [animated] submenu entrances/exits. Defaults
  /// to a short fade+scale/slide when `animated` is `true` and this is
  /// `null`.
  final NibTransition? transition;

  /// Drives open-submenu state externally. Never required for basic use —
  /// `NibNavigationMenu` creates and owns its own controller when this is
  /// `null`.
  final NibNavMenuController? controller;

  /// Accessibility label for the menu as a whole.
  final String? semanticLabel;

  @override
  State<NibNavigationMenu> createState() => _NibNavigationMenuState();
}

class _NibNavigationMenuState extends State<NibNavigationMenu> {
  late NibNavMenuController _controller;
  late bool _ownsController;

  final Map<String, LayerLink> _links = {};
  final Map<String, GlobalKey> _itemKeys = {};
  final Map<String, NibAnchoredOverlayHandle> _flyoutHandles = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, double> _measuredWidths = {};

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant NibNavigationMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _unbindController();
      _bindController(widget.controller);
    }
    final currentIds = {for (final i in widget.items) i.id};
    _measuredWidths.removeWhere((id, _) => id != '__more__' && !currentIds.contains(id));
  }

  @override
  void dispose() {
    for (final handle in _flyoutHandles.values) {
      handle.remove();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _unbindController();
    super.dispose();
  }

  void _bindController(NibNavMenuController? external) {
    _controller = external ?? NibNavMenuController();
    _ownsController = external == null;
    _controller.addListener(_handleControllerChanged);
  }

  void _unbindController() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) _controller.dispose();
  }

  void _handleControllerChanged() => setState(() {});

  LayerLink _linkFor(String id) => _links.putIfAbsent(id, LayerLink.new);
  GlobalKey _keyFor(String id) => _itemKeys.putIfAbsent(id, GlobalKey.new);
  FocusNode _focusNodeFor(String id) =>
      _focusNodes.putIfAbsent(id, () => FocusNode(debugLabel: id));

  void _handleItemTap(NibNavItem item, List<String> path, List<String> siblingIds) {
    if (item.disabled) return;
    // A mouse/touch tap on InkWell does not request focus by itself, so
    // without this, pressing Escape right after clicking an item to open
    // its flyout would find focus still sitting on the ambient route scope
    // (an ancestor of this whole menu) rather than anywhere inside it,
    // and never reach the Escape handler below.
    _focusNodeFor(item.id).requestFocus();
    if (!item.hasChildren) {
      widget.onItemSelected?.call(item.id);
      _closeFlyoutsFrom(0);
      return;
    }
    if (widget.orientation == NibNavMenuOrientation.horizontal) {
      _toggleFlyout(item, path);
    } else {
      _toggleInline(item, siblingIds);
    }
  }

  void _toggleInline(NibNavItem item, List<String> siblingIds) {
    final exclusive = widget.allowMultipleOpen ? null : (siblingIds.toSet()..remove(item.id));
    _controller.toggleOpenId(item.id, exclusiveSiblings: exclusive);
  }

  void _toggleFlyout(NibNavItem item, List<String> path) {
    final depth = path.length - 1;
    final chain = _controller.openChain;
    final alreadyOpenHere = chain.length > depth && chain[depth] == item.id;
    if (alreadyOpenHere) {
      _closeFlyoutsFrom(depth);
      return;
    }
    _closeFlyoutsFrom(depth);
    final renderBox = _keyFor(item.id).currentContext!.findRenderObject() as RenderBox;
    final handle = NibAnchoredOverlay.show(
      context,
      link: _linkFor(item.id),
      targetRenderBox: renderBox,
      placement: depth == 0 ? NibOverlayPlacement.bottom : NibOverlayPlacement.end,
      contentBuilder: (overlayContext) {
        final built = _buildFlyoutContent(item.children, path);
        if (!widget.animated) return built;
        return NibMotion(
          initial: const NibAnim(opacity: 0, scale: 0.95),
          animate: const NibAnim(opacity: 1, scale: 1),
          transition: widget.transition ?? const NibTransition(duration: Duration(milliseconds: 160)),
          child: built,
        );
      },
      onDismissed: () => _closeFlyoutsFrom(depth),
      // Only the root (depth 0) flyout in a cascade installs a barrier —
      // see NibAnchoredOverlay's withBarrier doc. Its onDismissed above
      // closes from depth 0, collapsing the whole chain in one tap.
      withBarrier: depth == 0,
    );
    _flyoutHandles[item.id] = handle;
    _controller.openChainTo(path);
  }

  void _closeFlyoutsFrom(int depth) {
    final chain = _controller.openChain;
    for (var i = chain.length - 1; i >= depth && i >= 0; i--) {
      _flyoutHandles.remove(chain[i])?.remove();
    }
    _controller.closeFromDepth(depth);
  }

  Widget _buildFlyoutContent(List<NibNavItem> items, List<String> parentPath) {
    final theme = NibTheme.of(context);
    final siblingIds = [for (final i in items) i.id];
    return Material(
      color: theme.card,
      elevation: 4,
      borderRadius: BorderRadius.circular(theme.radiusDefault),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 160),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final child in items)
              _buildItem(context, theme, child, [...parentPath, child.id], siblingIds),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    NibTheme theme,
    NibNavItem item,
    List<String> path,
    List<String> siblingIds,
  ) {
    final isActive = item.id == widget.activeItemId;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.icon != null) ...[item.icon!, const SizedBox(width: 8)],
          Text(
            item.label,
            style: TextStyle(
              color: item.disabled
                  ? theme.mutedForeground
                  : (isActive ? theme.primary : theme.foreground),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (item.badge != null) ...[const SizedBox(width: 6), item.badge!],
        ],
      ),
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: isActive
            ? Border(bottom: BorderSide(color: theme.primary, width: 2))
            : null,
      ),
      child: content,
    );

    return Semantics(
      button: true,
      enabled: !item.disabled,
      selected: isActive,
      label: item.label,
      child: CompositedTransformTarget(
        link: _linkFor(item.id),
        child: KeyedSubtree(
          key: _keyFor(item.id),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              focusNode: _focusNodeFor(item.id),
              onTap: item.disabled ? null : () => _handleItemTap(item, path, siblingIds),
              borderRadius: BorderRadius.circular(theme.radiusSm),
              excludeFromSemantics: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: decorated,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalNode(
    BuildContext context,
    NibTheme theme,
    NibNavItem item,
    List<String> path,
    List<String> siblingIds,
  ) {
    final header = _buildItem(context, theme, item, path, siblingIds);
    if (!item.hasChildren) return header;

    final isOpen = _controller.openIds.contains(item.id);
    final childSiblingIds = [for (final c in item.children) c.id];
    final childList = Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final child in item.children)
            _buildVerticalNode(context, theme, child, [...path, child.id], childSiblingIds),
        ],
      ),
    );

    final reveal = widget.animated
        ? NibPresence(
            children: [
              if (isOpen)
                NibMotion(
                  key: ValueKey('nib-nav-inline-${item.id}'),
                  initial: const NibAnim(opacity: 0, y: -6),
                  animate: const NibAnim(opacity: 1, y: 0),
                  exit: const NibAnim(opacity: 0, y: -6),
                  transition:
                      widget.transition ?? const NibTransition(duration: Duration(milliseconds: 180)),
                  child: childList,
                ),
            ],
          )
        : (isOpen ? childList : const SizedBox.shrink());

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [header, reveal],
    );
  }

  void _recordWidth(String id, double width) {
    if (_measuredWidths[id] == width) return;
    setState(() => _measuredWidths[id] = width);
  }

  Widget _measureVisual(NibNavItem item) {
    final theme = NibTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.icon != null) ...[item.icon!, const SizedBox(width: 8)],
            Text(item.label, style: TextStyle(color: theme.foreground)),
            if (item.badge != null) ...[const SizedBox(width: 6), item.badge!],
          ],
        ),
      ),
    );
  }

  ({List<NibNavItem> visible, List<NibNavItem> overflow}) _packItems(
    double maxWidth,
    double moreWidth,
  ) {
    var used = 0.0;
    final visible = <NibNavItem>[];
    final overflow = <NibNavItem>[];
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      final width = _measuredWidths[item.id];
      if (width == null) {
        // Not measured yet this frame — show everything until we know better.
        visible.add(item);
        continue;
      }
      final hasMoreAfter = i < widget.items.length - 1;
      final reserve = hasMoreAfter ? moreWidth : 0.0;
      if (visible.isEmpty || used + width + reserve <= maxWidth) {
        used += width;
        visible.add(item);
      } else {
        overflow.addAll(widget.items.sublist(i));
        break;
      }
    }
    return (visible: visible, overflow: overflow);
  }

  Widget _buildHorizontalRow(BuildContext context, NibTheme theme) {
    final measuringPass = Offstage(
      offstage: true,
      child: Row(
        children: [
          for (final item in widget.items)
            MeasureSize(
              onChange: (size) => _recordWidth(item.id, size.width),
              child: _measureVisual(item),
            ),
          MeasureSize(
            onChange: (size) => _recordWidth('__more__', size.width),
            child: _measureVisual(const NibNavItem(id: '__more__', label: 'More')),
          ),
        ],
      ),
    );

    final allMeasured =
        widget.items.every((i) => _measuredWidths.containsKey(i.id)) &&
        _measuredWidths.containsKey('__more__');

    return LayoutBuilder(
      builder: (context, constraints) {
        // Nothing is measured yet on the very first build, so we don't yet
        // know what actually fits. Rendering every item directly in a plain
        // Row here could overflow (a hard layout error) before the first
        // measurement round-trips back via _recordWidth's setState one frame
        // later — so this transient pass wraps them in a horizontally
        // scrollable fallback instead of the final non-scrolling, packed
        // Row. Every item is still immediately present and tappable; only
        // the "does it need a More menu" decision is one frame behind.
        if (!allMeasured) {
          final rawSiblingIds = [for (final i in widget.items) i.id];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              measuringPass,
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in widget.items)
                      _buildItem(context, theme, item, [item.id], rawSiblingIds),
                  ],
                ),
              ),
            ],
          );
        }

        final moreWidth = _measuredWidths['__more__'] ?? 72.0;
        final packed = _packItems(constraints.maxWidth, moreWidth);
        final displayItems = packed.overflow.isEmpty
            ? packed.visible
            : [
                ...packed.visible,
                NibNavItem(id: '__more__', label: 'More', children: packed.overflow),
              ];
        final topSiblingIds = [for (final i in displayItems) i.id];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            measuringPass,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in displayItems)
                  _buildItem(context, theme, item, [item.id], topSiblingIds),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final topSiblingIds = [for (final i in widget.items) i.id];
    final nodes = widget.orientation == NibNavMenuOrientation.vertical
        ? [
            for (final item in widget.items)
              _buildVerticalNode(context, theme, item, [item.id], topSiblingIds),
          ]
        : const <Widget>[];

    final content = Semantics(
      label: widget.semanticLabel,
      container: true,
      child: widget.orientation == NibNavMenuOrientation.horizontal
          ? _buildHorizontalRow(context, theme)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: nodes,
            ),
    );

    return Shortcuts(
      shortcuts: {LogicalKeySet(LogicalKeyboardKey.escape): const _CloseFlyoutIntent()},
      child: Actions(
        actions: {
          _CloseFlyoutIntent: CallbackAction<_CloseFlyoutIntent>(
            onInvoke: (intent) {
              if (widget.orientation == NibNavMenuOrientation.horizontal) {
                final chain = _controller.openChain;
                if (chain.isNotEmpty) _closeFlyoutsFrom(chain.length - 1);
              }
              return null;
            },
          ),
        },
        child: content,
      ),
    );
  }
}

class _CloseFlyoutIntent extends Intent {
  const _CloseFlyoutIntent();
}
