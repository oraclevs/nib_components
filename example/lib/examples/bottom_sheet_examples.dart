import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibTransition;

/// A non-interactive, tappable trigger for the declarative [NibBottomSheet]
/// demos — `NibBottomSheet` wraps its `trigger` in an opaque tap handler, so the
/// trigger itself must not consume the tap (as a Material button would).
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
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _action(IconData icon, String label, VoidCallback onTap) {
  return ListTile(
    leading: Icon(icon),
    title: Text(label),
    contentPadding: EdgeInsets.zero,
    onTap: onTap,
  );
}

/// 1. Minimal — the imperative `showNibBottomSheet`, content-sized, with a few
/// action rows that close it via `NibBottomSheetScope`.
class BottomSheetMinimalExample extends StatelessWidget {
  const BottomSheetMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Imperative — showNibBottomSheet() (content-sized)'),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => showNibBottomSheet<void>(
            context,
            title: 'Share',
            content: Builder(
              builder: (sctx) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _action(
                    Icons.link,
                    'Copy link',
                    () => NibBottomSheetScope.of(sctx).close(),
                  ),
                  _action(
                    Icons.mail_outline,
                    'Email',
                    () => NibBottomSheetScope.of(sctx).close(),
                  ),
                  _action(
                    Icons.download,
                    'Save to device',
                    () => NibBottomSheetScope.of(sctx).close(),
                  ),
                ],
              ),
            ),
          ),
          child: const Text('Open sheet'),
        ),
      ],
    );
  }
}

/// 2. Snap points — a tall sheet with peek/half/full snaps, opening at the
/// middle snap, reporting the settled snap, and animated.
class BottomSheetSnapPointsExample extends StatefulWidget {
  const BottomSheetSnapPointsExample({super.key});

  @override
  State<BottomSheetSnapPointsExample> createState() =>
      _BottomSheetSnapPointsExampleState();
}

class _BottomSheetSnapPointsExampleState
    extends State<BottomSheetSnapPointsExample> {
  int _snap = 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Snap points — peek / half / full (drag the handle)'),
        const SizedBox(height: 4),
        Text(
          'Last settled snap: $_snap',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => showNibBottomSheet<void>(
            context,
            title: 'Nearby places',
            snapPoints: const [0.25, 0.5, 0.9],
            initialSnap: 1,
            animated: true,
            onSnapChanged: (i) => setState(() => _snap = i),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 1; i <= 20; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.place_outlined),
                    title: Text('Place #$i'),
                    subtitle: const Text('0.4 km away'),
                  ),
              ],
            ),
          ),
          child: const Text('Open snapping sheet'),
        ),
      ],
    );
  }
}

/// 3. Declarative + advanced — a `NibBottomSheet` widget driven by a controller,
/// with a custom spring transition, a title, and a footer button that snaps the
/// sheet to full height before closing.
class BottomSheetDeclarativeAdvancedExample extends StatefulWidget {
  const BottomSheetDeclarativeAdvancedExample({super.key});

  @override
  State<BottomSheetDeclarativeAdvancedExample> createState() =>
      _BottomSheetDeclarativeAdvancedExampleState();
}

class _BottomSheetDeclarativeAdvancedExampleState
    extends State<BottomSheetDeclarativeAdvancedExample> {
  final _controller = NibBottomSheetController();

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
        const Text(
          'Declarative — NibBottomSheet(controller:, animated spring)',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            NibBottomSheet(
              controller: _controller,
              title: 'Filters',
              snapPoints: const [0.4, 0.85],
              initialSnap: 0,
              animated: true,
              transition: NibTransition.springGentle,
              trigger: const _TriggerBox('Edit filters', icon: Icons.tune),
              content: Builder(
                builder: (sctx) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Sort by',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    for (final o in ['Relevance', 'Newest', 'Price'])
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          o == 'Relevance'
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        title: Text(o),
                        onTap: () {},
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => NibBottomSheetScope.of(sctx).snapTo(1),
                      child: const Text('Expand ↑'),
                    ),
                    const SizedBox(height: 4),
                    FilledButton(
                      onPressed: () => NibBottomSheetScope.of(sctx).close(),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _controller.open,
              child: const Text('Open via controller'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 4. Non-dismissible — the barrier and Escape can't close it; only the explicit
/// Confirm/Cancel buttons do (via `NibBottomSheetScope`). Demonstrates
/// `dismissible: false`.
class BottomSheetNonDismissibleExample extends StatelessWidget {
  const BottomSheetNonDismissibleExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Non-dismissible — must choose an action'),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            final result = await showNibBottomSheet<bool>(
              context,
              title: 'Accept terms?',
              dismissible: false,
              content: Builder(
                builder: (sctx) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'You must accept before continuing. Tapping outside '
                      'or pressing Escape will not close this sheet.',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              NibBottomSheetScope.of(sctx).close(false),
                          child: const Text('Decline'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () =>
                              NibBottomSheetScope.of(sctx).close(true),
                          child: const Text('Accept'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result == true ? 'Accepted' : 'Declined')),
            );
          },
          child: const Text('Open locked sheet'),
        ),
      ],
    );
  }
}
