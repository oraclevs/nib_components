import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibTransition;

/// A dashed target area telling the user how to summon the menu.
class _Target extends StatelessWidget {
  const _Target(this.hint);

  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 280,
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        hint,
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// 1. Minimal — right-click or long-press a target for a basic menu.
class ContextMenuMinimalExample extends StatelessWidget {
  const ContextMenuMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Right-click (desktop) or long-press (touch) the box'),
        const SizedBox(height: 12),
        NibContextMenu(
          onItemSelected: (item) => _toast(context, item.label),
          items: const [
            NibMenuItem(label: 'Copy', icon: Icon(Icons.copy)),
            NibMenuItem(label: 'Paste', icon: Icon(Icons.paste)),
            NibMenuDivider(),
            NibMenuItem(
              label: 'Delete',
              icon: Icon(Icons.delete_outline),
              destructive: true,
            ),
          ],
          child: const _Target('Copy · Paste · Delete'),
        ),
      ],
    );
  }
}

/// 2. Submenus + sections + a disabled item — the full entry vocabulary,
/// animated, with keyboard nav (↑/↓, →/Enter, ←/Esc).
class ContextMenuSubmenuExample extends StatelessWidget {
  const ContextMenuSubmenuExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Sections, a nested submenu, a disabled item — animated'),
        const SizedBox(height: 12),
        NibContextMenu(
          animated: true,
          transition: NibTransition.springSnappy,
          onItemSelected: (item) => _toast(context, item.label),
          items: const [
            NibMenuSection('Edit'),
            NibMenuItem(
              label: 'Undo',
              icon: Icon(Icons.undo),
              trailing: Text('⌘Z'),
            ),
            NibMenuItem(
              label: 'Redo',
              icon: Icon(Icons.redo),
              enabled: false,
              trailing: Text('⇧⌘Z'),
            ),
            NibMenuDivider(),
            NibMenuSection('Share'),
            NibMenuItem(
              label: 'Share to',
              icon: Icon(Icons.ios_share),
              submenu: [
                NibMenuItem(
                  label: 'Messages',
                  icon: Icon(Icons.message_outlined),
                ),
                NibMenuItem(label: 'Mail', icon: Icon(Icons.mail_outline)),
                NibMenuItem(
                  label: 'More…',
                  submenu: [
                    NibMenuItem(label: 'AirDrop'),
                    NibMenuItem(label: 'Copy link'),
                  ],
                ),
              ],
            ),
            NibMenuDivider(),
            NibMenuItem(
              label: 'Move to trash',
              icon: Icon(Icons.delete_outline),
              destructive: true,
            ),
          ],
          child: const _Target('Nested submenu · sections · disabled'),
        ),
      ],
    );
  }
}

/// 3. Imperative — open a menu at the tap point from a plain button, awaiting
/// the chosen item.
class ContextMenuImperativeExample extends StatelessWidget {
  const ContextMenuImperativeExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Imperative — showNibContextMenu() at the tap point'),
        const SizedBox(height: 12),
        GestureDetector(
          onTapDown: (d) async {
            final choice = await showNibContextMenu(
              context,
              globalPosition: d.globalPosition,
              animated: true,
              items: const [
                NibMenuItem(
                  label: 'New file',
                  icon: Icon(Icons.insert_drive_file_outlined),
                ),
                NibMenuItem(
                  label: 'New folder',
                  icon: Icon(Icons.create_new_folder_outlined),
                ),
                NibMenuDivider(),
                NibMenuItem(label: 'Refresh', icon: Icon(Icons.refresh)),
              ],
            );
            if (context.mounted && choice != null) {
              _toast(context, 'Chose: ${choice.label}');
            }
          },
          child: const _Target('Tap me to open a menu here'),
        ),
      ],
    );
  }
}
