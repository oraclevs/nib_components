import 'package:nib_motion/nib_motion.dart' show NibAnim;

/// Predefined entrance/exit motions for a [NibSelect] dropdown, layered on top
/// of `nib_motion`. Pick one via `NibSelect.animation` (only used when
/// `animated: true`); the timing/curve/spring is still controlled separately
/// by `NibSelect.transition`.
///
/// Each preset is direction-aware — a `slide`/`slideFade` opening *upward*
/// (when there's no room below the trigger) slides from below instead of
/// above. For full control, bypass the enum with `NibSelect.enterFrom` (a raw
/// [NibAnim] "from" state).
enum NibSelectAnimation {
  /// No entrance transform — the dropdown simply appears (and closes
  /// instantly). Equivalent to `animated: false` for the dropdown itself.
  none,

  /// Fade opacity in on open, out on close.
  fade,

  /// Translate from the trigger edge (no opacity change).
  slide,

  /// Scale up from slightly small (no translation).
  scale,

  /// Fade + a small scale-up. The default when `animated: true`.
  fadeScale,

  /// Fade + a slide from the trigger edge.
  slideFade,
}

/// How far a slide preset travels, in logical pixels.
const double _slideDistance = 10;

/// How far a slightly-small scale preset starts from identity.
const double _scaleFrom = 0.96;

/// Resolves a [NibSelectAnimation] to the [NibAnim] "from" state the dropdown
/// animates out of (on open) and back into (on close). The `animate`/at-rest
/// target is always [NibAnim.identity].
///
/// [openUp] flips the slide direction so the panel always travels *away from*
/// the trigger as it settles: sliding down when the panel is below the
/// trigger, up when it's above.
NibAnim resolveNibSelectEnter(NibSelectAnimation animation, {required bool openUp}) {
  final slideY = openUp ? _slideDistance : -_slideDistance;
  switch (animation) {
    case NibSelectAnimation.none:
      return NibAnim.identity;
    case NibSelectAnimation.fade:
      return const NibAnim(opacity: 0);
    case NibSelectAnimation.slide:
      return NibAnim(y: slideY);
    case NibSelectAnimation.scale:
      return const NibAnim(scale: _scaleFrom);
    case NibSelectAnimation.fadeScale:
      return const NibAnim(opacity: 0, scale: _scaleFrom);
    case NibSelectAnimation.slideFade:
      return NibAnim(opacity: 0, y: slideY);
  }
}
