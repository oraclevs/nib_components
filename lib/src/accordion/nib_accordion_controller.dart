import 'package:flutter/foundation.dart';

/// Optional external controller for a `NibAccordion`'s expanded sections. Never
/// required for basic use — the accordion creates and owns one internally when
/// none is supplied, and disposes it on unmount/controller-swap.
///
/// It also encapsulates the **single-open coordination** that `ExpansionTile`
/// lacks: with [allowMultiple] `false` (the default), opening one section closes
/// the rest. Read [openIndices] (it's a [ChangeNotifier], so you can listen) and
/// drive it with [open]/[close]/[toggle]/[openAll]/[closeAll].
class NibAccordionController extends ChangeNotifier {
  NibAccordionController({Set<int>? initialOpen, this.allowMultiple = false})
      : _open = {...?initialOpen} {
    if (!allowMultiple && _open.length > 1) {
      final first = _open.first;
      _open
        ..clear()
        ..add(first);
    }
  }

  Set<int> _open;

  /// Whether more than one section may be open at once. Kept in sync with the
  /// widget's `allowMultipleOpen`.
  bool allowMultiple;

  /// The currently-open section indices (unmodifiable snapshot).
  Set<int> get openIndices => Set.unmodifiable(_open);

  /// Whether section [index] is open.
  bool isOpen(int index) => _open.contains(index);

  /// Opens [index]. In single-open mode this closes every other section.
  void open(int index) {
    if (isOpen(index) && (allowMultiple || _open.length == 1)) return;
    if (allowMultiple) {
      _open.add(index);
    } else {
      _open = {index};
    }
    notifyListeners();
  }

  /// Closes [index]. No-op if it's already closed.
  void close(int index) {
    if (_open.remove(index)) notifyListeners();
  }

  /// Toggles [index] open/closed (honouring single-open coordination).
  void toggle(int index) => isOpen(index) ? close(index) : open(index);

  /// Opens every section `0..count-1`. Ignored in single-open mode.
  void openAll(int count) {
    if (!allowMultiple) return;
    _open = {for (var i = 0; i < count; i++) i};
    notifyListeners();
  }

  /// Closes every section.
  void closeAll() {
    if (_open.isEmpty) return;
    _open = {};
    notifyListeners();
  }
}
