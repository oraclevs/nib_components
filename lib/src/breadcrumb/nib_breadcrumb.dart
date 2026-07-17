import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart' show NibAnim, NibMotion, NibTransition;

import '../popover/nib_popover.dart';
import '../theme/nib_theme.dart';
import 'nib_breadcrumb_types.dart';

/// A navigation trail that auto-collapses its middle items into an ellipsis /
/// overflow menu when there are too many crumbs or the viewport is too narrow.
///
/// Simple by default — `NibBreadcrumb(items: [...])` — with the last item shown
/// as the current page. Collapsing is driven by [maxVisibleItems] **and** the
/// available width; the hidden crumbs open in a [NibPopover] from the `…`.
///
/// ```dart
/// NibBreadcrumb(items: [
///   NibBreadcrumbItem(label: 'Home', onTap: goHome),
///   NibBreadcrumbItem(label: 'Docs', onTap: goDocs),
///   NibBreadcrumbItem(label: 'Breadcrumb'), // current
/// ])
/// ```
class NibBreadcrumb extends StatefulWidget {
  const NibBreadcrumb({
    super.key,
    required this.items,
    this.maxVisibleItems,
    this.itemsBeforeCollapse = 1,
    this.itemsAfterCollapse = 1,
    this.separator,
    this.disabled = false,
    this.overflowPlacement = NibPopoverPlacement.bottom,
    this.linkColor,
    this.currentColor,
    this.separatorColor,
    this.fontSize,
    this.itemPadding,
    this.gap,
    this.animated = false,
    this.transition,
    this.semanticLabel,
  });

  /// The trail, root → current. The **last** item is the current page.
  final List<NibBreadcrumbItem> items;

  /// Collapse the middle once the trail exceeds this many items. `null` ⇒
  /// collapse only when the trail doesn't fit the available width.
  final int? maxVisibleItems;

  /// Leading crumbs kept when collapsed.
  final int itemsBeforeCollapse;

  /// Trailing crumbs kept when collapsed.
  final int itemsAfterCollapse;

  /// Separator between crumbs. Defaults to a chevron `›`.
  final Widget? separator;

  /// Disables links and dims the trail.
  final bool disabled;

  /// Placement of the overflow popover relative to the `…`.
  final NibPopoverPlacement overflowPlacement;

  /// Link (non-current) crumb colour. Defaults to `NibTheme.mutedForeground`.
  final Color? linkColor;

  /// Current (last) crumb colour. Defaults to `NibTheme.foreground`.
  final Color? currentColor;

  /// Separator colour. Defaults to `NibTheme.mutedForeground`.
  final Color? separatorColor;

  /// Crumb text size. Defaults to 14.
  final double? fontSize;

  /// Padding around each crumb. Defaults to `EdgeInsets.symmetric(horizontal: 4)`.
  final EdgeInsetsGeometry? itemPadding;

  /// Icon↔label spacing. Defaults to 6.
  final double? gap;

  /// Opt-in `nib_motion`: crumbs slide+fade in, staggered. `false` builds
  /// **zero** [NibMotion].
  final bool animated;

  /// Timing for [animated]. `null` → a short ~220ms ease.
  final NibTransition? transition;

  /// Accessible name for the trail. Defaults to `'Breadcrumb'`.
  final String? semanticLabel;

  @override
  State<NibBreadcrumb> createState() => _NibBreadcrumbState();
}

class _NibBreadcrumbState extends State<NibBreadcrumb> {
  bool get _interactive => !widget.disabled;
  double get _fontSize => widget.fontSize ?? 14;
  double get _gap => widget.gap ?? 6;
  EdgeInsetsGeometry get _itemPadding =>
      widget.itemPadding ?? const EdgeInsets.symmetric(horizontal: 4);

  int get _count => widget.items.length;
  int get _lastIndex => _count - 1;

  // --- fit measurement ------------------------------------------------------

  double _measure(String text) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: _fontSize)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.width;
  }

  double get _iconSlot => _fontSize + 2 + _gap;
  double get _sepSlot => _fontSize + 2 + 4; // chevron + its side padding
  double get _padSlot => 8; // itemPadding horizontal total (4 + 4)

  double _crumbWidth(NibBreadcrumbItem item) =>
      _measure(item.label) + (item.icon != null ? _iconSlot : 0) + _padSlot;

  double get _fullWidth {
    var w = 0.0;
    for (final item in widget.items) {
      w += _crumbWidth(item);
    }
    return w + (_count - 1) * _sepSlot;
  }

  bool _shouldCollapse(double available) {
    if (_count <= widget.itemsBeforeCollapse + widget.itemsAfterCollapse) {
      return false;
    }
    if (widget.maxVisibleItems != null && _count > widget.maxVisibleItems!) {
      return true;
    }
    return _fullWidth > available;
  }

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final theme = NibTheme.of(context);

    Widget trail = LayoutBuilder(
      builder: (context, constraints) {
        final available =
            constraints.hasBoundedWidth ? constraints.maxWidth : double.infinity;
        final collapsed = _shouldCollapse(available);
        final indices = breadcrumbVisibleIndices(
          count: _count,
          collapsed: collapsed,
          before: widget.itemsBeforeCollapse,
          after: widget.itemsAfterCollapse,
        );

        final children = <Widget>[];
        for (var pos = 0; pos < indices.length; pos++) {
          if (pos > 0) children.add(_separator(theme));
          final idx = indices[pos];
          Widget inner =
              idx == null ? _ellipsis(theme) : _crumbInner(theme, idx);
          if (widget.animated) {
            inner = NibMotion(
              key: ValueKey('crumb_$pos'),
              initial: const NibAnim(x: -8, opacity: 0),
              animate: NibAnim.identity,
              transition: _transitionFor(pos),
              child: inner,
            );
          }
          children.add(inner);
        }

        // Collapsing handles the common narrow case; a horizontal scroll is the
        // last-resort fallback so a pathologically narrow viewport can never
        // overflow (§1.7).
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        );
      },
    );

    trail = Semantics(
      container: true,
      label: widget.semanticLabel ?? 'Breadcrumb',
      child: trail,
    );
    if (!_interactive) trail = Opacity(opacity: 0.5, child: trail);
    return trail;
  }

  NibTransition _transitionFor(int pos) {
    final base = widget.transition ??
        const NibTransition(duration: Duration(milliseconds: 220));
    return NibTransition(
      duration: base.duration,
      curve: base.curve,
      delay: base.delay + Duration(milliseconds: pos * 40),
      spring: base.spring,
    );
  }

  Widget _separator(NibTheme theme) {
    final color = widget.separatorColor ?? theme.mutedForeground;
    final sep = widget.separator ??
        Icon(Icons.chevron_right, size: _fontSize + 2, color: color);
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: sep);
  }

  Widget _icon(NibTheme theme, Widget icon, Color color) => IconTheme.merge(
        data: IconThemeData(color: color, size: _fontSize + 2),
        child: icon,
      );

  Widget _crumbInner(NibTheme theme, int idx) {
    final item = widget.items[idx];
    final isLast = idx == _lastIndex;

    if (isLast) {
      final color = widget.currentColor ?? theme.foreground;
      final text = Text(
        item.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: _fontSize,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      );
      final content = item.icon == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _icon(theme, item.icon!, color),
                SizedBox(width: _gap),
                Flexible(child: text),
              ],
            );
      return Padding(
        padding: _itemPadding,
        child: Semantics(header: true, child: content),
      );
    }

    final linkColor = widget.linkColor ?? theme.mutedForeground;
    if (item.onTap != null && _interactive) {
      return Padding(
        padding: _itemPadding,
        child: _CrumbLink(
          label: item.label,
          icon: item.icon,
          onTap: item.onTap!,
          color: linkColor,
          activeColor: theme.foreground,
          fontSize: _fontSize,
          gap: _gap,
        ),
      );
    }

    // Non-current, non-interactive → plain text.
    final text = Text(
      item.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: _fontSize, color: linkColor),
    );
    return Padding(
      padding: _itemPadding,
      child: item.icon == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _icon(theme, item.icon!, linkColor),
                SizedBox(width: _gap),
                text,
              ],
            ),
    );
  }

  Widget _ellipsis(NibTheme theme) {
    final hidden = widget.items.sublist(
      widget.itemsBeforeCollapse,
      _count - widget.itemsAfterCollapse,
    );
    final color = widget.separatorColor ?? theme.mutedForeground;

    return NibPopover(
      placement: widget.overflowPlacement,
      animated: widget.animated,
      transition: widget.transition,
      maxWidth: 260,
      semanticLabel: 'Show ${hidden.length} hidden breadcrumbs',
      trigger: Padding(
        padding: _itemPadding,
        child: Text(
          '…',
          style: TextStyle(
            fontSize: _fontSize + 2,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      content: _OverflowMenu(
        items: hidden,
        theme: theme,
        fontSize: _fontSize,
        gap: _gap,
      ),
    );
  }
}

/// A focusable, hover-underlined breadcrumb link built on
/// [FocusableActionDetector] (native focus + `ActivateIntent` on Enter/Space +
/// click cursor) with a tap [GestureDetector].
class _CrumbLink extends StatefulWidget {
  const _CrumbLink({
    required this.label,
    required this.onTap,
    required this.color,
    required this.activeColor,
    required this.fontSize,
    required this.gap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color activeColor;
  final double fontSize;
  final double gap;
  final Widget? icon;

  @override
  State<_CrumbLink> createState() => _CrumbLinkState();
}

class _CrumbLinkState extends State<_CrumbLink> {
  bool _hover = false;
  bool _focus = false;
  bool get _active => _hover || _focus;

  @override
  Widget build(BuildContext context) {
    final color = _active ? widget.activeColor : widget.color;
    final text = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: widget.fontSize,
        color: color,
        decoration: _active ? TextDecoration.underline : TextDecoration.none,
      ),
    );
    final content = widget.icon == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme.merge(
                data: IconThemeData(color: color, size: widget.fontSize + 2),
                child: widget.icon!,
              ),
              SizedBox(width: widget.gap),
              text,
            ],
          );

    return Semantics(
      link: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          onShowHoverHighlight: (h) => setState(() => _hover = h),
          onShowFocusHighlight: (f) => setState(() => _focus = f),
          child: content,
        ),
      ),
    );
  }
}

/// The card of hidden crumbs shown inside the overflow [NibPopover]. Each tile
/// runs the crumb's `onTap` and closes the popover via [NibPopoverScope].
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.items,
    required this.theme,
    required this.fontSize,
    required this.gap,
  });

  final List<NibBreadcrumbItem> items;
  final NibTheme theme;
  final double fontSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(theme.radiusDefault),
        border: Border.all(color: theme.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          for (final item in items)
            Builder(
              builder: (context) => InkWell(
                onTap: () {
                  item.onTap?.call();
                  NibPopoverScope.of(context).close();
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.icon != null) ...[
                        IconTheme.merge(
                          data: IconThemeData(
                            color: theme.foreground,
                            size: fontSize + 2,
                          ),
                          child: item.icon!,
                        ),
                        SizedBox(width: gap),
                      ],
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: fontSize,
                          color: theme.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
