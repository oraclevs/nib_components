import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// A non-interactive, tappable trigger for the declarative [NibDialog] demos —
/// `NibDialog` wraps its `trigger` in an opaque tap handler, so the trigger
/// itself must not consume the tap (as a Material button would).
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

const _lorem = 'Nib components are built native — real focus traps, keyboard '
    'handling, and screen-bounds-aware overlays, not a Container bolted to a '
    'GestureDetector. Everything reads its colours from NibTheme, works in '
    'light and dark, and animates only when you opt in.';

/// 1. Minimal — the imperative `showNibDialog` with a title, description, and a
/// single OK footer button that closes it.
class DialogMinimalExample extends StatelessWidget {
  const DialogMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Imperative — showNibDialog()'),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => showNibDialog<void>(
            context,
            title: 'Welcome to Nib',
            description: 'A native Flutter component library.',
            content: const Text(
              'Tap outside, press Esc, or use the × to close this dialog.',
            ),
            footer: Builder(
              builder: (dctx) => Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => NibDialogScope.of(dctx).close(),
                  child: const Text('Got it'),
                ),
              ),
            ),
          ),
          child: const Text('Open dialog'),
        ),
      ],
    );
  }
}

/// 2. Confirm — returns a `bool` result via `NibDialogScope.close`, with a
/// Cancel/Delete footer, reporting the choice in a snackbar. Animated.
class DialogConfirmExample extends StatelessWidget {
  const DialogConfirmExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Returns a result (Future<bool?>)'),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            final confirmed = await showNibDialog<bool>(
              context,
              size: NibDialogSize.sm,
              animated: true,
              title: 'Delete file?',
              description: 'This action cannot be undone.',
              content: const Text('“report.pdf” will be permanently removed.'),
              footer: Builder(
                builder: (dctx) => Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => NibDialogScope.of(dctx).close(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                      onPressed: () => NibDialogScope.of(dctx).close(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(confirmed == true ? 'Deleted' : 'Cancelled')),
            );
          },
          child: const Text('Delete file…'),
        ),
      ],
    );
  }
}

/// 3. Declarative + advanced — a `NibDialog` widget with a large size, a custom
/// header, long scrollable content, an animated entrance, and a footer.
class DialogDeclarativeAdvancedExample extends StatelessWidget {
  const DialogDeclarativeAdvancedExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Declarative — NibDialog(trigger: …)'),
        const SizedBox(height: 12),
        NibDialog(
          size: NibDialogSize.lg,
          animated: true,
          trigger: const _TriggerBox('Review terms', icon: Icons.description_outlined),
          header: Builder(
            builder: (dctx) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 10, 8),
              child: Row(
                children: [
                  const Icon(Icons.gavel_outlined),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Terms of Service',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => NibDialogScope.of(dctx).close(),
                  ),
                ],
              ),
            ),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 6; i++) ...[
                Text('$i. Section', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text(_lorem),
                const SizedBox(height: 16),
              ],
            ],
          ),
          footer: Builder(
            builder: (dctx) => Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => NibDialogScope.of(dctx).close(),
                child: const Text('I agree'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 4. Stacked — a dialog that opens a second dialog on top of itself; Escape
/// closes only the topmost.
class DialogStackedExample extends StatelessWidget {
  const DialogStackedExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Stacked dialogs (dialog-from-dialog)'),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => showNibDialog<void>(
            context,
            animated: true,
            title: 'First dialog',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Open another dialog on top of this one.'),
                const SizedBox(height: 12),
                Builder(
                  builder: (dctx) => ElevatedButton(
                    onPressed: () => showNibDialog<void>(
                      dctx,
                      animated: true,
                      size: NibDialogSize.sm,
                      title: 'Second dialog',
                      content: const Text('Press Esc — it closes just this one.'),
                    ),
                    child: const Text('Open second'),
                  ),
                ),
              ],
            ),
          ),
          child: const Text('Open stacked dialogs'),
        ),
      ],
    );
  }
}

/// 5. Fullscreen — fills the viewport (inside the safe area), sliding up.
class DialogFullscreenExample extends StatelessWidget {
  const DialogFullscreenExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Fullscreen preset (slide-up)'),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => showNibDialog<void>(
            context,
            size: NibDialogSize.fullscreen,
            animated: true,
            animation: NibDialogAnimation.slideUp,
            title: 'Fullscreen',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 12; i++) ...[
                  const Text(_lorem),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          child: const Text('Open fullscreen'),
        ),
      ],
    );
  }
}
