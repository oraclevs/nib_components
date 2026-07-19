import 'package:flutter/widgets.dart';

import 'measure_size.dart';
import 'overlay_positioning.dart';

// `NibOverlayPlacement` now lives in `overlay_positioning.dart` (shared with
// `NibPopover`); re-exported here so existing importers (e.g.
// `NibNavigationMenu`) keep resolving it from this file.
export 'overlay_positioning.dart' show NibOverlayPlacement;

/// A handle to a [NibAnchoredOverlay.show] call. Call [remove] to close it.
class NibAnchoredOverlayHandle {
  NibAnchoredOverlayHandle._(this._entry);
  final OverlayEntry _entry;
  bool _removed = false;

  /// Removes the overlay entry. Safe to call more than once.
  void remove() {
    if (_removed) return;
    _removed = true;
    _entry.remove();
  }
}

/// Generic anchored-overlay primitive: positions [contentBuilder]'s content
/// next to [targetRenderBox] via [link], flipping to the opposite side and
/// clamping to the screen bounds when the preferred [placement] doesn't
/// fit.
///
/// Shared by `NibNavigationMenu`'s flyout/cascade submenus and (per the
/// 2026-07-10 Navigation Menu design doc) intended for `Popover` to reuse
/// rather than reimplement.
class NibAnchoredOverlay {
  NibAnchoredOverlay._();

  static NibAnchoredOverlayHandle show(
    BuildContext context, {
    required LayerLink link,
    required RenderBox targetRenderBox,
    required WidgetBuilder contentBuilder,
    NibOverlayPlacement placement = NibOverlayPlacement.bottom,
    VoidCallback? onDismissed,
    bool withBarrier = true,
  }) {
    final overlayState = Overlay.of(context);
    final targetGlobalTopLeft = targetRenderBox.localToGlobal(Offset.zero);
    final targetSize = targetRenderBox.size;

    late OverlayEntry entry;
    late NibAnchoredOverlayHandle handle;
    // Routed through `handle.remove()` (idempotent via its `_removed` flag)
    // rather than `entry.remove()` directly — a caller's `onDismissed` may
    // also hold and remove the same handle (e.g. to close a whole chain of
    // nested flyouts), and the two removal paths must share one guard or
    // the second call hits Flutter's "OverlayEntry removed only once"
    // assertion.
    void dismiss() {
      handle.remove();
      onDismissed?.call();
    }

    entry = OverlayEntry(
      builder: (overlayContext) => _NibAnchoredOverlayContent(
        link: link,
        targetSize: targetSize,
        targetGlobalTopLeft: targetGlobalTopLeft,
        placement: placement,
        onDismissed: dismiss,
        withBarrier: withBarrier,
        contentBuilder: contentBuilder,
      ),
    );
    handle = NibAnchoredOverlayHandle._(entry);
    overlayState.insert(entry);
    return handle;
  }
}

class _NibAnchoredOverlayContent extends StatefulWidget {
  const _NibAnchoredOverlayContent({
    required this.link,
    required this.targetSize,
    required this.targetGlobalTopLeft,
    required this.placement,
    required this.onDismissed,
    required this.withBarrier,
    required this.contentBuilder,
  });

  final LayerLink link;
  final Size targetSize;
  final Offset targetGlobalTopLeft;
  final NibOverlayPlacement placement;
  final VoidCallback onDismissed;

  /// Whether this entry installs its own full-screen dismiss-on-outside-tap
  /// barrier. A caller chaining several `show()` calls into one cascade
  /// (each anchored to content shown by the previous call) should only set
  /// this `true` on the first/outermost call — a barrier on every level
  /// would each independently absorb any tap outside its own bounds,
  /// preventing a tap from ever reaching an already-open shallower level's
  /// own sibling content, and preventing a single outside tap from
  /// collapsing the whole cascade at once.
  final bool withBarrier;
  final WidgetBuilder contentBuilder;

  @override
  State<_NibAnchoredOverlayContent> createState() =>
      _NibAnchoredOverlayContentState();
}

class _NibAnchoredOverlayContentState
    extends State<_NibAnchoredOverlayContent> {
  Size? _contentSize;

  Rect get _targetRect => widget.targetGlobalTopLeft & widget.targetSize;

  @override
  Widget build(BuildContext context) {
    final content = MeasureSize(
      onChange: (size) {
        if (mounted && _contentSize != size) {
          setState(() => _contentSize = size);
        }
      },
      child: widget.contentBuilder(context),
    );

    // Opaque, not translucent: a tap on the barrier must not also reach
    // whatever sits beneath it in the base app (e.g. the trigger button
    // itself), which would otherwise double-fire dismiss-on-outside-tap
    // and the trigger's own re-toggle logic for the same tap.
    final barrier = widget.withBarrier
        ? Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismissed,
            ),
          )
        : null;

    if (_contentSize == null) {
      return Stack(
        children: [
          ?barrier,
          Opacity(opacity: 0, child: content),
        ],
      );
    }

    final mq = MediaQuery.of(context);
    final geo = resolveOverlayGeometry(
      placement: widget.placement,
      target: _targetRect,
      content: _contentSize!,
      screen: mq.size,
      safeInsets: nibOverlaySafeInsets(mq),
    );

    return Stack(
      children: [
        ?barrier,
        CompositedTransformFollower(
          link: widget.link,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.topLeft,
          offset: geo.offset,
          child: content,
        ),
      ],
    );
  }
}
