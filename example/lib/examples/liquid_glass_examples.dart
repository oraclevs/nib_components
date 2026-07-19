import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibTransition;

/// A colourful, busy backdrop so the glass frost + refraction is visible.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.child, this.height = 260});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF7C3AED),
                    Color(0xFF2563EB),
                    Color(0xFF06B6D4),
                  ],
                ),
              ),
              child: SizedBox.expand(),
            ),
            Positioned(
              top: -20,
              left: 30,
              child: _blob(120, const Color(0x66F472B6)),
            ),
            Positioned(
              bottom: -10,
              right: 40,
              child: _blob(140, const Color(0x66FDE047)),
            ),
            Positioned(
              top: 60,
              right: 80,
              child: _blob(70, const Color(0x6634D399)),
            ),
            child,
          ],
        ),
      ),
    );
  }

  static Widget _blob(double d, Color c) => Container(
    width: d,
    height: d,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}

/// A capsule-ish rounded-rect that also works as a custom clipper demo.
class _CapsuleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(size.shortestSide / 2),
      ),
    );
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 1. Minimal — a glass card floating over the colourful backdrop.
class LiquidGlassMinimalExample extends StatelessWidget {
  const LiquidGlassMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Minimal — a glass card over a busy backdrop'),
        const SizedBox(height: 4),
        const Text(
          'Run the example with  flutter run -d linux --enable-impeller  to see '
          'true edge refraction; otherwise you get the frosted-blur fallback.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        const _Backdrop(
          child: NibLiquidGlass(
            width: 260,
            height: 150,
            interactive: false,
            child: Center(
              child: Text(
                'Liquid Glass',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 2. Interactive — the highlight follows the pointer and a press scales the
/// glass (animated via nib_motion).
class LiquidGlassInteractiveExample extends StatelessWidget {
  const LiquidGlassInteractiveExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Interactive — move the pointer over it, press to scale'),
        const SizedBox(height: 12),
        _Backdrop(
          child: NibLiquidGlass(
            width: 280,
            height: 160,
            animated: true,
            transition: NibTransition.springGentle,
            thickness: 32,
            highlight: 0.6,
            child: const Center(
              child: Icon(Icons.touch_app, color: Colors.white, size: 40),
            ),
          ),
        ),
      ],
    );
  }
}

/// 3. Advanced — a custom capsule clip, stronger tint, an inner control laid
/// over the glass (state still works inside).
class LiquidGlassAdvancedExample extends StatefulWidget {
  const LiquidGlassAdvancedExample({super.key});

  @override
  State<LiquidGlassAdvancedExample> createState() =>
      _LiquidGlassAdvancedExampleState();
}

class _LiquidGlassAdvancedExampleState
    extends State<LiquidGlassAdvancedExample> {
  double _value = 0.4;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Advanced — custom capsule clip, tint, a live control inside',
        ),
        const SizedBox(height: 12),
        _Backdrop(
          height: 220,
          child: NibLiquidGlass(
            width: 320,
            height: 96,
            clipper: _CapsuleClipper(),
            tint: const Color(0x40FFFFFF),
            blurSigma: 18,
            highlight: 0.7,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.volume_up, color: Colors.white),
                Expanded(
                  child: Slider(
                    value: _value,
                    onChanged: (v) => setState(() => _value = v),
                  ),
                ),
                Text(
                  '${(_value * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
