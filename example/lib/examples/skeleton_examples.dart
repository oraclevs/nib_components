import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal — plain Text lines, toggled by a button.
class SkeletonMinimalExample extends StatefulWidget {
  const SkeletonMinimalExample({super.key});

  @override
  State<SkeletonMinimalExample> createState() => _SkeletonMinimalExampleState();
}

class _SkeletonMinimalExampleState extends State<SkeletonMinimalExample> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        NibSkeleton(
          loading: _loading,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nib Components',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text('A native, installable Flutter UI component library.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => setState(() => _loading = !_loading),
          child: Text(_loading ? 'Finish loading' : 'Start loading'),
        ),
      ],
    );
  }
}

/// A custom composite widget — auto-expanded by NibSkeleton's detector via
/// its own build(), with no configuration required.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CircleAvatar(radius: 28, child: Icon(Icons.person)),
        const SizedBox(width: 12),
        const Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ada Lovelace',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text('@ada'),
              SizedBox(height: 4),
              Text('Mathematician and writer, first computer programmer.'),
            ],
          ),
        ),
      ],
    );
  }
}

/// 2. Common variant — a social-profile card (avatar + name + username +
/// bio), auto-shaded without hand-building a second skeleton tree.
class SkeletonCommonExample extends StatefulWidget {
  const SkeletonCommonExample({super.key});

  @override
  State<SkeletonCommonExample> createState() => _SkeletonCommonExampleState();
}

class _SkeletonCommonExampleState extends State<SkeletonCommonExample> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        NibSkeleton(
          loading: _loading,
          animated: true,
          child: const _ProfileHeader(),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => setState(() => _loading = !_loading),
          child: Text(_loading ? 'Finish loading' : 'Start loading'),
        ),
      ],
    );
  }
}

/// 3. Advanced — explicit NibSkeletonBone override + NibSkeletonIgnore for a
/// static icon, custom bone colours.
class SkeletonAdvancedExample extends StatefulWidget {
  const SkeletonAdvancedExample({super.key});

  @override
  State<SkeletonAdvancedExample> createState() =>
      _SkeletonAdvancedExampleState();
}

class _SkeletonAdvancedExampleState extends State<SkeletonAdvancedExample> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        NibSkeleton(
          loading: _loading,
          animated: true,
          baseColor: Colors.blueGrey.shade100,
          shimmerColor: Colors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const NibSkeletonIgnore(
                child: Icon(Icons.star, color: Colors.amber),
              ),
              const SizedBox(width: 12),
              NibSkeletonBone(
                width: 140,
                height: 48,
                child: Container(
                  width: 140,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Custom chart',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => setState(() => _loading = !_loading),
          child: Text(_loading ? 'Finish loading' : 'Start loading'),
        ),
      ],
    );
  }
}

/// A real-world composite — a Nib `NibCard` with a header (avatar + name +
/// title), a body paragraph, and a footer with two `NibButton`s.
///
/// `NibCard`/`NibButton` are themselves `StatefulWidget`s (this library's
/// own stateful-by-default convention), so — unlike `_ProfileHeader` above,
/// which is a plain `StatelessWidget` composition NibSkeleton sees straight
/// through — they route through the render-mount engine: the real subtree
/// is mounted normally (real lifecycle) and bone boxes are substituted only
/// at paint time, preserving the card's and buttons' own `DecoratedBox`
/// chrome under the boned content. See
/// docs/superpowers/specs/2026-07-19-skeleton-render-mount.md and the
/// offsets/chrome/shimmer follow-up spec.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    return NibCard(
      header: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(radius: 24, child: Icon(Icons.person)),
          SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Grace Hopper',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text('Rear Admiral, US Navy'),
              ],
            ),
          ),
        ],
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          NibButton(
            label: 'Message',
            variant: NibButtonVariant.outline,
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          NibButton(label: 'Follow', onPressed: () {}),
        ],
      ),
      child: const Text(
        'Pioneering computer scientist — invented the first compiler and '
        'popularized the idea of machine-independent programming languages.',
      ),
    );
  }
}

/// 4. Card — real-world stress test: a Nib `NibCard` (header/body/footer)
/// containing an avatar, name/title/bio text, and two `NibButton`s.
class SkeletonCardExample extends StatefulWidget {
  const SkeletonCardExample({super.key});

  @override
  State<SkeletonCardExample> createState() => _SkeletonCardExampleState();
}

class _SkeletonCardExampleState extends State<SkeletonCardExample> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 320,
          child: NibSkeleton(
            loading: _loading,
            animated: true,
            boneSpacing: 8,
            child: const _ProfileCard(),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => setState(() => _loading = !_loading),
          child: Text(_loading ? 'Finish loading' : 'Start loading'),
        ),
      ],
    );
  }
}

/// 5. Stock Material — a subtree of plain Material widgets (`Card`,
/// `ElevatedButton`), whose chrome comes from `PhysicalShape` rather than
/// `DecoratedBox`. Exercises the render mount's stock-Material chrome
/// preservation.
class SkeletonMaterialExample extends StatefulWidget {
  const SkeletonMaterialExample({super.key});

  @override
  State<SkeletonMaterialExample> createState() =>
      _SkeletonMaterialExampleState();
}

class _SkeletonMaterialExampleState extends State<SkeletonMaterialExample> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 320,
          child: NibSkeleton(
            loading: _loading,
            animated: true,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Stock Material card',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Card and ElevatedButton chrome comes from '
                      'PhysicalShape, not DecoratedBox.',
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: () {}, child: const Text('Act')),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => setState(() => _loading = !_loading),
          child: Text(_loading ? 'Finish loading' : 'Start loading'),
        ),
      ],
    );
  }
}
