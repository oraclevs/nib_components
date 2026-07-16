import 'package:flutter/foundation.dart';

/// Optional external controller for a `NibDialog`'s open/closed state. Never
/// required for basic use — `NibDialog` creates and owns its own controller
/// internally when none is supplied, and disposes it on unmount/controller-swap.
///
/// Pass an explicit instance to open/close the dialog from elsewhere in the
/// tree (e.g. a menu item or a keyboard shortcut). For the imperative
/// [showNibDialog] entry point there is no controller — its returned
/// `Future`/`NibDialogHandle` plays that role instead.
class NibDialogController extends ChangeNotifier {
  bool _isOpen = false;

  /// Whether the dialog is currently open.
  bool get isOpen => _isOpen;

  /// Opens the dialog. No-op (no notification) if already open.
  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  /// Closes the dialog. No-op (no notification) if already closed.
  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }
}
