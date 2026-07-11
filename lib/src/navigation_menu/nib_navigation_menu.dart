import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart' show NibTransition;

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
  }

  @override
  void dispose() {
    for (final handle in _flyoutHandles.values) {
      handle.remove();
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

  void _handleItemTap(NibNavItem item, List<String> path, List<String> siblingIds) {
    if (item.disabled) return;
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
      contentBuilder: (overlayContext) => _buildFlyoutContent(item.children, path),
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
            _buildItem(context, theme, child, [...path, child.id], childSiblingIds),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [header, if (isOpen) childList],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final topSiblingIds = [for (final i in widget.items) i.id];
    final nodes = [
      for (final item in widget.items)
        widget.orientation == NibNavMenuOrientation.horizontal
            ? _buildItem(context, theme, item, [item.id], topSiblingIds)
            : _buildVerticalNode(context, theme, item, [item.id], topSiblingIds),
    ];

    return Semantics(
      label: widget.semanticLabel,
      container: true,
      child: widget.orientation == NibNavMenuOrientation.horizontal
          ? Row(mainAxisSize: MainAxisSize.min, children: nodes)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: nodes,
            ),
    );
  }
}
