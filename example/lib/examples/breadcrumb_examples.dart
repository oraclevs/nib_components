import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 0. Interactive navigation — a live file tree. Tapping a crumb navigates
/// **back** (the trail shortens, that crumb becomes the current page); tapping a
/// child folder navigates **forward** (the trail grows). Deep paths collapse into
/// the `…` overflow menu, whose crumbs navigate too.
class BreadcrumbNavigationExample extends StatefulWidget {
  const BreadcrumbNavigationExample({super.key});

  @override
  State<BreadcrumbNavigationExample> createState() =>
      _BreadcrumbNavigationExampleState();
}

class _BreadcrumbNavigationExampleState
    extends State<BreadcrumbNavigationExample> {
  // A tiny fake folder tree: folder → its children. Missing keys are leaves.
  static const Map<String, List<String>> _tree = {
    'Home': ['Documents', 'Projects', 'Photos'],
    'Documents': ['Invoices', 'Notes'],
    'Projects': ['nib_components', 'website'],
    'nib_components': ['lib', 'test', 'example'],
    'lib': ['breadcrumb', 'button', 'slider'],
    'breadcrumb': ['nib_breadcrumb.dart', 'nib_breadcrumb_types.dart'],
  };

  List<String> _path = ['Home'];

  String get _current => _path.last;
  List<String> get _children => _tree[_current] ?? const [];

  void _navigateTo(int index) =>
      setState(() => _path = _path.sublist(0, index + 1));

  void _open(String child) => setState(() => _path = [..._path, child]);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Interactive — tap a crumb to go back, a folder to go in'),
        const SizedBox(height: 16),
        // The last item is the current page (no onTap); earlier crumbs navigate
        // back to their level.
        NibBreadcrumb(
          maxVisibleItems: 4,
          animated: true,
          items: [
            for (var i = 0; i < _path.length; i++)
              NibBreadcrumbItem(
                label: _path[i],
                icon: i == 0 ? const Icon(Icons.home_outlined) : null,
                onTap: i == _path.length - 1 ? null : () => _navigateTo(i),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          _children.isEmpty
              ? '📄 $_current  (a file — no children)'
              : '📂 Inside "$_current":',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final child in _children)
              NibButton(
                label: child,
                variant: NibButtonVariant.secondary,
                size: NibButtonSize.sm,
                leadingIcon: _tree.containsKey(child)
                    ? const Icon(Icons.folder_outlined)
                    : const Icon(Icons.insert_drive_file_outlined),
                onPressed: () => _open(child),
              ),
          ],
        ),
      ],
    );
  }
}

/// 1. Minimal — a short 3-crumb trail (last = current page).
class BreadcrumbMinimalExample extends StatelessWidget {
  const BreadcrumbMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Minimal — Home › Docs › Breadcrumb'),
        const SizedBox(height: 16),
        NibBreadcrumb(
          items: [
            NibBreadcrumbItem(label: 'Home', onTap: () {}),
            NibBreadcrumbItem(label: 'Docs', onTap: () {}),
            const NibBreadcrumbItem(label: 'Breadcrumb'),
          ],
        ),
      ],
    );
  }
}

/// 2. Long trail — collapses the middle into an overflow menu, animated
/// (staggered slide-in).
class BreadcrumbCollapseExample extends StatelessWidget {
  const BreadcrumbCollapseExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Collapse — maxVisibleItems: 4, tap … for hidden crumbs'),
        const SizedBox(height: 16),
        NibBreadcrumb(
          maxVisibleItems: 4,
          animated: true,
          items: [
            NibBreadcrumbItem(label: 'Home', onTap: () {}),
            NibBreadcrumbItem(label: 'Workspace', onTap: () {}),
            NibBreadcrumbItem(label: 'Projects', onTap: () {}),
            NibBreadcrumbItem(label: 'nib_components', onTap: () {}),
            NibBreadcrumbItem(label: 'lib', onTap: () {}),
            NibBreadcrumbItem(label: 'breadcrumb', onTap: () {}),
            const NibBreadcrumbItem(label: 'nib_breadcrumb.dart'),
          ],
        ),
      ],
    );
  }
}

/// 3. Custom separator + icons.
class BreadcrumbCustomExample extends StatelessWidget {
  const BreadcrumbCustomExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Custom — slash separator + icons'),
        const SizedBox(height: 16),
        NibBreadcrumb(
          separator: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text('/', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          items: [
            NibBreadcrumbItem(
              label: 'Home',
              icon: const Icon(Icons.home_outlined),
              onTap: () {},
            ),
            NibBreadcrumbItem(
              label: 'Library',
              icon: const Icon(Icons.folder_outlined),
              onTap: () {},
            ),
            const NibBreadcrumbItem(
              label: 'Settings',
              icon: Icon(Icons.settings_outlined),
            ),
          ],
        ),
      ],
    );
  }
}
