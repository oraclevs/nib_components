import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/nib_theme.dart';

/// A custom-painted indeterminate circular loader — a soft full-circle track
/// with a gradient sweep and rounded caps rotating over it, and an optional
/// [child] centred inside (an icon, a short label, a logo).
///
/// Deliberately richer than Flutter's thin `CircularProgressIndicator`: the
/// sweep fades in from transparent to [color] so it reads as a comet tail, and
/// the stroke is thick with round caps. Reusable anywhere; `NibOtpInput` shows
/// one in its keypad's confirm slot while verifying.
///
/// ```dart
/// NibCircularLoader(size: 56, child: Icon(Icons.lock_outline))
/// ```
class NibCircularLoader extends StatefulWidget {
  const NibCircularLoader({
    super.key,
    this.size = 44,
    this.strokeWidth = 4,
    this.color,
    this.trackColor,
    this.child,
    this.duration = const Duration(milliseconds: 1100),
    this.sweep = 0.72,
  }) : assert(
         sweep > 0 && sweep < 1,
         'sweep is a fraction of the circle (0–1)',
       );

  /// Overall diameter.
  final double size;

  /// Thickness of the ring and the sweep.
  final double strokeWidth;

  /// The sweep colour. Defaults to the theme's `primary`.
  final Color? color;

  /// The faint full-circle track behind the sweep. Defaults to `color` at low
  /// opacity.
  final Color? trackColor;

  /// Optional widget centred inside the ring.
  final Widget? child;

  /// Time for one full rotation.
  final Duration duration;

  /// Fraction of the circle the moving arc spans (0–1).
  final double sweep;

  @override
  State<NibCircularLoader> createState() => _NibCircularLoaderState();
}

class _NibCircularLoaderState extends State<NibCircularLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void didUpdateWidget(covariant NibCircularLoader old) {
    super.didUpdateWidget(old);
    if (widget.duration != old.duration) {
      _controller.duration = widget.duration;
      _controller
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final color = widget.color ?? theme.primary;
    final track = widget.trackColor ?? color.withValues(alpha: 0.15);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              size: Size.square(widget.size),
              painter: _NibLoaderPainter(
                progress: _controller.value,
                color: color,
                trackColor: track,
                strokeWidth: widget.strokeWidth,
                sweep: widget.sweep,
              ),
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _NibLoaderPainter extends CustomPainter {
  _NibLoaderPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.sweep,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Faint full-circle track.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    // Rotating gradient sweep — fades in from transparent to the full colour so
    // it trails like a comet.
    final startAngle = progress * 2 * math.pi;
    final sweepAngle = sweep * 2 * math.pi;
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: sweepAngle,
      colors: [color.withValues(alpha: 0), color],
      transform: GradientRotation(startAngle),
    );
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);
    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(_NibLoaderPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth ||
      old.sweep != sweep;
}
