import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal — a bare checkbox and one with a label.
class CheckboxMinimalExample extends StatefulWidget {
  const CheckboxMinimalExample({super.key});

  @override
  State<CheckboxMinimalExample> createState() =>
      _CheckboxMinimalExampleState();
}

class _CheckboxMinimalExampleState extends State<CheckboxMinimalExample> {
  bool _bare = false;
  bool _labelled = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Bare — $_bare'),
        const SizedBox(height: 8),
        NibCheckbox(
          value: _bare,
          onChanged: (v) => setState(() => _bare = v!),
        ),
        const SizedBox(height: 16),
        NibCheckbox(
          value: _labelled,
          label: 'Remember me',
          onChanged: (v) => setState(() => _labelled = v!),
        ),
      ],
    );
  }
}

/// 2. Common variant — a "select all" tri-state checkbox coordinating a list
/// of item checkboxes, with descriptions and a disabled item.
class CheckboxCommonExample extends StatefulWidget {
  const CheckboxCommonExample({super.key});

  @override
  State<CheckboxCommonExample> createState() => _CheckboxCommonExampleState();
}

class _CheckboxCommonExampleState extends State<CheckboxCommonExample> {
  final Map<String, bool> _items = {
    'Widgets': true,
    'Themes': false,
    'Motion': false,
  };
  static const _disabledLabel = 'Icons (coming soon)';

  bool? get _allValue {
    final values = _items.values.toList();
    if (values.every((v) => v)) return true;
    if (values.every((v) => !v)) return false;
    return null;
  }

  void _setAll(bool? v) {
    setState(() {
      for (final key in _items.keys) {
        _items[key] = v ?? false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        NibCheckbox(
          value: _allValue,
          tristate: true,
          label: 'Select all',
          description: 'Toggles every item below',
          onChanged: _setAll,
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.only(left: 30),
          child: Divider(height: 16),
        ),
        for (final entry in _items.entries)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: NibCheckbox(
              value: entry.value,
              label: entry.key,
              onChanged: (v) => setState(() => _items[entry.key] = v!),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: NibCheckbox(
            value: false,
            label: _disabledLabel,
            disabled: true,
          ),
        ),
      ],
    );
  }
}

/// Extra — beside a Button, checking alignment against `NibButton` at both
/// sizes, bare and labelled, and a typical "agree to terms" form row.
class CheckboxBesideButtonExample extends StatefulWidget {
  const CheckboxBesideButtonExample({super.key});

  @override
  State<CheckboxBesideButtonExample> createState() =>
      _CheckboxBesideButtonExampleState();
}

class _CheckboxBesideButtonExampleState
    extends State<CheckboxBesideButtonExample> {
  bool _bare = false;
  bool _labelled = false;
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Bare checkbox beside NibButton (sm / md)'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            NibCheckbox(
              value: _bare,
              onChanged: (v) => setState(() => _bare = v!),
            ),
            const SizedBox(width: 12),
            NibButton(
              label: 'Small',
              size: NibButtonSize.sm,
              onPressed: () {},
            ),
            const SizedBox(width: 12),
            NibButton(label: 'Medium', onPressed: () {}),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Labelled checkbox beside NibButton'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            NibCheckbox(
              value: _labelled,
              label: 'Keep me signed in',
              onChanged: (v) => setState(() => _labelled = v!),
            ),
            const SizedBox(width: 12),
            NibButton(label: 'Sign in', onPressed: () {}),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Form row — checkbox + label + trailing button'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: NibCheckbox(
                value: _agreed,
                label: 'I agree to the terms and conditions',
                onChanged: (v) => setState(() => _agreed = v!),
              ),
            ),
            const SizedBox(width: 12),
            NibButton(
              label: 'Continue',
              disabled: !_agreed,
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }
}

/// 3. Advanced — animated pop, custom active colour and size.
class CheckboxAdvancedExample extends StatefulWidget {
  const CheckboxAdvancedExample({super.key});

  @override
  State<CheckboxAdvancedExample> createState() =>
      _CheckboxAdvancedExampleState();
}

class _CheckboxAdvancedExampleState extends State<CheckboxAdvancedExample> {
  bool? _value = false;

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Advanced — animated, custom colour + size, tristate'),
        const SizedBox(height: 16),
        NibCheckbox(
          value: _value,
          tristate: true,
          animated: true,
          size: 26,
          activeColor: theme.accent,
          label: 'Sync across devices',
          description: 'Tap through: off, on, mixed',
          onChanged: (v) => setState(() => _value = v),
        ),
      ],
    );
  }
}
