import 'package:flutter/widgets.dart';
import 'package:nib_motion/nib_motion.dart' show NibTransition;

import 'nib_dialog_controller.dart';
import 'nib_dialog_types.dart';
import 'show_nib_dialog.dart';

/// Declarative face of the dialog, matching the house style of `NibSelect` /
/// `NibDatePicker`: a [trigger] whose tap opens a modal, with open/closed state
/// managed internally (or via an optional [controller]). Built on the same
/// [openNibDialog] primitive as [showNibDialog].
///
/// Simplest usage needs only [trigger] and [content]:
///
/// ```dart
/// NibDialog(
///   trigger: const Text('Open'),
///   title: 'Details',
///   content: const Text('…'),
/// )
/// ```
///
/// The [trigger] is wrapped so a tap opens the dialog — pass a non-interactive
/// widget (text, icon, a custom chip). For a fire-and-forget confirm dialog
/// that returns a result, prefer [showNibDialog] instead.
class NibDialog extends StatefulWidget {
  const NibDialog({
    super.key,
    this.trigger,
    this.controller,
    this.title,
    this.description,
    this.header,
    required this.content,
    this.footer,
    this.size = NibDialogSize.md,
    this.width,
    this.barrierDismissible = true,
    this.showCloseButton = true,
    this.barrierColor,
    this.animated = false,
    this.animation = NibDialogAnimation.fadeScale,
    this.transition,
    this.onClose,
  });

  /// Tapping this opens the dialog. Optional — omit it and drive the dialog via
  /// [controller] instead.
  final Widget? trigger;

  /// Optional external open/closed controller. Never required — `NibDialog`
  /// creates and owns one internally when this is `null`, disposing it on
  /// unmount/controller-swap.
  final NibDialogController? controller;

  final String? title;
  final String? description;

  /// Full override of the default title/description/close-button header.
  final Widget? header;

  final Widget content;
  final Widget? footer;
  final NibDialogSize size;

  /// Custom-size escape hatch (overrides [size]'s width ceiling).
  final double? width;

  final bool barrierDismissible;
  final bool showCloseButton;
  final Color? barrierColor;

  /// Opt-in enter/exit animation. `false` builds zero `NibMotion` overhead.
  final bool animated;
  final NibDialogAnimation animation;
  final NibTransition? transition;

  /// Called when the dialog closes, however it was dismissed.
  final VoidCallback? onClose;

  @override
  State<NibDialog> createState() => _NibDialogState();
}

class _NibDialogState extends State<NibDialog> {
  late NibDialogController _controller;
  late bool _ownsController;
  NibDialogHandle<void>? _handle;

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
    if (_controller.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openDialog();
      });
    }
  }

  @override
  void didUpdateWidget(covariant NibDialog oldWidget) {
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

  void _bindController(NibDialogController? external) {
    _controller = external ?? NibDialogController();
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
      _openDialog();
    } else {
      _handle?.close();
    }
  }

  void _openDialog() {
    if (_handle != null || !mounted) return;
    _handle = openNibDialog<void>(
      context,
      title: widget.title,
      description: widget.description,
      header: widget.header,
      content: widget.content,
      footer: widget.footer,
      size: widget.size,
      width: widget.width,
      barrierDismissible: widget.barrierDismissible,
      showCloseButton: widget.showCloseButton,
      barrierColor: widget.barrierColor,
      animated: widget.animated,
      animation: widget.animation,
      transition: widget.transition,
      onClose: _onDialogClosed,
    );
  }

  /// Runs when the dialog closes by any means (barrier/Escape/close-button or a
  /// programmatic `controller.close()`): drops the handle and syncs the
  /// controller back to closed so state stays consistent.
  void _onDialogClosed() {
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
