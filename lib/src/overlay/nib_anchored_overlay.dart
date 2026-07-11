import 'package:flutter/widgets.dart';

import 'measure_size.dart';

/// Which side of the trigger a [NibAnchoredOverlay]'s content prefers to
/// open toward. Flips to the opposite side automatically if it doesn't fit
/// in the viewport.
enum NibOverlayPlacement {
  /// Below the trigger, left-aligned. Flips to [top] if it doesn't fit.
  bottom,

  /// Above the trigger, left-aligned. Flips to [bottom] if it doesn't fit.
  top,

  /// To the right of the trigger, top-aligned. Flips to [start] if it
  /// doesn't fit.
  end,

  /// To the left of the trigger, top-aligned. Flips to [end] if it doesn't
  /// fit.
  start,
}

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
        contentBuilder: contentBuilder,
      ),
    );
    handle = NibAnchoredOverlayHandle._(entry);
    overlayState.insert(entry);
    return handle;
  }
}

class _Anchors {
  const _Anchors(this.target, this.follower);
  final Alignment target;
  final Alignment follower;
}

enum _ResolvedSide { bottom, top, end, start }

class _NibAnchoredOverlayContent extends StatefulWidget {
  const _NibAnchoredOverlayContent({
    required this.link,
    required this.targetSize,
    required this.targetGlobalTopLeft,
    required this.placement,
    required this.onDismissed,
    required this.contentBuilder,
  });

  final LayerLink link;
  final Size targetSize;
  final Offset targetGlobalTopLeft;
  final NibOverlayPlacement placement;
  final VoidCallback onDismissed;
  final WidgetBuilder contentBuilder;

  @override
  State<_NibAnchoredOverlayContent> createState() => _NibAnchoredOverlayContentState();
}

class _NibAnchoredOverlayContentState extends State<_NibAnchoredOverlayContent> {
  Size? _contentSize;

  _ResolvedSide _resolveSide(Size contentSize, Size screen) {
    switch (widget.placement) {
      case NibOverlayPlacement.bottom:
        final fits =
            widget.targetGlobalTopLeft.dy + widget.targetSize.height + contentSize.height <=
            screen.height;
        return fits ? _ResolvedSide.bottom : _ResolvedSide.top;
      case NibOverlayPlacement.top:
        final fits = widget.targetGlobalTopLeft.dy - contentSize.height >= 0;
        return fits ? _ResolvedSide.top : _ResolvedSide.bottom;
      case NibOverlayPlacement.end:
        final fits =
            widget.targetGlobalTopLeft.dx + widget.targetSize.width + contentSize.width <=
            screen.width;
        return fits ? _ResolvedSide.end : _ResolvedSide.start;
      case NibOverlayPlacement.start:
        final fits = widget.targetGlobalTopLeft.dx - contentSize.width >= 0;
        return fits ? _ResolvedSide.start : _ResolvedSide.end;
    }
  }

  _Anchors _anchorsFor(_ResolvedSide side) {
    switch (side) {
      case _ResolvedSide.bottom:
        return const _Anchors(Alignment.bottomLeft, Alignment.topLeft);
      case _ResolvedSide.top:
        return const _Anchors(Alignment.topLeft, Alignment.bottomLeft);
      case _ResolvedSide.end:
        return const _Anchors(Alignment.topRight, Alignment.topLeft);
      case _ResolvedSide.start:
        return const _Anchors(Alignment.topLeft, Alignment.topRight);
    }
  }

  Offset _clampOffsetFor(_ResolvedSide side, Size contentSize, Size screen) {
    switch (side) {
      case _ResolvedSide.bottom:
      case _ResolvedSide.top:
        final overflow = (widget.targetGlobalTopLeft.dx + contentSize.width) - screen.width;
        if (overflow <= 0) return Offset.zero;
        final dx = -overflow;
        final clamped = widget.targetGlobalTopLeft.dx + dx < 0 ? -widget.targetGlobalTopLeft.dx : dx;
        return Offset(clamped, 0);
      case _ResolvedSide.end:
      case _ResolvedSide.start:
        final overflow = (widget.targetGlobalTopLeft.dy + contentSize.height) - screen.height;
        if (overflow <= 0) return Offset.zero;
        final dy = -overflow;
        final clamped = widget.targetGlobalTopLeft.dy + dy < 0 ? -widget.targetGlobalTopLeft.dy : dy;
        return Offset(0, clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = MeasureSize(
      onChange: (size) {
        if (mounted && _contentSize != size) setState(() => _contentSize = size);
      },
      child: widget.contentBuilder(context),
    );

    // Opaque, not translucent: a tap on the barrier must not also reach
    // whatever sits beneath it in the base app (e.g. the trigger button
    // itself), which would otherwise double-fire dismiss-on-outside-tap
    // and the trigger's own re-toggle logic for the same tap.
    final barrier = Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDismissed,
      ),
    );

    if (_contentSize == null) {
      return Stack(children: [barrier, Opacity(opacity: 0, child: content)]);
    }

    final screen = MediaQuery.sizeOf(context);
    final side = _resolveSide(_contentSize!, screen);
    final anchors = _anchorsFor(side);
    final clampOffset = _clampOffsetFor(side, _contentSize!, screen);

    return Stack(
      children: [
        barrier,
        CompositedTransformFollower(
          link: widget.link,
          targetAnchor: anchors.target,
          followerAnchor: anchors.follower,
          offset: clampOffset,
          child: content,
        ),
      ],
    );
  }
}
