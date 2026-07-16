import 'package:nib_motion/nib_motion.dart' show NibAnim;

/// Preset max-width for a [showNibDialog]/`NibDialog` surface. The actual width
/// is clamped to the viewport minus a margin, so these are ceilings, not fixed
/// widths — a narrow phone still gets a full-bleed-minus-margin dialog.
enum NibDialogSize {
  /// ~380 logical px ceiling — alerts, confirmations.
  sm,

  /// ~512 logical px ceiling — the default; forms, standard content.
  md,

  /// ~720 logical px ceiling — wide content, side-by-side layouts.
  lg,

  /// Fills the viewport (inside its safe area). No max width.
  fullscreen,
}

/// Predefined entrance/exit motions for a dialog surface, layered on top of
/// `nib_motion`. Only used when `animated: true`; the timing/curve/spring is
/// controlled separately by the `transition` parameter.
enum NibDialogAnimation {
  /// No transform — the dialog appears and closes instantly. Equivalent to
  /// `animated: false` for the card itself.
  none,

  /// Fade opacity in on open, out on close.
  fade,

  /// Scale up from slightly small (no opacity change).
  scale,

  /// Fade + a small scale-up. The default when `animated: true`.
  fadeScale,

  /// Fade + a rise from slightly below (sheet-like).
  slideUp,
}

const double _smWidth = 380;
const double _mdWidth = 512;
const double _lgWidth = 720;

/// How small a scale-only preset starts.
const double _scaleFrom = 0.96;

/// How small the fade+scale preset starts (subtler than [scale] alone).
const double _fadeScaleFrom = 0.97;

/// How far below its resting position [NibDialogAnimation.slideUp] starts, in
/// logical pixels.
const double _slideFrom = 16;

/// The ceiling width for a [NibDialogSize], or `null` for
/// [NibDialogSize.fullscreen] (which fills the viewport). Pure — the surface
/// clamps this to the available width itself.
double? nibDialogMaxWidth(NibDialogSize size) {
  switch (size) {
    case NibDialogSize.sm:
      return _smWidth;
    case NibDialogSize.md:
      return _mdWidth;
    case NibDialogSize.lg:
      return _lgWidth;
    case NibDialogSize.fullscreen:
      return null;
  }
}

/// Resolves a [NibDialogAnimation] to the [NibAnim] "from" state the card
/// animates out of (on open) and back into (on close). The at-rest target is
/// always [NibAnim.identity].
NibAnim resolveNibDialogEnter(NibDialogAnimation animation) {
  switch (animation) {
    case NibDialogAnimation.none:
      return NibAnim.identity;
    case NibDialogAnimation.fade:
      return const NibAnim(opacity: 0);
    case NibDialogAnimation.scale:
      return const NibAnim(scale: _scaleFrom);
    case NibDialogAnimation.fadeScale:
      return const NibAnim(opacity: 0, scale: _fadeScaleFrom);
    case NibDialogAnimation.slideUp:
      return const NibAnim(opacity: 0, y: _slideFrom);
  }
}
