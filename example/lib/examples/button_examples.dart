import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal — the general "Try it": a primary button with a visible state
/// change on tap.
class ButtonMinimalExample extends StatefulWidget {
  const ButtonMinimalExample({super.key});

  @override
  State<ButtonMinimalExample> createState() => _ButtonMinimalExampleState();
}

class _ButtonMinimalExampleState extends State<ButtonMinimalExample> {
  int _clicks = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Minimal — primary button (tap to count)'),
        const SizedBox(height: 12),
        NibButton(
          label: _clicks == 0 ? 'Click me' : 'Clicked $_clicks times',
          onPressed: () => setState(() => _clicks++),
        ),
      ],
    );
  }
}

/// 2. Variants — the five styles side by side (all identical box geometry).
class ButtonVariantsExample extends StatelessWidget {
  const ButtonVariantsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Variants — primary / secondary / outline / ghost / destructive',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            NibButton(label: 'Primary', onPressed: () {}),
            NibButton(
              label: 'Secondary',
              variant: NibButtonVariant.secondary,
              onPressed: () {},
            ),
            NibButton(
              label: 'Outline',
              variant: NibButtonVariant.outline,
              onPressed: () {},
            ),
            NibButton(
              label: 'Ghost',
              variant: NibButtonVariant.ghost,
              onPressed: () {},
            ),
            NibButton(
              label: 'Delete',
              variant: NibButtonVariant.destructive,
              leadingIcon: const Icon(Icons.delete_outline),
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }
}

/// 3. Sizes — presets, a custom exact size, and full-width.
class ButtonSizesExample extends StatelessWidget {
  const ButtonSizesExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Sizes — sm / md / lg, a custom 200×64, and expand'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            NibButton(label: 'Small', size: NibButtonSize.sm, onPressed: () {}),
            NibButton(label: 'Medium', onPressed: () {}),
            NibButton(label: 'Large', size: NibButtonSize.lg, onPressed: () {}),
            NibButton(
              label: 'Custom 200×64',
              width: 200,
              height: 64,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 320,
          child: NibButton(label: 'Full-width', expand: true, onPressed: () {}),
        ),
      ],
    );
  }
}

/// 4. States — a real async loading toggle plus a disabled button.
class ButtonStatesExample extends StatefulWidget {
  const ButtonStatesExample({super.key});

  @override
  State<ButtonStatesExample> createState() => _ButtonStatesExampleState();
}

class _ButtonStatesExampleState extends State<ButtonStatesExample> {
  bool _loading = false;

  void _save() {
    setState(() => _loading = true);
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('States — tap "Save" to see the loader; disabled is inert'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            NibButton(
              label: 'Save',
              loading: _loading,
              loadingText: 'Saving…',
              leadingIcon: const Icon(Icons.check),
              onPressed: _save,
            ),
            const NibButton(label: 'Disabled', onPressed: null),
            NibButton(
              label: 'Disabled outline',
              variant: NibButtonVariant.outline,
              disabled: true,
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }
}

/// 5. Icons, pill & icon-only — the extra shape/slot options.
class ButtonIconsPillExample extends StatelessWidget {
  const ButtonIconsPillExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Icons, pill shape & icon-only (square)'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            NibButton(
              label: 'Continue',
              trailingIcon: const Icon(Icons.arrow_forward),
              onPressed: () {},
            ),
            NibButton(
              label: 'Pill',
              pill: true,
              variant: NibButtonVariant.secondary,
              onPressed: () {},
            ),
            NibButton(
              onPressed: () {},
              semanticLabel: 'Add',
              leadingIcon: const Icon(Icons.add),
            ),
            NibButton(
              onPressed: () {},
              semanticLabel: 'Favorite',
              variant: NibButtonVariant.outline,
              pill: true,
              leadingIcon: const Icon(Icons.favorite_border),
            ),
          ],
        ),
      ],
    );
  }
}

/// 6. Shape — custom borderRadius & padding (fully square → generous → pill).
class ButtonShapeExample extends StatelessWidget {
  const ButtonShapeExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Shape — custom borderRadius & padding'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            NibButton(
              label: 'Square',
              borderRadius: BorderRadius.zero,
              onPressed: () {},
            ),
            NibButton(
              label: 'Roomy padding',
              variant: NibButtonVariant.outline,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              onPressed: () {},
            ),
            NibButton(
              label: 'Custom 20px radius',
              variant: NibButtonVariant.secondary,
              borderRadius: BorderRadius.circular(20),
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }
}

/// 7. Animated — opt-in nib_motion tap scale-pop.
class ButtonAnimatedExample extends StatelessWidget {
  const ButtonAnimatedExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Animated — tap to feel the nib_motion scale-pop'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            NibButton(label: 'Pop', animated: true, onPressed: () {}),
            NibButton(
              label: 'Pop outline',
              variant: NibButtonVariant.outline,
              animated: true,
              onPressed: () {},
            ),
            NibButton(
              label: 'Pop destructive',
              variant: NibButtonVariant.destructive,
              animated: true,
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }
}

/// 8. Custom content — your own child, positioned however you like. The button
/// still owns tap/ripple/focus, shape, sizing, padding and the loading overlay.
class ButtonContentExample extends StatelessWidget {
  const ButtonContentExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Custom content — arbitrary widgets inside the button'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Two-line content with its own layout.
            NibButton(
              onPressed: () {},
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upgrade',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text('\$9 / month', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            // An avatar + label composition.
            NibButton(
              onPressed: () {},
              variant: NibButtonVariant.outline,
              content: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    child: Text('N', style: TextStyle(fontSize: 12)),
                  ),
                  SizedBox(width: 8),
                  Text('Signed in as Nib'),
                  SizedBox(width: 6),
                  Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
