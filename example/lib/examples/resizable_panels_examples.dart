import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal/default usage — two panels, even split.
class ResizablePanelsMinimalExample extends StatelessWidget {
  const ResizablePanelsMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: NibResizablePanels(
        direction: Axis.horizontal,
        panels: [
          NibResizablePanel(child: ColoredBox(color: Colors.blue.shade50, child: const Center(child: Text('Left')))),
          NibResizablePanel(
            child: ColoredBox(color: Colors.blue.shade100, child: const Center(child: Text('Right'))),
          ),
        ],
      ),
    );
  }
}

/// 2. Common variant — a 3-panel IDE-style layout (sidebar / content /
/// inspector) with fixed initial ratios and per-panel min sizes.
class ResizablePanelsIdeLayoutExample extends StatelessWidget {
  const ResizablePanelsIdeLayoutExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: NibResizablePanels(
        direction: Axis.horizontal,
        panels: [
          NibResizablePanel(
            initialSize: 0.2,
            minSize: 0.12,
            child: ColoredBox(color: Colors.grey.shade100, child: const Center(child: Text('Sidebar'))),
          ),
          NibResizablePanel(
            initialSize: 0.6,
            minSize: 0.3,
            child: ColoredBox(color: Colors.white, child: const Center(child: Text('Editor'))),
          ),
          NibResizablePanel(
            initialSize: 0.2,
            minSize: 0.12,
            child: ColoredBox(color: Colors.grey.shade100, child: const Center(child: Text('Inspector'))),
          ),
        ],
      ),
    );
  }
}

/// 3. Advanced — nested vertical + horizontal groups, an external
/// controller with a "Reset layout" button, animated handle affordance, and
/// persisted-layout callback wired to a snackbar.
class ResizablePanelsAdvancedExample extends StatefulWidget {
  const ResizablePanelsAdvancedExample({super.key});

  @override
  State<ResizablePanelsAdvancedExample> createState() => _ResizablePanelsAdvancedExampleState();
}

class _ResizablePanelsAdvancedExampleState extends State<ResizablePanelsAdvancedExample> {
  final _controller = NibResizablePanelsController();

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
        OutlinedButton(onPressed: _controller.resetAll, child: const Text('Reset layout')),
        const SizedBox(height: 8),
        SizedBox(
          height: 360,
          child: NibResizablePanels(
            direction: Axis.vertical,
            controller: _controller,
            animated: true,
            onLayoutChanged: (sizes) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Layout changed: $sizes'), duration: const Duration(milliseconds: 800)),
              );
            },
            panels: [
              NibResizablePanel(
                initialSize: 0.65,
                child: NibResizablePanels(
                  direction: Axis.horizontal,
                  animated: true,
                  panels: [
                    NibResizablePanel(
                      child: ColoredBox(color: Colors.teal.shade50, child: const Center(child: Text('Top left'))),
                    ),
                    NibResizablePanel(
                      child: ColoredBox(color: Colors.teal.shade100, child: const Center(child: Text('Top right'))),
                    ),
                  ],
                ),
              ),
              NibResizablePanel(
                initialSize: 0.35,
                child: ColoredBox(color: Colors.teal.shade200, child: const Center(child: Text('Bottom'))),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 4. Narrow-viewport demo — a fixed narrow container deterministically
/// triggers the scrollable, handle-less fallback (mirrors Data Table's
/// `DataTableWideExample` pattern for reliably demonstrating a responsive
/// breakpoint rather than relying on the host window being narrow).
class ResizablePanelsNarrowExample extends StatelessWidget {
  const ResizablePanelsNarrowExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 240,
      child: NibResizablePanels(
        direction: Axis.horizontal,
        panels: [
          NibResizablePanel(child: ColoredBox(color: Colors.orange.shade50, child: const Center(child: Text('A')))),
          NibResizablePanel(child: ColoredBox(color: Colors.orange.shade100, child: const Center(child: Text('B')))),
          NibResizablePanel(child: ColoredBox(color: Colors.orange.shade200, child: const Center(child: Text('C')))),
        ],
      ),
    );
  }
}
