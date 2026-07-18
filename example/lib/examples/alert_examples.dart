import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal — title + description, default Cancel/OK. Includes a stock
/// `showDialog` + `AlertDialog` trigger with identical content, side by
/// side, so the two can be visually compared directly.
class AlertMinimalExample extends StatefulWidget {
  const AlertMinimalExample({super.key});

  @override
  State<AlertMinimalExample> createState() => _AlertMinimalExampleState();
}

class _AlertMinimalExampleState extends State<AlertMinimalExample> {
  String _result = 'No answer yet.';

  Future<bool?> _showFlutterAlertDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NibButton(
          label: 'Sign out? (NibAlert)',
          onPressed: () async {
            final confirmed = await showNibAlertDialog(
              context,
              title: 'Sign out?',
              description: 'You can sign back in at any time.',
              cancelVariant: NibButtonVariant.ghost,
              confirmVariant: NibButtonVariant.ghost,
            );
            setState(() => _result = 'Result: $confirmed');
          },
        ),
        const SizedBox(height: 8),
        NibButton(
          label: 'Sign out? (stock Flutter AlertDialog)',
          variant: NibButtonVariant.outline,
          onPressed: () async {
            final confirmed = await _showFlutterAlertDialog();
            setState(() => _result = 'Result: $confirmed');
          },
        ),
        const SizedBox(height: 12),
        Text(_result),
      ],
    );
  }
}

/// 2. Common variant — a severity-driven destructive confirm, and a
/// single-button informational alert (cancelText: null).
class AlertCommonExample extends StatefulWidget {
  const AlertCommonExample({super.key});

  @override
  State<AlertCommonExample> createState() => _AlertCommonExampleState();
}

class _AlertCommonExampleState extends State<AlertCommonExample> {
  String _result = 'No answer yet.';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NibButton(
          label: 'Delete file',
          variant: NibButtonVariant.destructive,
          onPressed: () async {
            final confirmed = await showNibAlertDialog(
              context,
              title: 'Delete file?',
              description: 'This cannot be undone.',
              severity: NibAlertSeverity.error,
              confirmText: 'Delete',
              // Different-length labels ("Cancel" vs "Delete") on
              // content-sized buttons render at different widths — set
              // buttonWidth for a clean, equal-width matched pair.
              buttonWidth: 110,
            );
            setState(() => _result = 'Deleted: ${confirmed == true}');
          },
        ),
        const SizedBox(height: 8),
        NibButton(
          label: 'Show info alert',
          variant: NibButtonVariant.outline,
          onPressed: () => showNibAlertDialog(
            context,
            title: 'Update available',
            description: 'Version 2.0 is ready to install.',
            severity: NibAlertSeverity.info,
            cancelText: null,
          ),
        ),
        const SizedBox(height: 12),
        Text(_result),
      ],
    );
  }
}

/// 3. Advanced — [adaptive] iOS/Android styling and a fully custom [actions]
/// row.
class AlertAdvancedExample extends StatefulWidget {
  const AlertAdvancedExample({super.key});

  @override
  State<AlertAdvancedExample> createState() => _AlertAdvancedExampleState();
}

class _AlertAdvancedExampleState extends State<AlertAdvancedExample> {
  String _result = 'No answer yet.';

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NibButton(
          label: 'Custom icon/text style, centered actions',
          variant: NibButtonVariant.outline,
          onPressed: () async {
            final confirmed = await showNibAlertDialog(
              context,
              title: 'Enable notifications?',
              description: "We'll only notify you about important updates.",
              icon: const Icon(Icons.notifications_active_rounded),
              iconColor: theme.primary,
              titleTextStyle: const TextStyle(fontStyle: FontStyle.italic),
              descriptionTextStyle: TextStyle(color: theme.primary),
              actionsAlignment: MainAxisAlignment.center,
              confirmText: 'Enable',
            );
            setState(() => _result = 'Result: $confirmed');
          },
        ),
        const SizedBox(height: 8),
        NibButton(
          label: 'Matched variants, confirm on the left',
          variant: NibButtonVariant.outline,
          onPressed: () async {
            final confirmed = await showNibAlertDialog(
              context,
              title: 'Leave without saving?',
              description:
                  'Both actions share one variant/width, and '
                  'Confirm is first (left) instead of the default '
                  'Cancel-first order.',
              cancelVariant: NibButtonVariant.outline,
              confirmVariant: NibButtonVariant.outline,
              buttonWidth: 100,
              cancelFirst: false,
              confirmText: 'Leave',
            );
            setState(() => _result = 'Result: $confirmed');
          },
        ),
        const SizedBox(height: 8),
        NibButton(
          label: 'Adaptive confirm (iOS/macOS styling)',
          onPressed: () async {
            final confirmed = await showNibAlertDialog(
              context,
              title: 'Discard draft?',
              description:
                  'Renders Cupertino-style on iOS/macOS, Material '
                  'everywhere else.',
              severity: NibAlertSeverity.warning,
              adaptive: true,
            );
            setState(() => _result = 'Result: $confirmed');
          },
        ),
        const SizedBox(height: 8),
        NibButton(
          label: 'Custom actions row',
          variant: NibButtonVariant.outline,
          onPressed: () async {
            // `actions` fully replaces the default Cancel/OK row with
            // arbitrary widgets — still resolves the same Future<bool?> via
            // NibDialogScope.close(). For a non-bool result, use
            // showNibDialog<T> directly instead of this convenience wrapper.
            final confirmed = await showNibAlertDialog(
              context,
              title: 'Replace existing file?',
              description: 'A file with this name already exists.',
              actions: [
                Builder(
                  builder: (ctx) => NibButton(
                    label: 'Keep both',
                    variant: NibButtonVariant.ghost,
                    onPressed: () => NibDialogScope.of(ctx).close(false),
                  ),
                ),
                Builder(
                  builder: (ctx) => NibButton(
                    label: 'Replace',
                    variant: NibButtonVariant.destructive,
                    onPressed: () => NibDialogScope.of(ctx).close(true),
                  ),
                ),
              ],
            );
            setState(() => _result = 'Replaced: ${confirmed == true}');
          },
        ),
        const SizedBox(height: 12),
        Text(_result),
      ],
    );
  }
}
