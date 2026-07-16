import 'package:flutter/foundation.dart';

/// Optional external controller for a `NibHoverCard`'s open/closed state. Never
/// required for basic use — `NibHoverCard` creates and owns one internally when
/// none is supplied, and disposes it on unmount/controller-swap.
///
/// Pass an explicit instance to open/close the card from elsewhere in the tree,
/// or to read whether it is currently showing. Hover/tap intent still drives it
/// automatically when present.
class NibHoverCardController extends ChangeNotifier {
  bool _isOpen = false;

  /// Whether the hover card is currently open.
  bool get isOpen => _isOpen;

  /// Opens the card. No-op (no notification) if already open.
  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  /// Closes the card. No-op (no notification) if already closed.
  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }

  /// Toggles the card open/closed.
  void toggle() => _isOpen ? close() : open();
}
