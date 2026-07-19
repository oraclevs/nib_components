import 'package:flutter/material.dart';
// `NibNavItem` exists in both packages (nib_components' navigation-menu item and
// nib_motion's nav-bar item); this screen uses nib_motion's, so hide the other.
import 'package:nib_components/nib_components.dart' hide NibNavItem;
import 'package:nib_motion/nib_motion.dart'
    show
        NibNavBar,
        NibNavItem,
        NibNavBarStyle,
        NibNavIndicatorStyle,
        NibNavIndicatorType;

/// Entry in the catalog: a button that opens the full-screen liquid-glass
/// showcase so the glass can be judged over real, scrolling content.
class LiquidGlassShowcaseExample extends StatelessWidget {
  const LiquidGlassShowcaseExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'A full screen of liquid-glass components over a rich, '
          'scrolling backdrop — plus a glass bottom nav bar.',
        ),
        const SizedBox(height: 4),
        const Text(
          'Best viewed on an Impeller backend (Android, or  flutter run -d linux '
          '--enable-impeller). Tap the search field to confirm the keyboard '
          'sits OVER the nav bar instead of pushing it up.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const _GlassShowcaseScreen(),
            ),
          ),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Open full-screen glass demo'),
        ),
      ],
    );
  }
}

class _GlassShowcaseScreen extends StatefulWidget {
  const _GlassShowcaseScreen();

  @override
  State<_GlassShowcaseScreen> createState() => _GlassShowcaseScreenState();
}

class _GlassShowcaseScreenState extends State<_GlassShowcaseScreen> {
  int _navIndex = 0;
  double _volume = 0.6;
  double _brightness = 0.8;
  bool _wifi = true;
  bool _playing = true;

  static const _white = Colors.white;
  static const _white70 = Color(0xB3FFFFFF);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const navHeight = 66.0;

    return Scaffold(
      // The fix: the keyboard is drawn OVER the floating nav bar rather than
      // pushing it up.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const Positioned.fill(child: _Backdrop()),
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  navHeight + bottomInset + 40,
                ),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Liquid Glass',
                        style: TextStyle(
                          color: _white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: _white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _nowPlaying(),
                  const SizedBox(height: 16),
                  _searchField(),
                  const SizedBox(height: 16),
                  _statTiles(),
                  const SizedBox(height: 16),
                  _settingsCard(),
                  const SizedBox(height: 16),
                  for (var i = 0; i < 4; i++) ...[
                    _listRow(i),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 10,
            height: navHeight,
            child: NibNavBar(
              currentIndex: _navIndex,
              onIndexChanged: (i) => setState(() => _navIndex = i),
              style: NibNavBarStyle(
                glass: true,
                glassTint: const Color(0x24FFFFFF),
                glassBlur: 5,
                glassHighlight: 0.85,
                height: navHeight,
                borderRadius: BorderRadius.circular(30),
                activeColor: _white,
                inactiveColor: _white70,
              ),
              indicator: const NibNavIndicatorStyle(
                type: NibNavIndicatorType.pill,
                color: Color(0x33FFFFFF),
              ),
              items: const [
                NibNavItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NibNavItem(icon: Icon(Icons.search), label: 'Search'),
                NibNavItem(
                  icon: Icon(Icons.library_music_outlined),
                  activeIcon: Icon(Icons.library_music),
                  label: 'Library',
                ),
                NibNavItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'You',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nowPlaying() {
    return NibLiquidGlass(
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFFF472B6), Color(0xFFFB923C)],
              ),
            ),
            child: const Icon(Icons.music_note, color: _white),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Backseat Driver',
                  style: TextStyle(
                    color: _white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text('Kane Brown', style: TextStyle(color: _white70)),
              ],
            ),
          ),
          IconButton(
            iconSize: 40,
            icon: Icon(
              _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: _white,
            ),
            onPressed: () => setState(() => _playing = !_playing),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return NibLiquidGlass(
      borderRadius: const BorderRadius.all(Radius.circular(30)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: const Row(
        children: [
          Icon(Icons.search, color: _white70),
          SizedBox(width: 10),
          Expanded(
            child: TextField(
              style: TextStyle(color: _white),
              cursorColor: _white,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search songs, artists…',
                hintStyle: TextStyle(color: _white70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTiles() {
    Widget tile(String value, String label, IconData icon) => Expanded(
      child: NibLiquidGlass(
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _white),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: _white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(label, style: const TextStyle(color: _white70, fontSize: 12)),
          ],
        ),
      ),
    );
    return Row(
      children: [
        tile('128', 'Songs', Icons.queue_music),
        const SizedBox(width: 12),
        tile('12', 'Albums', Icons.album),
        const SizedBox(width: 12),
        tile('4.8', 'Rating', Icons.star),
      ],
    );
  }

  Widget _settingsCard() {
    return NibLiquidGlass(
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.volume_up, color: _white),
              Expanded(
                child: Slider(
                  value: _volume,
                  onChanged: (v) => setState(() => _volume = v),
                ),
              ),
              Text(
                '${(_volume * 100).round()}%',
                style: const TextStyle(color: _white),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.brightness_6, color: _white),
              Expanded(
                child: Slider(
                  value: _brightness,
                  onChanged: (v) => setState(() => _brightness = v),
                ),
              ),
              Text(
                '${(_brightness * 100).round()}%',
                style: const TextStyle(color: _white),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Wi-Fi', style: TextStyle(color: _white)),
            secondary: const Icon(Icons.wifi, color: _white),
            value: _wifi,
            onChanged: (v) => setState(() => _wifi = v),
          ),
        ],
      ),
    );
  }

  Widget _listRow(int i) {
    const colors = [
      Color(0xFF34D399),
      Color(0xFF60A5FA),
      Color(0xFFF472B6),
      Color(0xFFFBBF24),
    ];
    return NibLiquidGlass(
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      padding: const EdgeInsets.all(12),
      interactive: false,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors[i],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Playlist ${i + 1}',
                  style: const TextStyle(
                    color: _white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'Updated today',
                  style: TextStyle(color: _white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: _white70),
        ],
      ),
    );
  }
}

/// A vivid, high-contrast backdrop so the glass has rich detail to refract.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0EA5E9)],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned(
          top: 40,
          left: -30,
          child: _blob(200, const Color(0x88A855F7)),
        ),
        Positioned(
          top: 180,
          right: -40,
          child: _blob(220, const Color(0x8822D3EE)),
        ),
        Positioned(
          bottom: 120,
          left: 20,
          child: _blob(180, const Color(0x88F472B6)),
        ),
        Positioned(
          bottom: -30,
          right: 30,
          child: _blob(160, const Color(0x88FBBF24)),
        ),
      ],
    );
  }

  static Widget _blob(double d, Color c) => Container(
    width: d,
    height: d,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}
