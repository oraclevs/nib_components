import 'package:flutter/widgets.dart';

/// One item in a [NibNavigationMenu]. [children] may itself contain items
/// with further [children], producing cascading (horizontal) or nested
/// (vertical) submenus of arbitrary depth.
///
/// [id] must be unique across the whole tree passed to one
/// `NibNavigationMenu` — it keys per-item overlay/focus/open-state
/// tracking.
class NibNavItem {
  const NibNavItem({
    required this.id,
    required this.label,
    this.icon,
    this.disabled = false,
    this.badge,
    this.children = const [],
  });

  final String id;
  final String label;
  final Widget? icon;
  final bool disabled;
  final Widget? badge;
  final List<NibNavItem> children;

  /// Whether this item has any nested [children].
  bool get hasChildren => children.isNotEmpty;
}
