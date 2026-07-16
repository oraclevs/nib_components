import 'package:flutter/foundation.dart';

/// Optional external controller for a `NibPopover`'s open/closed state. Never
/// required for basic use — `NibPopover` creates and owns one internally when
/// none is supplied, and disposes it on unmount/controller-swap.
///
/// Pass an explicit instance to open/close the popover from elsewhere in the
/// tree (a menu item, a keyboard shortcut), or when `dismissOnOutsideTap` is
/// `false` and the only way to close is programmatic.
class NibPopoverController extends ChangeNotifier {
  bool _isOpen = false;

  /// Whether the popover is currently open.
  bool get isOpen => _isOpen;

  /// Opens the popover. No-op (no notification) if already open.
  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  /// Closes the popover. No-op (no notification) if already closed.
  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }

  /// Toggles the popover open/closed.
  void toggle() => _isOpen ? close() : open();
}
