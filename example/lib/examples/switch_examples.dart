import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal — a bare switch and one with a label.
class SwitchMinimalExample extends StatefulWidget {
  const SwitchMinimalExample({super.key});

  @override
  State<SwitchMinimalExample> createState() => _SwitchMinimalExampleState();
}

class _SwitchMinimalExampleState extends State<SwitchMinimalExample> {
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
        NibSwitch(value: _bare, onChanged: (v) => setState(() => _bare = v)),
        const SizedBox(height: 16),
        NibSwitch(
          value: _labelled,
          label: 'Notifications',
          onChanged: (v) => setState(() => _labelled = v),
        ),
      ],
    );
  }
}

/// 2. Common variant — descriptions, a disabled switch, animated glide.
class SwitchCommonExample extends StatefulWidget {
  const SwitchCommonExample({super.key});

  @override
  State<SwitchCommonExample> createState() => _SwitchCommonExampleState();
}

class _SwitchCommonExampleState extends State<SwitchCommonExample> {
  bool _wifi = true;
  bool _bluetooth = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('With descriptions, animated glide, a disabled item'),
        const SizedBox(height: 16),
        NibSwitch(
          value: _wifi,
          animated: true,
          label: 'Wi-Fi',
          description: 'Connect to known networks automatically',
          onChanged: (v) => setState(() => _wifi = v),
        ),
        const SizedBox(height: 12),
        NibSwitch(
          value: _bluetooth,
          animated: true,
          label: 'Bluetooth',
          description: 'Discoverable to nearby devices',
          onChanged: (v) => setState(() => _bluetooth = v),
        ),
        const SizedBox(height: 12),
        NibSwitch(
          value: false,
          animated: true,
          label: 'Airplane mode',
          description: 'Unavailable while a call is active',
          disabled: true,
        ),
      ],
    );
  }
}

/// 3. Advanced — async-confirmed toggle (loading state), custom colour.
class SwitchAdvancedExample extends StatefulWidget {
  const SwitchAdvancedExample({super.key});

  @override
  State<SwitchAdvancedExample> createState() => _SwitchAdvancedExampleState();
}

class _SwitchAdvancedExampleState extends State<SwitchAdvancedExample> {
  bool _syncing = false;
  bool _confirming = false;

  Future<void> _toggle(bool next) async {
    setState(() => _confirming = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _confirming = false;
      _syncing = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Advanced — async-confirmed toggle (1s fake network call)'),
        const SizedBox(height: 16),
        NibSwitch(
          value: _syncing,
          loading: _confirming,
          animated: true,
          activeColor: theme.accent,
          label: 'Sync across devices',
          description: _confirming ? 'Confirming…' : null,
          onChanged: _toggle,
        ),
      ],
    );
  }
}

/// 4. Thumb customization — shape override, on/off thumb images (a real
/// light/dark theme toggle using the sun.png/moon.png example assets), and
/// a fully custom `thumbBuilder`.
class SwitchThumbCustomizationExample extends StatefulWidget {
  const SwitchThumbCustomizationExample({super.key});

  @override
  State<SwitchThumbCustomizationExample> createState() =>
      _SwitchThumbCustomizationExampleState();
}

class _SwitchThumbCustomizationExampleState
    extends State<SwitchThumbCustomizationExample> {
  bool _squareThumb = true;
  bool _isDark = false;
  bool _custom = true;

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('thumbShape — rounded-square thumb'),
        const SizedBox(height: 8),
        NibSwitch(
          value: _squareThumb,
          animated: true,
          thumbShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
          onChanged: (v) => setState(() => _squareThumb = v),
        ),
        const SizedBox(height: 24),
        const Text('onThumbIcon / offThumbIcon — light/dark theme toggle'),
        const SizedBox(height: 8),
        NibSwitch(
          value: _isDark,
          animated: true,
          label: _isDark ? 'Dark theme' : 'Light theme',
          onThumbIcon: Image.asset(
            'assets/images/moon.png',
            width: 14,
            height: 14,
          ),
          offThumbIcon: Image.asset(
            'assets/images/sun.png',
            width: 14,
            height: 14,
          ),
          onChanged: (v) => setState(() => _isDark = v),
        ),
        const SizedBox(height: 24),
        const Text('thumbBuilder — fully custom thumb content'),
        const SizedBox(height: 8),
        NibSwitch(
          value: _custom,
          animated: true,
          label: 'Custom thumb',
          onChanged: (v) => setState(() => _custom = v),
          thumbBuilder: (context, state) => DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: state.value
                    ? [theme.accent, theme.primary]
                    : [theme.mutedForeground, theme.border],
              ),
            ),
            child: Center(
              child: Text(
                state.value ? 'ON' : 'OFF',
                style: TextStyle(
                  fontSize: 6,
                  fontWeight: FontWeight.w700,
                  color: theme.primaryForeground,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Extra — beside a Button, checking alignment against `NibButton`.
class SwitchBesideButtonExample extends StatefulWidget {
  const SwitchBesideButtonExample({super.key});

  @override
  State<SwitchBesideButtonExample> createState() =>
      _SwitchBesideButtonExampleState();
}

class _SwitchBesideButtonExampleState extends State<SwitchBesideButtonExample> {
  bool _bare = false;
  bool _labelled = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Bare switch beside NibButton (sm / md)'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            NibSwitch(
              value: _bare,
              onChanged: (v) => setState(() => _bare = v),
            ),
            const SizedBox(width: 12),
            NibButton(label: 'Small', size: NibButtonSize.sm, onPressed: () {}),
            const SizedBox(width: 12),
            NibButton(label: 'Medium', onPressed: () {}),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Labelled switch beside a Button, row-aligned'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: NibSwitch(
                value: _labelled,
                label: 'Auto-renew subscription',
                onChanged: (v) => setState(() => _labelled = v),
              ),
            ),
            const SizedBox(width: 12),
            NibButton(
              label: 'Manage',
              variant: NibButtonVariant.outline,
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }
}
