import 'package:flutter/foundation.dart';

/// Optional external controller for a `NibTabs`' selected tab. Never required for
/// basic use — the tab set creates and owns one internally when none is supplied,
/// and disposes it on unmount/controller-swap.
///
/// Read [index] (it's a [ChangeNotifier], so you can listen) and drive it with
/// [animateTo] (glides the pager + indicator) or [jumpTo] (switches instantly).
///
/// ```dart
/// final tabs = NibTabsController(initialIndex: 1);
/// // ...
/// tabs.animateTo(2); // programmatically move to the third tab
/// ```
class NibTabsController extends ChangeNotifier {
  NibTabsController({int initialIndex = 0})
    : assert(initialIndex >= 0),
      _index = initialIndex;

  int _index;

  /// The currently-selected tab index.
  int get index => _index;

  /// Whether the most recent programmatic change asked to animate. Read by
  /// `NibTabs` to decide glide-vs-jump; not typically used by apps.
  bool animateOnChange = true;

  /// Selects [index], gliding the pager and indicator to it.
  void animateTo(int index) => _set(index, animate: true);

  /// Selects [index] instantly, with no glide.
  void jumpTo(int index) => _set(index, animate: false);

  void _set(int index, {required bool animate}) {
    assert(index >= 0);
    if (index == _index) return;
    _index = index;
    animateOnChange = animate;
    notifyListeners();
  }

  /// Internal: `NibTabs` reports the index a swipe/tap settled on, so the
  /// controller stays authoritative without retriggering a drive. Apps should
  /// use [animateTo]/[jumpTo] instead.
  void syncIndex(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }
}
