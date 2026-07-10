import 'package:flutter/foundation.dart';

/// Optional external controller for a `NibNavigationMenu`'s open-submenu
/// state. Never required for basic use — `NibNavigationMenu` owns its own
/// controller internally when none is supplied.
///
/// [openChain] tracks horizontal cascading-flyout state (root-to-deepest
/// open item ids). [openIds] tracks vertical inline-expand state (every
/// currently-expanded item id, at any depth).
class NibNavMenuController extends ChangeNotifier {
  NibNavMenuController({List<String> openChain = const [], Set<String>? openIds})
    : _openChain = List<String>.of(openChain),
      _openIds = Set<String>.of(openIds ?? const {});

  final List<String> _openChain;
  final Set<String> _openIds;

  /// Horizontal mode: the chain of open flyout ids, root to deepest.
  List<String> get openChain => List<String>.unmodifiable(_openChain);

  /// Vertical mode: the set of currently-expanded item ids.
  Set<String> get openIds => Set<String>.unmodifiable(_openIds);

  /// Replaces the open chain with [path] (root-to-leaf ids).
  void openChainTo(List<String> path) {
    _openChain
      ..clear()
      ..addAll(path);
    notifyListeners();
  }

  /// Truncates the open chain to length [depth]. No-op if already that
  /// short or shorter.
  void closeFromDepth(int depth) {
    if (_openChain.length <= depth) return;
    _openChain.removeRange(depth, _openChain.length);
    notifyListeners();
  }

  /// Empties the open chain. No-op (does not notify) if already empty.
  void closeAll() {
    if (_openChain.isEmpty) return;
    _openChain.clear();
    notifyListeners();
  }

  /// Vertical mode: toggles [id] open/closed. If [exclusiveSiblings] is
  /// given, every id in it is closed at the same time (single-open
  /// sibling coordination).
  void toggleOpenId(String id, {Set<String>? exclusiveSiblings}) {
    final opening = !_openIds.contains(id);
    if (exclusiveSiblings != null) {
      _openIds.removeAll(exclusiveSiblings);
    }
    if (opening) {
      _openIds.add(id);
    } else {
      _openIds.remove(id);
    }
    notifyListeners();
  }
}
