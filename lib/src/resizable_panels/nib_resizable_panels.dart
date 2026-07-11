import 'package:flutter/widgets.dart';
import 'package:nib_motion/nib_motion.dart' show NibTransition;

import 'nib_resizable_panel.dart';
import 'nib_resizable_panels_controller.dart';
import 'nib_resizable_panels_handle.dart';
import 'render_resizable_panels.dart';

/// Below `panels.length * kNibResizablePanelsNarrowFallbackPanelExtent`
/// logical pixels along the main axis, `NibResizablePanels` renders a
/// scrollable, handle-less stack of full-size panels instead of squishing
/// them below a usable size (master prompt §1.7).
///
/// The fallback always stacks **vertically** and scrolls vertically,
/// regardless of `direction` — for a `vertical` group this is the same axis
/// it already uses (it just gains scrolling instead of squishing); for a
/// `horizontal` group this is a deliberate axis pivot, collapsing
/// side-by-side panels into a single scrollable column (the locked
/// brainstorming decision — see the design doc's "Narrow-viewport fallback"
/// section — not merely making the horizontal row scroll sideways).
const double kNibResizablePanelsNarrowFallbackPanelExtent = 160.0;

/// A horizontal or vertical group of resizable panels with draggable,
/// keyboard-resizable, min/max-constrained dividers between them.
///
/// ```dart
/// NibResizablePanels(
///   direction: Axis.horizontal,
///   panels: [
///     NibResizablePanel(child: Sidebar()),
///     NibResizablePanel(child: MainContent()),
///   ],
/// )
/// ```
///
/// Must be given bounded constraints in both axes (e.g. wrap it in a
/// `SizedBox` or `Expanded` within a bounded parent).
class NibResizablePanels extends StatefulWidget {
  const NibResizablePanels({
    super.key,
    required this.direction,
    required this.panels,
    this.controller,
    this.onLayoutChanged,
    this.handleThickness = 1.0,
    this.animated = false,
    this.transition,
  }) : assert(panels.length >= 2, 'NibResizablePanels requires at least 2 panels.');

  /// Whether panels are arranged left-to-right ([Axis.horizontal]) or
  /// top-to-bottom ([Axis.vertical]).
  final Axis direction;

  /// The panels in this group, in order. Must have at least 2 entries.
  final List<NibResizablePanel> panels;

  /// Optional external controller for reading/driving panel sizes
  /// programmatically. Never required for basic use — a controller is
  /// created and owned internally when this is `null`.
  final NibResizablePanelsController? controller;

  /// Called with the full sizes list whenever a drag, keyboard nudge, or
  /// double-tap reset finishes changing the layout (not on every frame of a
  /// drag) — the host app's hook for persisting the layout.
  final ValueChanged<List<double>>? onLayoutChanged;

  /// The visual thickness of each divider line, in logical pixels.
  final double handleThickness;

  /// Whether a handle's hover/active color change animates via `NibMotion`.
  final bool animated;

  /// The transition used for the animated hover/active color change, when
  /// [animated] is `true`. `null` falls back to a short default fade.
  final NibTransition? transition;

  @override
  State<NibResizablePanels> createState() => _NibResizablePanelsState();
}

class _NibResizablePanelsState extends State<NibResizablePanels> {
  late NibResizablePanelsController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant NibResizablePanels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _unbindController();
      _bindController(widget.controller);
    } else {
      _controller.attach(widget.panels);
    }
  }

  @override
  void dispose() {
    _unbindController();
    super.dispose();
  }

  void _bindController(NibResizablePanelsController? external) {
    _controller = external ?? NibResizablePanelsController();
    _ownsController = external == null;
    _controller.attach(widget.panels);
    _controller.addListener(_handleControllerChanged);
  }

  void _unbindController() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
  }

  void _handleControllerChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final sizes = _controller.sizes;
    return LayoutBuilder(
      builder: (context, constraints) {
        final groupMainExtent = widget.direction == Axis.horizontal ? constraints.maxWidth : constraints.maxHeight;
        final narrowThreshold = widget.panels.length * kNibResizablePanelsNarrowFallbackPanelExtent;

        if (groupMainExtent < narrowThreshold) {
          // Always a vertical stack + vertical scroll, regardless of
          // `direction` — a horizontal group pivots from side-by-side to
          // stacked; a vertical group was already stacked and just gains
          // scrolling. See the constant's doc comment above.
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [for (final panel in widget.panels) panel.child],
            ),
          );
        }

        final children = <Widget>[];
        for (var i = 0; i < widget.panels.length; i++) {
          children.add(widget.panels[i].child);
          if (i < widget.panels.length - 1) {
            final handleIndex = i;
            children.add(
              NibResizablePanelsHandle(
                key: ValueKey('nib-resizable-handle-$handleIndex'),
                direction: widget.direction,
                groupMainExtent: groupMainExtent,
                handleThickness: widget.handleThickness,
                sizeFraction: sizes[handleIndex],
                animated: widget.animated,
                transition: widget.transition,
                onDeltaFraction: (delta) => _controller.applyDelta(widget.panels, handleIndex, delta),
                onDragEnd: () => widget.onLayoutChanged?.call(_controller.sizes),
                onReset: () {
                  _controller.resetPanelPair(handleIndex);
                  widget.onLayoutChanged?.call(_controller.sizes);
                },
              ),
            );
          }
        }

        return NibResizablePanelsLayout(direction: widget.direction, sizes: sizes, children: children);
      },
    );
  }
}
