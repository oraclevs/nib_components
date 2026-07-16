import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
// `NibNavItem` exists in both packages; this screen uses nib_motion's nav bar.
import 'package:nib_components/nib_components.dart' hide NibNavItem;
import 'package:nib_motion/nib_motion.dart'
    show NibNavBar, NibNavItem, NibNavBarStyle, NibNavIndicatorStyle, NibNavIndicatorType;

/// The audio file the player loads. Drop your own at
/// `example/assets/audio/track.mp3` (already wired in pubspec.yaml).
const String _trackAsset = 'audio/Phyno_-_The_Bag.mp3';

class _Track {
  const _Track(this.title, this.artist, this.colors);
  final String title;
  final String artist;
  final List<Color> colors;
}

const List<_Track> _tracks = [
  _Track('Backseat Driver', 'Kane Brown', [Color(0xFFF472B6), Color(0xFFFB923C)]),
  _Track('Midnight City', 'M83', [Color(0xFF6366F1), Color(0xFF22D3EE)]),
  _Track('Blinding Lights', 'The Weeknd', [Color(0xFFEF4444), Color(0xFFF59E0B)]),
  _Track('Sunflower', 'Post Malone', [Color(0xFFF59E0B), Color(0xFF84CC16)]),
  _Track('Levitating', 'Dua Lipa', [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
];

const _white = Colors.white;
const _white70 = Color(0xB3FFFFFF);
const _white54 = Color(0x8AFFFFFF);

/// Catalog entry — opens the full-screen liquid-glass music player.
class MusicPlayerExample extends StatelessWidget {
  const MusicPlayerExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('A Spotify-style player built entirely from Liquid Glass — '
            'real play/pause, seek, and volume.'),
        const SizedBox(height: 4),
        const Text(
          'Drop an audio file at  example/assets/audio/track.mp3  to hear it. '
          'Needs Impeller (Android, or --enable-impeller) for the glass.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MusicPlayerScreen()),
          ),
          icon: const Icon(Icons.play_circle_fill),
          label: const Text('Open Music Player'),
        ),
      ],
    );
  }
}

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];

  int _current = 0;
  int _navIndex = 0;
  bool _playing = false;
  bool _shuffle = false;
  bool _loop = false;
  double _volume = 0.7;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  _Track get _track => _tracks[_current];

  @override
  void initState() {
    super.initState();
    _player.setReleaseMode(ReleaseMode.stop);
    _player.setVolume(_volume);
    _subs.add(_player.onPositionChanged.listen((p) => setState(() => _position = p)));
    _subs.add(_player.onDurationChanged.listen((d) => setState(() => _duration = d)));
    _subs.add(_player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    }));
    _subs.add(_player.onPlayerComplete.listen((_) => _onComplete()));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    try {
      await _player.play(AssetSource(_trackAsset), volume: _volume);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add example/assets/audio/track.mp3 to play audio.'),
        ));
      }
    }
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else if (_player.state == PlayerState.paused) {
      await _player.resume();
    } else {
      await _play();
    }
  }

  Future<void> _select(int index) async {
    setState(() {
      _current = index;
      _position = Duration.zero;
    });
    await _player.stop();
    await _play();
  }

  void _onComplete() {
    if (_loop) {
      _select(_current);
    } else {
      _skip(1);
    }
  }

  void _skip(int dir) {
    final next = (_current + dir + _tracks.length) % _tracks.length;
    _select(next);
  }

  Future<void> _seekFraction(double f) async {
    if (_duration == Duration.zero) return;
    await _player.seek(_duration * f);
  }

  Future<void> _setVolume(double v) async {
    setState(() => _volume = v);
    await _player.setVolume(v);
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  void _openQueue() {
    showNibBottomSheet<void>(
      context,
      title: 'Up next',
      animated: true,
      snapPoints: const [0.5, 0.9],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _tracks.length; i++)
            Builder(
              builder: (sctx) => _QueueRow(
                track: _tracks[i],
                active: i == _current,
                onTap: () {
                  NibBottomSheetScope.of(sctx).close();
                  _select(i);
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const navHeight = 66.0;
    final frac = _duration.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: _Backdrop(colors: _track.colors)),
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: EdgeInsets.fromLTRB(18, 8, 18, navHeight + bottomInset + 32),
                children: [
                  _header(),
                  const SizedBox(height: 18),
                  _albumArt(),
                  const SizedBox(height: 22),
                  _titleRow(),
                  const SizedBox(height: 16),
                  _seekCard(frac),
                  const SizedBox(height: 16),
                  _controls(),
                  const SizedBox(height: 16),
                  _volumeCard(),
                  const SizedBox(height: 22),
                  const Text('Up next',
                      style: TextStyle(color: _white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _tracks.length; i++) ...[
                    _playlistRow(i),
                    const SizedBox(height: 10),
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
                glassTint: const Color(0x1FFFFFFF),
                glassBlur: 4,
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
                NibNavItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
                NibNavItem(icon: Icon(Icons.search), label: 'Search'),
                NibNavItem(icon: Icon(Icons.library_music_outlined), activeIcon: Icon(Icons.library_music), label: 'Library'),
                NibNavItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'You'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: _white, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const Column(
          children: [
            Text('PLAYING FROM PLAYLIST',
                style: TextStyle(color: _white54, fontSize: 10, letterSpacing: 1.2)),
            Text('Liquid Mix', style: TextStyle(color: _white, fontWeight: FontWeight.w600)),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.queue_music, color: _white),
          onPressed: _openQueue,
        ),
      ],
    );
  }

  Widget _albumArt() {
    return Center(
      child: NibLiquidGlass(
        width: 300,
        height: 300,
        borderRadius: BorderRadius.circular(28),
        interactive: false,
        padding: EdgeInsets.zero,
        thickness: 22,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _track.colors,
            ),
          ),
          child: const Center(child: Icon(Icons.music_note, color: Colors.white70, size: 80)),
        ),
      ),
    );
  }

  Widget _titleRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(_track.artist, style: const TextStyle(color: _white70, fontSize: 15)),
            ],
          ),
        ),
        const Icon(Icons.favorite_border, color: _white),
      ],
    );
  }

  Widget _seekCard(double frac) {
    return NibLiquidGlass(
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      interactive: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: _white,
              inactiveTrackColor: _white54,
              thumbColor: _white,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: frac,
              onChanged: (v) {
                setState(() => _position = _duration * v);
              },
              onChangeEnd: _seekFraction,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(_position), style: const TextStyle(color: _white70, fontSize: 12)),
                Text(_fmt(_duration), style: const TextStyle(color: _white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return NibLiquidGlass(
      borderRadius: const BorderRadius.all(Radius.circular(30)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      interactive: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.shuffle, color: _shuffle ? _white : _white54),
            onPressed: () => setState(() => _shuffle = !_shuffle),
          ),
          IconButton(
            icon: const Icon(Icons.skip_previous, color: _white, size: 34),
            onPressed: () => _skip(-1),
          ),
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(color: _white, shape: BoxShape.circle),
              child: Icon(_playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.black, size: 38),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next, color: _white, size: 34),
            onPressed: () => _skip(1),
          ),
          IconButton(
            icon: Icon(Icons.repeat, color: _loop ? _white : _white54),
            onPressed: () => setState(() => _loop = !_loop),
          ),
        ],
      ),
    );
  }

  Widget _volumeCard() {
    return NibLiquidGlass(
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      interactive: false,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.volume_down, color: _white),
            onPressed: () => _setVolume((_volume - 0.1).clamp(0.0, 1.0)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                activeTrackColor: _white,
                inactiveTrackColor: _white54,
                thumbColor: _white,
              ),
              child: Slider(value: _volume, onChanged: _setVolume),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.volume_up, color: _white),
            onPressed: () => _setVolume((_volume + 0.1).clamp(0.0, 1.0)),
          ),
        ],
      ),
    );
  }

  Widget _playlistRow(int i) {
    final t = _tracks[i];
    final active = i == _current;
    return GestureDetector(
      onTap: () => _select(i),
      child: NibLiquidGlass(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        padding: const EdgeInsets.all(10),
        interactive: false,
        tint: active ? const Color(0x24FFFFFF) : null,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: t.colors),
              ),
              child: active
                  ? Icon(_playing ? Icons.equalizer : Icons.pause, color: _white, size: 22)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: active ? _white : const Color(0xE6FFFFFF),
                          fontWeight: FontWeight.w600)),
                  Text(t.artist, style: const TextStyle(color: _white70, fontSize: 12)),
                ],
              ),
            ),
            Icon(active ? Icons.volume_up : Icons.more_horiz, color: _white54),
          ],
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.track, required this.active, required this.onTap});

  final _Track track;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(colors: track.colors),
        ),
      ),
      title: Text(track.title,
          style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      subtitle: Text(track.artist),
      trailing: active ? Icon(Icons.equalizer, color: scheme.primary) : null,
    );
  }
}

/// A vivid backdrop derived from the current track's colours, so the glass has
/// something rich and coloured to refract.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFF0B1020)),
          child: SizedBox.expand(),
        ),
        Positioned(top: -40, left: -40, child: _blob(260, colors.first.withValues(alpha: 0.55))),
        Positioned(top: 120, right: -60, child: _blob(240, colors.last.withValues(alpha: 0.5))),
        Positioned(bottom: 40, left: -30, child: _blob(220, colors.first.withValues(alpha: 0.4))),
      ],
    );
  }

  static Widget _blob(double d, Color c) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}
