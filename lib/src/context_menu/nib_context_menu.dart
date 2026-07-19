import 'package:flutter/widgets.dart';
import 'package:nib_motion/nib_motion.dart' show NibTransition;

import 'nib_menu_entry.dart';
import 'show_nib_context_menu.dart';

/// Wraps [child] so a right-click (desktop/web) or long-press (touch) opens a
/// context menu at the exact pointer/touch point, clamped to the viewport.
///
/// ```dart
/// NibContextMenu(
///   items: [
///     NibMenuItem(label: 'Copy', icon: Icon(Icons.copy)),
///     const NibMenuDivider(),
///     NibMenuItem(label: 'Delete', destructive: true),
///   ],
///   onItemSelected: (item) => print(item.label),
///   child: const Card(child: SizedBox(width: 200, height: 120)),
/// )
/// ```
///
/// Submenus (a [NibMenuItem] with a `submenu`) open to the side; keyboard
/// navigation (↑/↓ move, →/Enter open/activate, ←/Esc back) works once open.
class NibContextMenu extends StatelessWidget {
  const NibContextMenu({
    super.key,
    required this.items,
    required this.child,
    this.onItemSelected,
    this.enableSecondaryTap = true,
    this.enableLongPress = true,
    this.animated = false,
    this.transition,
  });

  /// The menu entries — selectable [NibMenuItem]s (optionally with submenus),
  /// [NibMenuDivider]s, and [NibMenuSection] headers.
  final List<NibMenuEntry> items;

  /// The widget the menu is attached to.
  final Widget child;

  /// Called with the chosen leaf item.
  final ValueChanged<NibMenuItem>? onItemSelected;

  /// Whether a right-click (secondary tap) opens the menu — the desktop/web
  /// trigger.
  final bool enableSecondaryTap;

  /// Whether a long-press opens the menu — the touch trigger.
  final bool enableLongPress;

  /// Opt-in enter animation via `nib_motion`. `false` builds zero `NibMotion`
  /// overhead.
  final bool animated;

  final NibTransition? transition;

  void _open(BuildContext context, Offset globalPosition) {
    showNibContextMenu(
      context,
      globalPosition: globalPosition,
      items: items,
      onItemSelected: onItemSelected,
      animated: animated,
      transition: transition,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: enableSecondaryTap
          ? (d) => _open(context, d.globalPosition)
          : null,
      onLongPressStart: enableLongPress
          ? (d) => _open(context, d.globalPosition)
          : null,
      child: child,
    );
  }
}
