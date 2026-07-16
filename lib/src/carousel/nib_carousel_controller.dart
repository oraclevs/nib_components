part of 'nib_carousel.dart';

/// Optional external controller for a [NibCarousel]'s current page. Never
/// required for basic use — the carousel creates and owns one internally when
/// none is supplied, and disposes it on unmount/controller-swap.
///
/// Read the live page via [page] (it's a [ChangeNotifier], so you can listen),
/// and drive it with [nextPage]/[previousPage]/[animateToPage]/[jumpToPage].
class NibCarouselController extends ChangeNotifier {
  _NibCarouselState? _state;
  int _page = 0;

  /// The current logical page index (0-based, independent of loop wrapping).
  int get page => _page;

  void _attach(_NibCarouselState state) => _state = state;

  void _detach(_NibCarouselState state) {
    if (identical(_state, state)) _state = null;
  }

  /// Pushed by the carousel when the visible slide changes (drag, auto-play,
  /// wrap). Notifies listeners only on an actual change.
  void _sync(int page) {
    if (_page == page) return;
    _page = page;
    notifyListeners();
  }

  /// Advances one slide (wrapping when the carousel loops; a no-op at the last
  /// slide otherwise).
  void nextPage() => _state?._goRelative(1);

  /// Goes back one slide (wrapping when the carousel loops; a no-op at the first
  /// slide otherwise).
  void previousPage() => _state?._goRelative(-1);

  /// Animates to a specific logical page.
  void animateToPage(int page) => _state?._goToLogical(page, animate: true);

  /// Jumps to a specific logical page without animation.
  void jumpToPage(int page) => _state?._goToLogical(page, animate: false);
}
