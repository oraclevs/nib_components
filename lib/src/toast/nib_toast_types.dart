import 'package:flutter/material.dart';

import '../theme/nib_theme.dart';

/// Visual/semantic style of a toast — sets the default leading icon and accent.
enum NibToastVariant { normal, success, error, warning, info }

/// Where a toast stack is anchored. Each position is an independent stack.
enum NibToastPosition {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

/// What happens when [showNibToast] is called with an `id` that is already
/// showing: [shake] the existing toast, [ignore] the new call, or [replace] the
/// existing toast's content (and reset its dismiss timer).
enum NibToastDuplicateBehavior { shake, ignore, replace }

// Semantic accents for success/warning — `NibTheme` has no token for these, so
// they're kept constant across light/dark, the same way `destructive` is.
const Color _nibToastSuccess = Color(0xFF16A34A);
const Color _nibToastWarning = Color(0xFFF59E0B);

/// Variant → default icon + accent color.
extension NibToastVariantX on NibToastVariant {
  /// The leading icon shown when the caller doesn't override `icon`. `normal`
  /// has none (a plain toast).
  IconData? defaultIcon() => switch (this) {
    NibToastVariant.normal => null,
    NibToastVariant.success => Icons.check_circle_rounded,
    NibToastVariant.error => Icons.error_rounded,
    NibToastVariant.warning => Icons.warning_amber_rounded,
    NibToastVariant.info => Icons.info_rounded,
  };

  /// The icon/accent color for this variant, resolved against [theme].
  Color accent(NibTheme theme) => switch (this) {
    NibToastVariant.normal => theme.foreground,
    NibToastVariant.success => _nibToastSuccess,
    NibToastVariant.error => theme.destructive,
    NibToastVariant.warning => _nibToastWarning,
    NibToastVariant.info => theme.accent,
  };
}

/// Position → alignment + whether it's a top anchor.
extension NibToastPositionX on NibToastPosition {
  bool get isTop =>
      this == NibToastPosition.topLeft ||
      this == NibToastPosition.topCenter ||
      this == NibToastPosition.topRight;

  Alignment get alignment => switch (this) {
    NibToastPosition.topLeft => Alignment.topLeft,
    NibToastPosition.topCenter => Alignment.topCenter,
    NibToastPosition.topRight => Alignment.topRight,
    NibToastPosition.bottomLeft => Alignment.bottomLeft,
    NibToastPosition.bottomCenter => Alignment.bottomCenter,
    NibToastPosition.bottomRight => Alignment.bottomRight,
  };

  /// The (dx, dy) offset the toast slides in from (and out to), in logical px.
  /// **Left/right positions slide horizontally from their edge**; only the
  /// centered positions slide vertically.
  Offset get enterOffset => switch (this) {
    NibToastPosition.topLeft ||
    NibToastPosition.bottomLeft => const Offset(-40, 0),
    NibToastPosition.topRight ||
    NibToastPosition.bottomRight => const Offset(40, 0),
    NibToastPosition.topCenter => const Offset(0, -16),
    NibToastPosition.bottomCenter => const Offset(0, 16),
  };
}
