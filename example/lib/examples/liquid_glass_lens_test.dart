import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibGlass;

/// Catalog entry: opens the full-screen grid lens test.
class LiquidGlassLensTestExample extends StatelessWidget {
  const LiquidGlassLensTestExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Glass over a fine grid — the clearest way to see the lens. '
            'Drag the shapes around: the grid should bend and magnify through '
            'them like a real concave lens (like the reference).'),
        const SizedBox(height: 4),
        const Text(
          'Needs Impeller: run on Android, or  flutter run -d linux --enable-impeller.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const _LensTestScreen()),
          ),
          icon: const Icon(Icons.grid_on),
          label: const Text('Open grid lens test'),
        ),
      ],
    );
  }
}

class _LensTestScreen extends StatelessWidget {
  const _LensTestScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // The sharp backdrop that makes refraction visible.
          const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          // Draggable glass shapes.
          const _DraggableGlass(
            start: Offset(40, 120),
            size: Size(150, 150),
            radius: 40,
          ),
          _DraggableGlass(
            start: const Offset(210, 260),
            size: const Size(160, 160),
            radius: 999,
            clipper: _CircleClipper(),
          ),
          const _DraggableGlass(
            start: Offset(80, 440),
            size: Size(220, 110),
            radius: 55,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton.filledTonal(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // Diagnostic banner: is the real shader path available on this device?
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _DiagnosticBanner(),
              ),
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Drag the glass shapes across the grid',
                    style: TextStyle(color: Colors.black54)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggableGlass extends StatefulWidget {
  const _DraggableGlass({
    required this.start,
    required this.size,
    required this.radius,
    this.clipper,
  });

  final Offset start;
  final Size size;
  final double radius;
  final CustomClipper<Path>? clipper;

  @override
  State<_DraggableGlass> createState() => _DraggableGlassState();
}

class _DraggableGlassState extends State<_DraggableGlass> {
  late Offset _pos = widget.start;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _pos += d.delta),
        // A visible outline so the shape is always locatable, even if the
        // shader path isn't active — then a bent grid inside = real refraction.
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.clipper == null ? BorderRadius.circular(widget.radius) : null,
            shape: widget.clipper == null ? BoxShape.rectangle : BoxShape.circle,
            border: Border.all(color: const Color(0x66FFFFFF), width: 1.5),
          ),
          child: NibLiquidGlass(
            width: widget.size.width,
            height: widget.size.height,
            borderRadius: BorderRadius.circular(widget.radius),
            clipper: widget.clipper,
            interactive: false,
            showBorder: false,
            padding: EdgeInsets.zero,
            tint: const Color(0x14FFFFFF),
            thickness: 26,
            chromaticAberration: 0.04,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// Reports whether the REAL liquid-glass shader path is actually running on
/// this device: the `.frag` program must compile/bundle AND `ImageFilter.shader`
/// must be supported (Impeller). If this says FALLBACK, every glass here is the
/// plain blur — no refraction is possible, so the fix is about getting the
/// shader to run, not the optics.
class _DiagnosticBanner extends StatelessWidget {
  const _DiagnosticBanner();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: NibGlass.debugShaderPathAvailable(),
      builder: (context, snap) {
        final ok = snap.data;
        final (text, color) = switch (ok) {
          true => ('Shader glass: RUNNING (real refraction) ✓', const Color(0xCC1B5E20)),
          false => ('Shader glass: FALLBACK (no refraction) ✗', const Color(0xCCB71C1C)),
          null => ('Checking shader…', const Color(0xCC424242)),
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}

class _CircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()..addOval(Offset.zero & size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// A fine graph-paper grid on a light backdrop — high-frequency detail so the
/// glass refraction is clearly visible.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFECE7DE));
    final thin = Paint()
      ..color = const Color(0x2247618A)
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = const Color(0x3347618A)
      ..strokeWidth = 1.5;
    const step = 22.0;
    var i = 0;
    for (double x = 0; x <= size.width; x += step, i++) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), i % 5 == 0 ? thick : thin);
    }
    i = 0;
    for (double y = 0; y <= size.height; y += step, i++) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), i % 5 == 0 ? thick : thin);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
