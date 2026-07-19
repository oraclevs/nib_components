import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// An image slide — shows how a real photo renders inside the carousel:
/// `BoxFit.cover` fills the slide, clipped to rounded corners, with a caption
/// gradient overlay so text stays legible over the image.
class _Slide extends StatelessWidget {
  const _Slide(this.index, this.caption);

  final int index;
  final String caption;

  static const _imageAsset = 'assets/images/24570.png';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _imageAsset,
              fit: BoxFit.cover,
              // A visible fallback if the asset isn't bundled, so the carousel
              // still demos rather than showing a red error box.
              errorBuilder: (context, error, stack) => ColoredBox(
                color: Colors.primaries[index % Colors.primaries.length],
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 14,
              child: Text(
                caption,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _slides() => const [
  _Slide(0, 'Slide 1'),
  _Slide(1, 'Slide 2'),
  _Slide(2, 'Slide 3'),
  _Slide(3, 'Slide 4'),
];

/// 1. Minimal — just items + the default dots indicator.
class CarouselMinimalExample extends StatelessWidget {
  const CarouselMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Minimal — swipe; dots indicator'),
        const SizedBox(height: 12),
        NibCarousel(items: _slides()),
      ],
    );
  }
}

/// 2. Common — auto-play, looping, a peek of the neighbouring slides.
class CarouselAutoPlayExample extends StatelessWidget {
  const CarouselAutoPlayExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Auto-play — loops, peeks neighbours, pauses while you drag',
        ),
        const SizedBox(height: 12),
        NibCarousel(
          items: _slides(),
          autoPlay: true,
          autoPlayInterval: const Duration(seconds: 3),
          loop: true,
          peekExtent: 32,
          animated: true,
          indicatorStyle: NibCarouselIndicatorStyle.line,
        ),
      ],
    );
  }
}

/// 3. Advanced — external controller with prev/next buttons and a live page
/// readout, no built-in indicator.
class CarouselControllerExample extends StatefulWidget {
  const CarouselControllerExample({super.key});

  @override
  State<CarouselControllerExample> createState() =>
      _CarouselControllerExampleState();
}

class _CarouselControllerExampleState extends State<CarouselControllerExample> {
  final _controller = NibCarouselController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Advanced — external controller, custom controls, looping'),
        const SizedBox(height: 12),
        NibCarousel(
          items: _slides(),
          controller: _controller,
          loop: true,
          height: 180,
          indicatorStyle: NibCarouselIndicatorStyle.none,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _controller.previousPage,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Prev'),
            ),
            const SizedBox(width: 12),
            Text('Page ${_controller.page + 1} of ${_slides().length}'),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _controller.nextPage,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}
