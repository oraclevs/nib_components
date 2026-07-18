import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal — plain content card, no chrome beyond the default.
class CardMinimalExample extends StatelessWidget {
  const CardMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 320,
      child: NibCard(
        child: Text(
          'A plain card is a static, non-interactive container — no ripple, '
          'no gesture wrapper at all.',
        ),
      ),
    );
  }
}

/// 2. Common variant — header + content + footer, interactive + animated.
class CardCommonExample extends StatefulWidget {
  const CardCommonExample({super.key});

  @override
  State<CardCommonExample> createState() => _CardCommonExampleState();
}

class _CardCommonExampleState extends State<CardCommonExample> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    return SizedBox(
      width: 320,
      child: NibCard(
        interactive: true,
        animated: true,
        onTap: () => setState(() => _taps++),
        header: Row(
          children: [
            Icon(Icons.notifications_outlined, color: theme.primary),
            const SizedBox(width: 8),
            const Text(
              'Notification settings',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        footer: Text(
          'Manage in Settings › Notifications',
          style: TextStyle(color: theme.mutedForeground, fontSize: 12),
        ),
        child: Text('Tapped $_taps time${_taps == 1 ? '' : 's'}.'),
      ),
    );
  }
}

/// 3. Advanced — custom colours/radius, disabled interactive card.
class CardAdvancedExample extends StatelessWidget {
  const CardAdvancedExample({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 320,
          child: NibCard(
            interactive: true,
            animated: true,
            onTap: () {},
            borderRadius: BorderRadius.circular(24),
            backgroundColor: theme.secondary,
            borderColor: theme.accent,
            child: const Text('Custom radius + colours'),
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(
          width: 320,
          child: NibCard(
            interactive: true,
            disabled: true,
            onTap: null,
            child: Text('Disabled interactive card — dimmed, no tap.'),
          ),
        ),
      ],
    );
  }
}

/// 4. Flip card — minimal, uncontrolled tap-to-flip.
class FlipCardMinimalExample extends StatelessWidget {
  const FlipCardMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 240,
      height: 150,
      child: NibFlipCard(
        front: Center(child: Text('Tap to flip')),
        back: Center(child: Text('This is the back!')),
      ),
    );
  }
}

/// 5. Flip card — vertical axis, custom colours, flashcard-style.
class FlipCardVerticalExample extends StatelessWidget {
  const FlipCardVerticalExample({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    return SizedBox(
      width: 240,
      height: 150,
      child: NibFlipCard(
        flipAxis: Axis.vertical,
        frontColor: theme.secondary,
        backColor: theme.primary,
        frontSemanticLabel: 'Flashcard: capital of France',
        backSemanticLabel: 'Answer: Paris',
        front: const Center(
          child: Text(
            'What is the capital of France?',
            textAlign: TextAlign.center,
          ),
        ),
        back: Center(
          child: Text(
            'Paris',
            style: TextStyle(
              color: theme.primaryForeground,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// 6. Flip card — controlled externally by a button, horizontal axis.
class FlipCardControlledExample extends StatefulWidget {
  const FlipCardControlledExample({super.key});

  @override
  State<FlipCardControlledExample> createState() =>
      _FlipCardControlledExampleState();
}

class _FlipCardControlledExampleState
    extends State<FlipCardControlledExample> {
  bool _flipped = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 240,
          height: 150,
          child: NibFlipCard(
            isFlipped: _flipped,
            tappable: false,
            front: const Center(child: Text('Front (controlled)')),
            back: const Center(child: Text('Back (controlled)')),
          ),
        ),
        const SizedBox(height: 16),
        NibButton(
          label: _flipped ? 'Show front' : 'Show back',
          onPressed: () => setState(() => _flipped = !_flipped),
        ),
      ],
    );
  }
}
