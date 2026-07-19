import 'package:flutter/widgets.dart';

/// Overridable match predicate used by [NibCommandPalette]'s filtering —
/// `true` if [action] should remain visible for the current [query].
typedef NibCommandActionFilter =
    bool Function(NibCommandAction action, String query);

/// One entry in a [NibCommandPalette]'s action list.
///
/// An action with non-empty [children] is a branch: selecting it drills the
/// palette into those children instead of firing selection (e.g. "Change
/// theme" -> "Light" / "Dark" / "System"). A leaf action (no children) fires
/// its own [onSelected] and the palette's `onActionSelected`, then closes.
@immutable
class NibCommandAction {
  const NibCommandAction({
    required this.id,
    required this.label,
    this.subtitle,
    this.icon,
    this.shortcutLabel,
    this.group,
    this.children = const [],
    this.onSelected,
    this.disabled = false,
  });

  /// Stable identifier, used for recent-action tracking and as a default
  /// list key.
  final String id;

  final String label;

  final String? subtitle;

  final Widget? icon;

  /// Display-only shortcut hint (e.g. `'⌘S'`) — not a real key binding.
  final String? shortcutLabel;

  /// Section-header key. Actions sharing the same [group] are clustered
  /// together in display order; `null` renders with no header.
  final String? group;

  /// Sub-actions revealed when this action is selected. Non-empty makes
  /// this a branch rather than a leaf.
  final List<NibCommandAction> children;

  final VoidCallback? onSelected;

  final bool disabled;

  bool get hasChildren => children.isNotEmpty;
}
