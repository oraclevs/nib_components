import 'package:flutter/foundation.dart';

/// Optional external controller for a `NibBottomSheet`'s open/closed state and
/// programmatic snapping. Never required for basic use — `NibBottomSheet`
/// creates and owns its own controller internally when none is supplied, and
/// disposes it on unmount/controller-swap.
///
/// Pass an explicit instance to open/close the sheet from elsewhere in the tree
/// (a menu item, a keyboard shortcut) or to move an open sheet between its snap
/// points. For the imperative `showNibBottomSheet` entry point there is no
/// controller — its returned `Future`/`NibBottomSheetHandle` plays that role.
class NibBottomSheetController extends ChangeNotifier {
  bool _isOpen = false;

  /// Whether the sheet is currently open.
  bool get isOpen => _isOpen;

  int? _pendingSnap;

  /// The snap index the open sheet has been asked to move to but hasn't yet
  /// consumed. Read once by the surface, then cleared via [consumePendingSnap].
  int? get pendingSnap => _pendingSnap;

  /// Opens the sheet. No-op (no notification) if already open.
  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  /// Closes the sheet. No-op (no notification) if already closed.
  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    _pendingSnap = null;
    notifyListeners();
  }

  /// Requests that an open sheet animate to snap [index]. Ignored (but retained)
  /// until the sheet is open and reads it. Always notifies so an already-open
  /// sheet reacts immediately.
  void snapTo(int index) {
    _pendingSnap = index;
    notifyListeners();
  }

  /// Called by the surface once it has acted on [pendingSnap], so the same
  /// request doesn't re-fire on unrelated rebuilds.
  void consumePendingSnap() {
    _pendingSnap = null;
  }
}
