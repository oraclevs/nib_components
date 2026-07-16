import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibTransition;

/// A non-interactive, hoverable/tappable inline trigger for the hover-card demos.
class _LinkTrigger extends StatelessWidget {
  const _LinkTrigger(this.label, {this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Text(label, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// A small profile card used as several demos' content.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.handle,
    required this.name,
    required this.bio,
  });

  final String handle;
  final String name;
  final String bio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 260,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.primary,
                child: Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(handle, style: TextStyle(color: scheme.outline)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(bio),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('268', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
              const SizedBox(width: 4),
              Text('Following', style: TextStyle(color: scheme.outline)),
              const SizedBox(width: 16),
              Text('12.4k', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
              const SizedBox(width: 4),
              Text('Followers', style: TextStyle(color: scheme.outline)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 1. Minimal — hover the handle to reveal a definition. Only trigger + content.
class HoverCardMinimalExample extends StatelessWidget {
  const HoverCardMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Minimal — hover the chip (700ms), or tap on touch'),
        const SizedBox(height: 12),
        const NibHoverCard(
          trigger: _LinkTrigger('@flutter', icon: Icons.alternate_email),
          content: SizedBox(
            width: 240,
            child: Text('The official Flutter account — open-source UI toolkit for '
                'building natively compiled apps from a single codebase.'),
          ),
        ),
      ],
    );
  }
}

/// 2. Common — a profile preview card with tuned delays, opening upward.
class HoverCardProfileExample extends StatelessWidget {
  const HoverCardProfileExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Profile — snappy 250ms open, top placement, animated'),
        const SizedBox(height: 12),
        const NibHoverCard(
          placement: NibHoverCardPlacement.top,
          showDelay: Duration(milliseconds: 250),
          animated: true,
          maxWidth: 300,
          trigger: _LinkTrigger('Ada Lovelace', icon: Icons.person_outline),
          content: _ProfileCard(
            handle: '@ada',
            name: 'Ada Lovelace',
            bio: 'Wrote the first algorithm. Occasionally tweets about analytical engines.',
          ),
        ),
      ],
    );
  }
}

/// 3. Advanced — hover-only (openOnTap: false), end placement, spring animation,
/// keeps a live counter inside proving descendant state survives.
class HoverCardAdvancedExample extends StatefulWidget {
  const HoverCardAdvancedExample({super.key});

  @override
  State<HoverCardAdvancedExample> createState() => _HoverCardAdvancedExampleState();
}

class _HoverCardAdvancedExampleState extends State<HoverCardAdvancedExample> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Advanced — hover-only, end placement, spring; the button '
            'inside keeps its own state (move onto the card to click it)'),
        const SizedBox(height: 12),
        NibHoverCard(
          placement: NibHoverCardPlacement.end,
          openOnTap: false,
          animated: true,
          transition: NibTransition.springSnappy,
          showDelay: const Duration(milliseconds: 200),
          hideDelay: const Duration(milliseconds: 500),
          trigger: const _LinkTrigger('Preview', icon: Icons.visibility_outlined),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Interactive content',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const SizedBox(
                width: 220,
                child: Text('A hover card is non-modal and keeps focus on the '
                    'trigger — descendants stay fully interactive.'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => setState(() => _count++),
                child: Text('Liked $_count times'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 4. Tap fallback — a plain tap-to-toggle demo (what touch users get).
class HoverCardTapFallbackExample extends StatelessWidget {
  const HoverCardTapFallbackExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Touch fallback — tap to open, tap outside to dismiss'),
        const SizedBox(height: 12),
        const NibHoverCard(
          trigger: _LinkTrigger('What is this?', icon: Icons.help_outline),
          content: SizedBox(
            width: 240,
            child: Text('On a device without a pointer, hover intent is replaced '
                'by tap-to-toggle so the card is still reachable.'),
          ),
        ),
      ],
    );
  }
}
