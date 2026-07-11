import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal/default usage — flat leaf items, horizontal.
class NavigationMenuMinimalExample extends StatelessWidget {
  const NavigationMenuMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return NibNavigationMenu(
      items: const [
        NibNavItem(id: 'home', label: 'Home'),
        NibNavItem(id: 'about', label: 'About'),
        NibNavItem(id: 'contact', label: 'Contact'),
      ],
      onItemSelected: (id) {},
    );
  }
}

/// 2. Common variant — cascading multi-level flyout, active-item indicator.
class NavigationMenuFlyoutExample extends StatefulWidget {
  const NavigationMenuFlyoutExample({super.key});

  @override
  State<NavigationMenuFlyoutExample> createState() =>
      _NavigationMenuFlyoutExampleState();
}

class _NavigationMenuFlyoutExampleState extends State<NavigationMenuFlyoutExample> {
  String _activeId = 'home';

  @override
  Widget build(BuildContext context) {
    return NibNavigationMenu(
      activeItemId: _activeId,
      items: const [
        NibNavItem(id: 'home', label: 'Home'),
        NibNavItem(
          id: 'products',
          label: 'Products',
          children: [
            NibNavItem(id: 'widgets', label: 'Widgets'),
            NibNavItem(
              id: 'hardware',
              label: 'Hardware',
              children: [
                NibNavItem(id: 'sensors', label: 'Sensors'),
                NibNavItem(id: 'controllers', label: 'Controllers'),
              ],
            ),
          ],
        ),
        NibNavItem(id: 'about', label: 'About'),
      ],
      onItemSelected: (id) => setState(() => _activeId = id),
    );
  }
}

/// 3. Advanced — vertical orientation, external controller, animated toggle,
/// allowMultipleOpen toggle, disabled item, badge.
class NavigationMenuAdvancedExample extends StatefulWidget {
  const NavigationMenuAdvancedExample({super.key});

  @override
  State<NavigationMenuAdvancedExample> createState() =>
      _NavigationMenuAdvancedExampleState();
}

class _NavigationMenuAdvancedExampleState
    extends State<NavigationMenuAdvancedExample> {
  final _controller = NibNavMenuController();
  bool _animated = true;
  bool _allowMultipleOpen = false;
  String? _selected;

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
        SwitchListTile(
          title: const Text('Animated'),
          value: _animated,
          onChanged: (value) => setState(() => _animated = value),
        ),
        SwitchListTile(
          title: const Text('Allow multiple open'),
          value: _allowMultipleOpen,
          onChanged: (value) => setState(() => _allowMultipleOpen = value),
        ),
        if (_selected != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Selected: $_selected'),
          ),
        NibNavigationMenu(
          orientation: NibNavMenuOrientation.vertical,
          controller: _controller,
          animated: _animated,
          allowMultipleOpen: _allowMultipleOpen,
          items: [
            const NibNavItem(
              id: 'products',
              label: 'Products',
              children: [
                NibNavItem(id: 'widgets', label: 'Widgets'),
                NibNavItem(id: 'gadgets', label: 'Gadgets', disabled: true),
              ],
            ),
            NibNavItem(
              id: 'company',
              label: 'Company',
              badge: const SizedBox(
                width: 8,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                ),
              ),
              children: const [
                NibNavItem(id: 'about', label: 'About'),
                NibNavItem(id: 'careers', label: 'Careers'),
              ],
            ),
          ],
          onItemSelected: (id) => setState(() => _selected = id),
        ),
      ],
    );
  }
}

/// 4. Overflow demo — pinned to a narrow width (deliberately narrower than
/// every item's combined natural width) so the "More" flyout always
/// triggers, regardless of the host window's actual size. Mirrors
/// `DataTableWideExample`'s deterministic-trigger convention.
class NavigationMenuOverflowExample extends StatelessWidget {
  const NavigationMenuOverflowExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 260,
      child: NibNavigationMenu(
        items: [
          NibNavItem(id: 'home', label: 'Home'),
          NibNavItem(id: 'products', label: 'Products'),
          NibNavItem(id: 'about', label: 'About Us'),
          NibNavItem(id: 'contact', label: 'Contact'),
          NibNavItem(id: 'careers', label: 'Careers'),
          NibNavItem(id: 'blog', label: 'Blog'),
        ],
      ),
    );
  }
}
