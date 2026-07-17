/// The visual style of a [NibButton].
///
/// All variants share the *same* box geometry for a given size — a filled and
/// an outline button of identical `height`/`width` render at the same footprint
/// (the border is drawn inside the bounds, never adding to the size).
enum NibButtonVariant {
  /// Solid brand fill (`primary` / `primaryForeground`). The default.
  primary,

  /// Muted fill (`secondary` / `secondaryForeground`).
  secondary,

  /// Transparent with a visible `border`, `foreground` text.
  outline,

  /// Transparent, `foreground` text, `muted` fill on hover only.
  ghost,

  /// Solid `destructive` fill for dangerous actions.
  destructive,
}

/// A [NibButton] size preset. Drives the default box height, text size, icon
/// size and horizontal padding. Override the box dimensions exactly with the
/// widget's `height` / `width`.
enum NibButtonSize {
  /// ~36px tall, 13px text.
  sm,

  /// ~44px tall, 14px text. The default.
  md,

  /// ~52px tall, 16px text.
  lg,
}

/// The resolved per-size metrics for a [NibButtonSize].
class NibButtonSizeMetrics {
  const NibButtonSizeMetrics({
    required this.height,
    required this.fontSize,
    required this.horizontalPadding,
    required this.iconSize,
    required this.gap,
  });

  /// Default visual box height (before any custom `height` override).
  final double height;

  /// Label text size.
  final double fontSize;

  /// Left/right content padding.
  final double horizontalPadding;

  /// Leading/trailing icon size.
  final double iconSize;

  /// Spacing between an icon and the label.
  final double gap;

  /// The locked metrics for [size].
  static NibButtonSizeMetrics of(NibButtonSize size) => switch (size) {
        NibButtonSize.sm => const NibButtonSizeMetrics(
            height: 36,
            fontSize: 13,
            horizontalPadding: 12,
            iconSize: 16,
            gap: 6,
          ),
        NibButtonSize.md => const NibButtonSizeMetrics(
            height: 44,
            fontSize: 14,
            horizontalPadding: 16,
            iconSize: 18,
            gap: 8,
          ),
        NibButtonSize.lg => const NibButtonSizeMetrics(
            height: 52,
            fontSize: 16,
            horizontalPadding: 20,
            iconSize: 20,
            gap: 10,
          ),
      };
}
