import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal/default usage — a flat action list, default Cmd+K/Ctrl+K
/// shortcut, no groups or icons.
class CommandPaletteMinimalExample extends StatelessWidget {
  const CommandPaletteMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return NibCommandPalette(
      actions: const [
        NibCommandAction(id: 'new-file', label: 'New File'),
        NibCommandAction(id: 'open-file', label: 'Open File'),
        NibCommandAction(id: 'save-file', label: 'Save File'),
        NibCommandAction(id: 'close-file', label: 'Close File'),
      ],
      onActionSelected: (action) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected: ${action.label}'), duration: const Duration(seconds: 1)),
        );
      },
      child: const SizedBox(
        height: 120,
        child: Center(child: Text('Press Cmd+K / Ctrl+K to open the command palette')),
      ),
    );
  }
}

/// 2. Common variant — grouped actions with icons and shortcut hints, plus
/// a visible trigger `IconButton` wired to a shared controller (works
/// without a physical keyboard).
class CommandPaletteGroupedExample extends StatefulWidget {
  const CommandPaletteGroupedExample({super.key});

  @override
  State<CommandPaletteGroupedExample> createState() => _CommandPaletteGroupedExampleState();
}

class _CommandPaletteGroupedExampleState extends State<CommandPaletteGroupedExample> {
  final _controller = NibCommandPaletteController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NibCommandPalette(
      controller: _controller,
      actions: const [
        NibCommandAction(
          id: 'new-file',
          label: 'New File',
          icon: Icon(Icons.note_add_outlined),
          shortcutLabel: '⌘N',
          group: 'File',
        ),
        NibCommandAction(
          id: 'open-file',
          label: 'Open File',
          icon: Icon(Icons.folder_open_outlined),
          shortcutLabel: '⌘O',
          group: 'File',
        ),
        NibCommandAction(
          id: 'toggle-sidebar',
          label: 'Toggle Sidebar',
          icon: Icon(Icons.view_sidebar_outlined),
          group: 'View',
        ),
        NibCommandAction(
          id: 'toggle-panel',
          label: 'Toggle Panel',
          icon: Icon(Icons.vertical_align_bottom_outlined),
          group: 'View',
        ),
      ],
      onActionSelected: (action) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected: ${action.label}'), duration: const Duration(seconds: 1)),
        );
      },
      child: SizedBox(
        height: 120,
        child: Center(
          child: OutlinedButton.icon(
            onPressed: _controller.open,
            icon: const Icon(Icons.search),
            label: const Text('Open command palette'),
          ),
        ),
      ),
    );
  }
}

/// 3. Advanced — nested sub-actions ("Change Theme" drills into
/// Light/Dark/System), a custom filter (matches from the start of the
/// label only), `showRecent: true`, and `animated: true`.
class CommandPaletteAdvancedExample extends StatelessWidget {
  const CommandPaletteAdvancedExample({super.key});

  static bool _startsWithFilter(NibCommandAction action, String query) {
    if (query.isEmpty) return true;
    return action.label.toLowerCase().startsWith(query.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return NibCommandPalette(
      animated: true,
      filter: _startsWithFilter,
      actions: [
        const NibCommandAction(id: 'new-file', label: 'New File', group: 'File'),
        const NibCommandAction(id: 'open-file', label: 'Open File', group: 'File'),
        NibCommandAction(
          id: 'change-theme',
          label: 'Change Theme',
          group: 'Preferences',
          icon: const Icon(Icons.palette_outlined),
          children: [
            NibCommandAction(
              id: 'theme-light',
              label: 'Light',
              onSelected: () => debugPrint('theme -> light'),
            ),
            NibCommandAction(
              id: 'theme-dark',
              label: 'Dark',
              onSelected: () => debugPrint('theme -> dark'),
            ),
            NibCommandAction(
              id: 'theme-system',
              label: 'System',
              onSelected: () => debugPrint('theme -> system'),
            ),
          ],
        ),
        const NibCommandAction(id: 'go-to-line', label: 'Go to Line', group: 'Navigation', disabled: true),
      ],
      onActionSelected: (action) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected: ${action.label}'), duration: const Duration(seconds: 1)),
        );
      },
      child: const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Cmd+K / Ctrl+K — try "Change Theme", then pick a recent action next time you open it',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
