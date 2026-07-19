import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal — single-select, deselectable.
class ToggleGroupMinimalExample extends StatefulWidget {
  const ToggleGroupMinimalExample({super.key});

  @override
  State<ToggleGroupMinimalExample> createState() =>
      _ToggleGroupMinimalExampleState();
}

class _ToggleGroupMinimalExampleState extends State<ToggleGroupMinimalExample> {
  String? _align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Selected: ${_align ?? 'none — tap the active one to clear'}'),
        const SizedBox(height: 16),
        NibToggleGroup<String>(
          options: const [
            NibToggleOption(
              value: 'left',
              icon: Icon(Icons.format_align_left),
              semanticLabel: 'Align left',
            ),
            NibToggleOption(
              value: 'center',
              icon: Icon(Icons.format_align_center),
              semanticLabel: 'Align center',
            ),
            NibToggleOption(
              value: 'right',
              icon: Icon(Icons.format_align_right),
              semanticLabel: 'Align right',
            ),
          ],
          value: _align,
          onChanged: (v) => setState(() => _align = v),
        ),
      ],
    );
  }
}

/// 2. Common variant — multi-select toolbar with labels, a disabled option,
/// animated pop.
class ToggleGroupCommonExample extends StatefulWidget {
  const ToggleGroupCommonExample({super.key});

  @override
  State<ToggleGroupCommonExample> createState() =>
      _ToggleGroupCommonExampleState();
}

class _ToggleGroupCommonExampleState extends State<ToggleGroupCommonExample> {
  Set<String> _styles = {'bold'};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Active: ${_styles.isEmpty ? 'none' : _styles.join(', ')}'),
        const SizedBox(height: 16),
        NibToggleGroup<String>.multiple(
          options: const [
            NibToggleOption(value: 'bold', label: 'Bold'),
            NibToggleOption(value: 'italic', label: 'Italic'),
            NibToggleOption(value: 'underline', label: 'Underline'),
            NibToggleOption(
              value: 'strike',
              label: 'Strikethrough',
              disabled: true,
            ),
          ],
          values: _styles,
          animated: true,
          onChanged: (v) => setState(() => _styles = v),
        ),
      ],
    );
  }
}

/// 3. Advanced — vertical direction, large size, fixed item width, custom
/// active colour.
class ToggleGroupAdvancedExample extends StatefulWidget {
  const ToggleGroupAdvancedExample({super.key});

  @override
  State<ToggleGroupAdvancedExample> createState() =>
      _ToggleGroupAdvancedExampleState();
}

class _ToggleGroupAdvancedExampleState
    extends State<ToggleGroupAdvancedExample> {
  String? _view = 'list';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Advanced — vertical, lg size, fixed width, animated'),
        const SizedBox(height: 16),
        NibToggleGroup<String>(
          options: const [
            NibToggleOption(
              value: 'list',
              icon: Icon(Icons.view_list),
              label: 'List',
            ),
            NibToggleOption(
              value: 'grid',
              icon: Icon(Icons.grid_view),
              label: 'Grid',
            ),
            NibToggleOption(
              value: 'board',
              icon: Icon(Icons.view_kanban),
              label: 'Board',
            ),
          ],
          value: _view,
          direction: Axis.vertical,
          size: NibButtonSize.lg,
          itemWidth: 180,
          animated: true,
          onChanged: (v) => setState(() => _view = v),
        ),
      ],
    );
  }
}
