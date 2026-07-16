import 'package:flutter/widgets.dart';

/// One entry in a `NibContextMenu` / `showNibContextMenu` list: a selectable
/// [NibMenuItem] (optionally with a nested [NibMenuItem.submenu]), a
/// [NibMenuDivider] rule, or a [NibMenuSection] header.
sealed class NibMenuEntry {
  const NibMenuEntry();
}

/// A selectable row. Tapping it (when [enabled]) fires [onSelected] and the
/// menu's `onItemSelected`, then closes the whole menu — unless it [hasSubmenu],
/// in which case tapping/❯ opens the child menu instead.
class NibMenuItem extends NibMenuEntry {
  const NibMenuItem({
    required this.label,
    this.icon,
    this.onSelected,
    this.submenu,
    this.trailing,
    this.enabled = true,
    this.destructive = false,
  });

  /// The row's text.
  final String label;

  /// Optional leading widget (typically an [Icon]).
  final Widget? icon;

  /// Called when this leaf item is chosen. Not called for submenu parents.
  final VoidCallback? onSelected;

  /// Nested entries. When non-empty this item is a submenu parent, not a leaf.
  final List<NibMenuEntry>? submenu;

  /// Optional trailing widget (typically a keyboard-shortcut hint). Ignored for
  /// submenu parents (they show a ❯ chevron instead).
  final Widget? trailing;

  /// Whether the item can be selected/opened.
  final bool enabled;

  /// Renders the row in the destructive (danger) color.
  final bool destructive;

  /// Whether this item opens a nested submenu rather than acting as a leaf.
  bool get hasSubmenu => submenu != null && submenu!.isNotEmpty;
}

/// A horizontal rule separating groups of items.
class NibMenuDivider extends NibMenuEntry {
  const NibMenuDivider();
}

/// A non-interactive section header labelling the items beneath it.
class NibMenuSection extends NibMenuEntry {
  const NibMenuSection(this.label);

  final String label;
}
