import 'package:flutter/widgets.dart';
import 'package:nib_motion/nib_motion.dart' show NibTransition;

import 'nib_bottom_sheet_controller.dart';
import 'show_nib_bottom_sheet.dart';

/// Declarative face of the bottom sheet, matching the house style of
/// `NibDialog` / `NibSelect`: a [trigger] whose tap opens a modal sheet, with
/// open/closed state managed internally (or via an optional [controller]). Built
/// on the same [openNibBottomSheet] primitive as [showNibBottomSheet].
///
/// Simplest usage needs only [trigger] and [content]:
///
/// ```dart
/// NibBottomSheet(
///   trigger: const Text('Open'),
///   title: 'Options',
///   content: const Text('…'),
/// )
/// ```
///
/// The [trigger] is wrapped so a tap opens the sheet — pass a non-interactive
/// widget (text, icon, a custom chip). For a fire-and-forget sheet that returns
/// a result, prefer [showNibBottomSheet] instead.
class NibBottomSheet extends StatefulWidget {
  const NibBottomSheet({
    super.key,
    this.trigger,
    this.controller,
    required this.content,
    this.title,
    this.snapPoints,
    this.initialSnap,
    this.onSnapChanged,
    this.dismissible = true,
    this.showDragHandle = true,
    this.barrierColor,
    this.animated = false,
    this.transition,
    this.onClose,
  });

  /// Tapping this opens the sheet. Optional — omit it and drive the sheet via
  /// [controller] instead.
  final Widget? trigger;

  /// Optional external open/closed + snap controller. Never required —
  /// `NibBottomSheet` creates and owns one internally when this is `null`,
  /// disposing it on unmount/controller-swap.
  final NibBottomSheetController? controller;

  final Widget content;
  final String? title;

  /// Snap heights as fractions of the available height (`0..1`, any order).
  /// Omit for a content-sized sheet with drag-to-dismiss only.
  final List<double>? snapPoints;

  /// Index into [snapPoints] to open at. Defaults to the most-open snap.
  final int? initialSnap;

  /// Called whenever the sheet settles on a different snap.
  final ValueChanged<int>? onSnapChanged;

  final bool dismissible;
  final bool showDragHandle;
  final Color? barrierColor;

  /// Opt-in enter/exit animation. `false` builds zero `NibMotion` overhead.
  final bool animated;
  final NibTransition? transition;

  /// Called when the sheet closes, however it was dismissed.
  final VoidCallback? onClose;

  @override
  State<NibBottomSheet> createState() => _NibBottomSheetState();
}

class _NibBottomSheetState extends State<NibBottomSheet> {
  late NibBottomSheetController _controller;
  late bool _ownsController;
  NibBottomSheetHandle<void>? _handle;

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
    if (_controller.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSheet();
      });
    }
  }

  @override
  void didUpdateWidget(covariant NibBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _unbindController();
      _bindController(widget.controller);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _handle?.close();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _bindController(NibBottomSheetController? external) {
    _controller = external ?? NibBottomSheetController();
    _ownsController = external == null;
    _controller.addListener(_handleControllerChanged);
  }

  void _unbindController() {
    _controller.removeListener(_handleControllerChanged);
    _handle?.close();
    _handle = null;
    if (_ownsController) _controller.dispose();
  }

  void _handleControllerChanged() {
    if (_controller.isOpen) {
      _openSheet();
      final pending = _controller.pendingSnap;
      if (pending != null) {
        _handle?.snapTo(pending);
        _controller.consumePendingSnap();
      }
    } else {
      _handle?.close();
    }
  }

  void _openSheet() {
    if (_handle != null || !mounted) return;
    _handle = openNibBottomSheet<void>(
      context,
      content: widget.content,
      title: widget.title,
      snapPoints: widget.snapPoints,
      initialSnap: widget.initialSnap,
      onSnapChanged: widget.onSnapChanged,
      dismissible: widget.dismissible,
      showDragHandle: widget.showDragHandle,
      barrierColor: widget.barrierColor,
      animated: widget.animated,
      transition: widget.transition,
      onClose: _onSheetClosed,
    );
  }

  /// Runs when the sheet closes by any means: drops the handle and syncs the
  /// controller back to closed so state stays consistent.
  void _onSheetClosed() {
    _handle = null;
    if (_controller.isOpen) _controller.close();
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trigger == null) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _controller.open,
      child: widget.trigger,
    );
  }
}
