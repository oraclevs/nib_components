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
              Text('Nib Components', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              Text('Ada Lovelace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  State<SkeletonAdvancedExample> createState() => _SkeletonAdvancedExampleState();
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
              const NibSkeletonIgnore(child: Icon(Icons.star, color: Colors.amber)),
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
                  child: const Text('Custom chart', style: TextStyle(color: Colors.white)),
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
