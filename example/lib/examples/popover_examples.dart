import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibTransition;

/// A non-interactive, tappable trigger for the [NibPopover] demos — `NibPopover`
/// wraps its `trigger` in a tap handler, so the trigger must not consume the tap.
class _TriggerBox extends StatelessWidget {
  const _TriggerBox(this.label, {this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Text(label, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// 1. Minimal — an icon trigger opening a small info panel with an arrow.
class PopoverMinimalExample extends StatelessWidget {
  const PopoverMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Minimal — tap the icon (arrow, outside-tap to dismiss)'),
        const SizedBox(height: 12),
        const NibPopover(
          showArrow: true,
          trigger: Icon(Icons.info_outline),
          content: SizedBox(
            width: 220,
            child: Text('Popovers anchor to their trigger and flip/clamp to stay '
                'on screen — the same positioning core Select and the nav menu use.'),
          ),
        ),
      ],
    );
  }
}

/// 2. Placement + animated — opens to the end (right) side with a spring, arrow on.
class PopoverPlacementExample extends StatelessWidget {
  const PopoverPlacementExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Placement — opens to the end, animated (spring), arrow'),
        const SizedBox(height: 12),
        NibPopover(
          placement: NibPopoverPlacement.end,
          showArrow: true,
          animated: true,
          transition: NibTransition.springSnappy,
          trigger: const _TriggerBox('Details', icon: Icons.chevron_right),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Shipping', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('Arrives in 2–3 business days.'),
            ],
          ),
        ),
      ],
    );
  }
}

/// 3. Advanced — controller-driven, `dismissOnOutsideTap: false` (only the
/// buttons close it via `NibPopoverScope`), animated.
class PopoverAdvancedExample extends StatefulWidget {
  const PopoverAdvancedExample({super.key});

  @override
  State<PopoverAdvancedExample> createState() => _PopoverAdvancedExampleState();
}

class _PopoverAdvancedExampleState extends State<PopoverAdvancedExample> {
  final _controller = NibPopoverController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Advanced — controller, dismissOnOutsideTap: false, animated'),
        const SizedBox(height: 12),
        NibPopover(
          controller: _controller,
          dismissOnOutsideTap: false,
          showArrow: true,
          animated: true,
          maxWidth: 260,
          trigger: const _TriggerBox('Rename…', icon: Icons.edit_outlined),
          content: Builder(
            builder: (pctx) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Rename item', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const TextField(
                  autofocus: true,
                  decoration: InputDecoration(isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => NibPopoverScope.of(pctx).close(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => NibPopoverScope.of(pctx).close(),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 4. Menu — a popover used as a lightweight action menu (top placement).
class PopoverMenuExample extends StatelessWidget {
  const PopoverMenuExample({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(BuildContext pctx, IconData icon, String label) => InkWell(
          onTap: () => NibPopoverScope.of(pctx).close(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(label)],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('As a menu — top placement, animated'),
        const SizedBox(height: 12),
        NibPopover(
          placement: NibPopoverPlacement.top,
          animated: true,
          showArrow: true,
          maxWidth: 200,
          trigger: const _TriggerBox('Actions', icon: Icons.more_horiz),
          content: Builder(
            builder: (pctx) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                item(pctx, Icons.open_in_new, 'Open'),
                item(pctx, Icons.copy, 'Duplicate'),
                item(pctx, Icons.delete_outline, 'Delete'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
