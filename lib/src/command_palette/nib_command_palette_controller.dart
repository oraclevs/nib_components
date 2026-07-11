import 'package:flutter/foundation.dart';

/// Optional external controller for a `NibCommandPalette`'s open/closed
/// state and recent-action history. Never required for basic use —
/// `NibCommandPalette` creates and owns its own controller internally when
/// none is supplied, and disposes it on unmount/controller-swap. Pass an
/// explicit instance to open the palette from elsewhere in the tree (e.g. a
/// trigger `IconButton`) without a physical keyboard.
class NibCommandPaletteController extends ChangeNotifier {
  bool _isOpen = false;
  final List<String> _recentActionIds = [];

  /// Whether the palette overlay is currently shown.
  bool get isOpen => _isOpen;

  /// Most-recently-used action ids, most recent first.
  List<String> get recentActionIds => List<String>.unmodifiable(_recentActionIds);

  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }

  void toggle() => _isOpen ? close() : open();

  /// Moves [id] to the front of [recentActionIds], removing any existing
  /// occurrence first, then trims to [maxRecent].
  void recordUsed(String id, int maxRecent) {
    _recentActionIds.remove(id);
    _recentActionIds.insert(0, id);
    if (_recentActionIds.length > maxRecent) {
      _recentActionIds.removeRange(maxRecent, _recentActionIds.length);
    }
    notifyListeners();
  }
}
