import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// Trigger board — fire each variant at a chosen position. All calls are
/// **context-free** (the example app is wrapped in a [NibToaster]).
class ToastTriggerBoardExample extends StatefulWidget {
  const ToastTriggerBoardExample({super.key});

  @override
  State<ToastTriggerBoardExample> createState() =>
      _ToastTriggerBoardExampleState();
}

class _ToastTriggerBoardExampleState extends State<ToastTriggerBoardExample> {
  NibToastPosition _position = NibToastPosition.bottomRight;

  void _fire(NibToastVariant variant, String title, String message) {
    showNibToast(
      title: title,
      message: message,
      variant: variant,
      position: _position,
      animated: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Position'),
          const SizedBox(height: 6),
          DropdownButton<NibToastPosition>(
            value: _position,
            onChanged: (p) => setState(() => _position = p!),
            items: [
              for (final p in NibToastPosition.values)
                DropdownMenuItem(value: p, child: Text(p.name)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: () =>
                    _fire(NibToastVariant.success, 'Saved', 'Your changes are stored.'),
                child: const Text('Success'),
              ),
              FilledButton.tonal(
                onPressed: () =>
                    _fire(NibToastVariant.error, 'Failed', 'Something went wrong.'),
                child: const Text('Error'),
              ),
              OutlinedButton(
                onPressed: () => _fire(
                    NibToastVariant.warning, 'Heads up', 'Storage is almost full.'),
                child: const Text('Warning'),
              ),
              OutlinedButton(
                onPressed: () =>
                    _fire(NibToastVariant.info, 'FYI', 'A new version is available.'),
                child: const Text('Info'),
              ),
              TextButton(
                onPressed: () =>
                    _fire(NibToastVariant.normal, 'Just so you know', 'Plain toast.'),
                child: const Text('Normal'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: dismissAllNibToasts,
            icon: const Icon(Icons.clear_all),
            label: const Text('Dismiss all'),
          ),
        ],
      ),
    );
  }
}

/// De-duplication — spam a button and watch the single toast shake/ignore/replace
/// instead of stacking duplicates.
class ToastDedupExample extends StatefulWidget {
  const ToastDedupExample({super.key});

  @override
  State<ToastDedupExample> createState() => _ToastDedupExampleState();
}

class _ToastDedupExampleState extends State<ToastDedupExample> {
  NibToastDuplicateBehavior _behavior = NibToastDuplicateBehavior.shake;
  int _count = 0;

  void _save() {
    _count++;
    showNibToast(
      id: 'save',
      title: 'Saved',
      message: 'Tap #$_count',
      variant: NibToastVariant.success,
      position: NibToastPosition.topCenter,
      duration: Duration.zero,
      onDuplicateTrigger: _behavior,
      animated: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('On duplicate (same id "save")'),
          const SizedBox(height: 6),
          SegmentedButton<NibToastDuplicateBehavior>(
            segments: const [
              ButtonSegment(
                  value: NibToastDuplicateBehavior.shake, label: Text('shake')),
              ButtonSegment(
                  value: NibToastDuplicateBehavior.ignore, label: Text('ignore')),
              ButtonSegment(
                  value: NibToastDuplicateBehavior.replace, label: Text('replace')),
            ],
            selected: {_behavior},
            onSelectionChanged: (s) => setState(() => _behavior = s.first),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Text('Save (spam me)'),
          ),
          const SizedBox(height: 8),
          const Text(
            'shake: the one toast wobbles · ignore: nothing happens · '
            'replace: content updates',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Action + persistent — an "Undo" toast that stays until acted on, plus a stack
/// demo for reflow + swipe-to-dismiss.
class ToastActionExample extends StatefulWidget {
  const ToastActionExample({super.key});

  @override
  State<ToastActionExample> createState() => _ToastActionExampleState();
}

class _ToastActionExampleState extends State<ToastActionExample> {
  String _status = 'Nothing deleted yet.';

  void _delete() {
    setState(() => _status = 'Item deleted.');
    showNibToast(
      id: 'undo-delete',
      title: 'Item deleted',
      actionLabel: 'Undo',
      onAction: () => setState(() => _status = 'Delete undone.'),
      variant: NibToastVariant.normal,
      icon: Icons.delete_outline,
      position: NibToastPosition.bottomCenter,
      duration: Duration.zero, // persistent until Undo or ×
      animated: true,
    );
  }

  void _spam() {
    for (var i = 1; i <= 4; i++) {
      showNibToast(
        title: 'Notification $i',
        message: 'Swipe me away →',
        variant: NibToastVariant.info,
        position: NibToastPosition.bottomRight,
        animated: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.tonal(
            onPressed: _delete,
            child: const Text('Delete (with Undo)'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _spam,
            child: const Text('Fire 4 (stack + swipe)'),
          ),
          const SizedBox(height: 16),
          Text(_status),
        ],
      ),
    );
  }
}

/// Custom content + shaping — a fully custom `content` widget with a custom
/// `backgroundColor`, `borderRadius`, and `padding`.
class ToastCustomContentExample extends StatelessWidget {
  const ToastCustomContentExample({super.key});

  void _show() {
    showNibToast(
      position: NibToastPosition.topRight,
      duration: Duration.zero,
      animated: true,
      showCloseButton: false,
      backgroundColor: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(14),
      content: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFF6366F1),
            child: Icon(Icons.person, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ada Lovelace',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                Text('sent you a message',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => dismissNibToast('dm'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('View'),
          ),
        ],
      ),
      id: 'dm',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: _show,
        icon: const Icon(Icons.dark_mode),
        label: const Text('Show custom toast'),
      ),
    );
  }
}
