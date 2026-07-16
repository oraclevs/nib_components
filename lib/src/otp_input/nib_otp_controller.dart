import 'package:flutter/foundation.dart';

/// Optional external controller for a `NibOtpInput`'s value. Never required for
/// basic use — the widget owns its own internally when none is supplied, and
/// disposes it on unmount/controller-swap.
///
/// Read the entered code via [value] (it's a [ChangeNotifier], so you can
/// listen), and drive it with [setValue]/[clear] — e.g. to prefill a code or to
/// reset the field after a failed verification.
class NibOtpController extends ChangeNotifier {
  String _value = '';

  /// The current entered digits (0..length of them).
  String get value => _value;

  /// Replaces the value. No-op (no notification) if unchanged. The widget
  /// still enforces its own length/digit limits when it applies this.
  void setValue(String value) {
    if (_value == value) return;
    _value = value;
    notifyListeners();
  }

  /// Clears the field.
  void clear() => setValue('');
}
