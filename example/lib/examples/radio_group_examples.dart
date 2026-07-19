import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal — three plain options, vertical.
class RadioGroupMinimalExample extends StatefulWidget {
  const RadioGroupMinimalExample({super.key});

  @override
  State<RadioGroupMinimalExample> createState() =>
      _RadioGroupMinimalExampleState();
}

class _RadioGroupMinimalExampleState extends State<RadioGroupMinimalExample> {
  String? _plan = 'free';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Minimal — selected: ${_plan ?? 'none'}'),
        const SizedBox(height: 16),
        NibRadioGroup<String>(
          options: const [
            NibRadioOption(value: 'free', label: 'Free'),
            NibRadioOption(value: 'pro', label: 'Pro'),
            NibRadioOption(value: 'team', label: 'Team'),
          ],
          value: _plan,
          onChanged: (v) => setState(() => _plan = v),
        ),
      ],
    );
  }
}

/// 2. Common variant — descriptions, a disabled option, horizontal layout.
class RadioGroupCommonExample extends StatefulWidget {
  const RadioGroupCommonExample({super.key});

  @override
  State<RadioGroupCommonExample> createState() =>
      _RadioGroupCommonExampleState();
}

class _RadioGroupCommonExampleState extends State<RadioGroupCommonExample> {
  String _shipping = 'standard';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('With descriptions + a disabled option'),
        const SizedBox(height: 16),
        NibRadioGroup<String>(
          options: const [
            NibRadioOption(
              value: 'standard',
              label: 'Standard',
              description: 'Arrives in 5–7 business days',
            ),
            NibRadioOption(
              value: 'express',
              label: 'Express',
              description: 'Arrives in 1–2 business days',
            ),
            NibRadioOption(
              value: 'overnight',
              label: 'Overnight',
              description: 'Currently unavailable in your region',
              disabled: true,
            ),
          ],
          value: _shipping,
          onChanged: (v) => setState(() => _shipping = v),
        ),
        const SizedBox(height: 24),
        const Text('Horizontal — wraps at narrow widths'),
        const SizedBox(height: 16),
        NibRadioGroup<String>(
          direction: Axis.horizontal,
          options: const [
            NibRadioOption(value: 'sm', label: 'Small'),
            NibRadioOption(value: 'md', label: 'Medium'),
            NibRadioOption(value: 'lg', label: 'Large'),
          ],
          value: 'md',
          onChanged: (_) {},
        ),
      ],
    );
  }
}

/// 3. Advanced — animated dot pop, custom active colour, fully custom
/// option builder (card-style rows).
class RadioGroupAdvancedExample extends StatefulWidget {
  const RadioGroupAdvancedExample({super.key});

  @override
  State<RadioGroupAdvancedExample> createState() =>
      _RadioGroupAdvancedExampleState();
}

class _RadioGroupAdvancedExampleState extends State<RadioGroupAdvancedExample> {
  String _tier = 'pro';

  static const _tiers = [
    NibRadioOption(value: 'free', label: 'Free', description: '\$0/mo'),
    NibRadioOption(value: 'pro', label: 'Pro', description: '\$12/mo'),
    NibRadioOption(value: 'team', label: 'Team', description: '\$29/mo'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Advanced — animated, custom colour, card rows'),
        const SizedBox(height: 16),
        NibRadioGroup<String>(
          options: _tiers,
          value: _tier,
          animated: true,
          activeColor: theme.accent,
          onChanged: (v) => setState(() => _tier = v),
          optionBuilder: (context, option, selected, disabled) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(theme.radiusDefault),
                border: Border.all(
                  color: selected ? theme.accent : theme.border,
                  width: selected ? 2 : 1,
                ),
                color: selected ? theme.secondary : theme.card,
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? theme.accent : theme.mutedForeground,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(option.label, style: TextStyle(color: theme.foreground)),
                  const Spacer(),
                  Text(
                    option.description ?? '',
                    style: TextStyle(color: theme.mutedForeground),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
