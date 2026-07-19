import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibTransition;

import '../theme/nib_theme.dart';
import 'nib_accordion_controller.dart';

/// One section of a [NibAccordion]: a tappable [title] header that reveals
/// [content] when open, with an optional [leading] widget.
class NibAccordionItem {
  const NibAccordionItem({
    required this.title,
    required this.content,
    this.leading,
    this.enabled = true,
  });

  /// The header widget (usually a `Text`).
  final Widget title;

  /// The body revealed when the section is open.
  final Widget content;

  /// Optional widget before the title (an icon, an avatar).
  final Widget? leading;

  /// Whether the section can be opened.
  final bool enabled;
}

/// A vertically stacked set of expandable [items].
///
/// Unlike Flutter's `ExpansionTile`, it has built-in **single-open
/// coordination**: by default opening one section closes the others. Set
/// [allowMultipleOpen] to let several stay open at once, and [defaultOpenIndex]
/// to start with one expanded.
///
/// ```dart
/// NibAccordion(items: [
///   NibAccordionItem(title: Text('Shipping'), content: Text('…')),
///   NibAccordionItem(title: Text('Returns'), content: Text('…')),
/// ])
/// ```
///
/// Expansion is instant by default; set [animated] to reveal with a height
/// animation and a `nib_motion` chevron rotation. Drive it programmatically with
/// a [NibAccordionController].
class NibAccordion extends StatefulWidget {
  const NibAccordion({
    super.key,
    required this.items,
    this.controller,
    this.allowMultipleOpen = false,
    this.defaultOpenIndex,
    this.animated = false,
    this.transition,
    this.onExpansionChanged,
  });

  final List<NibAccordionItem> items;

  /// Optional external controller. Never required — `NibAccordion` owns one
  /// internally when this is `null`, disposing it on unmount/controller-swap.
  final NibAccordionController? controller;

  /// Whether more than one section may be open at once. `false` (default) closes
  /// siblings when one opens.
  final bool allowMultipleOpen;

  /// Index of the section to start expanded (respects [allowMultipleOpen]).
  final int? defaultOpenIndex;

  /// Opt-in height + chevron animation via `nib_motion`. `false` expands
  /// instantly and builds zero `NibMotion`.
  final bool animated;

  /// Timing/curve for the [animated] reveal. `null` → a short ~220ms ease.
  final NibTransition? transition;

  /// Called on a user tap with the section index and its new open state.
  final void Function(int index, bool isOpen)? onExpansionChanged;

  @override
  State<NibAccordion> createState() => _NibAccordionState();
}

class _NibAccordionState extends State<NibAccordion> {
  late NibAccordionController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant NibAccordion old) {
    super.didUpdateWidget(old);
    if (widget.controller != old.controller) {
      _unbindController();
      _bindController(widget.controller);
    } else if (widget.allowMultipleOpen != old.allowMultipleOpen) {
      _controller.allowMultiple = widget.allowMultipleOpen;
    }
  }

  @override
  void dispose() {
    _unbindController();
    super.dispose();
  }

  void _bindController(NibAccordionController? external) {
    _controller =
        external ??
        NibAccordionController(
          allowMultiple: widget.allowMultipleOpen,
          initialOpen: widget.defaultOpenIndex != null
              ? {widget.defaultOpenIndex!}
              : null,
        );
    _ownsController = external == null;
    _controller.allowMultiple = widget.allowMultipleOpen;
    _controller.addListener(_onControllerChanged);
  }

  void _unbindController() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _handleToggle(int index) {
    _controller.toggle(index);
    widget.onExpansionChanged?.call(index, _controller.isOpen(index));
  }

  NibTransition get _transition =>
      widget.transition ??
      const NibTransition(duration: Duration(milliseconds: 220));

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final children = <Widget>[];
    for (var i = 0; i < widget.items.length; i++) {
      if (i > 0) {
        children.add(Divider(height: 1, thickness: 1, color: theme.border));
      }
      final item = widget.items[i];
      children.add(
        _NibAccordionSection(
          item: item,
          open: _controller.isOpen(i),
          animated: widget.animated,
          transition: _transition,
          theme: theme,
          onTap: item.enabled ? () => _handleToggle(i) : null,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(theme.radiusLg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radiusLg),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _NibAccordionSection extends StatefulWidget {
  const _NibAccordionSection({
    required this.item,
    required this.open,
    required this.animated,
    required this.transition,
    required this.theme,
    required this.onTap,
  });

  final NibAccordionItem item;
  final bool open;
  final bool animated;
  final NibTransition transition;
  final NibTheme theme;
  final VoidCallback? onTap;

  @override
  State<_NibAccordionSection> createState() => _NibAccordionSectionState();
}

class _NibAccordionSectionState extends State<_NibAccordionSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: widget.animated ? widget.transition.duration : Duration.zero,
    value: widget.open ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _NibAccordionSection old) {
    super.didUpdateWidget(old);
    _anim.duration = widget.animated
        ? widget.transition.duration
        : Duration.zero;
    if (widget.open != old.open) {
      widget.open ? _anim.forward() : _anim.reverse();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Widget _chevron() {
    final theme = widget.theme;
    final target = widget.open ? math.pi : 0.0;
    final icon = Transform.rotate(
      angle: target,
      child: Icon(Icons.expand_more, color: theme.mutedForeground),
    );
    if (!widget.animated) return icon;
    // The chevron sweeps between states via nib_motion; keying by [open] replays
    // it on each toggle. (The height reveal is driven by the controller — layout
    // height can't route through nib_motion's transform/opacity model.)
    return NibMotion(
      key: ValueKey(widget.open),
      initial: NibAnim(rotate: widget.open ? -math.pi : math.pi),
      animate: NibAnim.identity,
      transition: widget.transition,
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final enabled = widget.onTap != null;

    final header = InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (widget.item.leading != null) ...[
              widget.item.leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: enabled ? theme.foreground : theme.mutedForeground,
                ),
                child: widget.item.title,
              ),
            ),
            const SizedBox(width: 12),
            _chevron(),
          ],
        ),
      ),
    );

    final body = DefaultTextStyle.merge(
      style: TextStyle(color: theme.mutedForeground),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: widget.item.content,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        AnimatedBuilder(
          animation: _anim,
          builder: (context, child) {
            if (_anim.value == 0) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: Curves.easeInOut.transform(_anim.value),
                child: child,
              ),
            );
          },
          child: body,
        ),
      ],
    );
  }
}
