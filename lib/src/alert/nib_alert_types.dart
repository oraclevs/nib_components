import 'package:flutter/material.dart';

import '../theme/nib_theme.dart';

/// Semantic severity of a [NibAlert] — drives its default icon and accent
/// color.
enum NibAlertSeverity { info, success, warning, error }

// `NibTheme` has no success/warning tokens, so these are kept constant across
// light/dark — the same call `NibToast` made for its own success/warning
// accents (see nib_toast_types.dart).
const Color _nibAlertSuccess = Color(0xFF16A34A);
const Color _nibAlertWarning = Color(0xFFF59E0B);

/// Severity → default icon + accent color.
extension NibAlertSeverityX on NibAlertSeverity {
  /// The icon shown when the caller doesn't override `icon`.
  IconData defaultIcon() => switch (this) {
    NibAlertSeverity.info => Icons.info_rounded,
    NibAlertSeverity.success => Icons.check_circle_rounded,
    NibAlertSeverity.warning => Icons.warning_amber_rounded,
    NibAlertSeverity.error => Icons.error_rounded,
  };

  /// The icon/border accent color for this severity, resolved against
  /// [theme].
  Color accent(NibTheme theme) => switch (this) {
    NibAlertSeverity.info => theme.accent,
    NibAlertSeverity.success => _nibAlertSuccess,
    NibAlertSeverity.warning => _nibAlertWarning,
    NibAlertSeverity.error => theme.destructive,
  };
}
