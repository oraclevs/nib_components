import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The locked Nib design-token palette, exposed as a [ThemeExtension] so
/// every component reads colors/radii from [NibTheme.of] instead of
/// hardcoding hex values.
@immutable
class NibTheme extends ThemeExtension<NibTheme> {
  const NibTheme({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.border,
    required this.input,
    required this.ring,
    required this.destructive,
    required this.radiusSm,
    required this.radiusDefault,
    required this.radiusLg,
    required this.radiusPill,
  });

  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color border;
  final Color input;
  final Color ring;
  final Color destructive;

  final double radiusSm;
  final double radiusDefault;
  final double radiusLg;
  final double radiusPill;

  /// The light-mode token set.
  static const NibTheme light = NibTheme(
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF0A0A0A),
    card: Color(0xFFFFFFFF),
    cardForeground: Color(0xFF0A0A0A),
    primary: Color(0xFF02569B),
    primaryForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFFF4F8FF),
    secondaryForeground: Color(0xFF02569B),
    muted: Color(0xFFF1F5F9),
    mutedForeground: Color(0xFF64748B),
    accent: Color(0xFF54C5F8),
    accentForeground: Color(0xFF02569B),
    border: Color(0xFFE2E8F0),
    input: Color(0xFFE2E8F0),
    ring: Color(0xFF0175C2),
    destructive: Color(0xFFEF4444),
    radiusSm: 4,
    radiusDefault: 8,
    radiusLg: 12,
    radiusPill: 9999,
  );

  /// The dark-mode token set.
  static const NibTheme dark = NibTheme(
    background: Color(0xFF0A0A0A),
    foreground: Color(0xFFFAFAFA),
    card: Color(0xFF111111),
    cardForeground: Color(0xFFFAFAFA),
    primary: Color(0xFF54C5F8),
    primaryForeground: Color(0xFF0A0A0A),
    secondary: Color(0xFF1A1F2E),
    secondaryForeground: Color(0xFF54C5F8),
    muted: Color(0xFF1A1A1A),
    mutedForeground: Color(0xFF94A3B8),
    accent: Color(0xFF0175C2),
    accentForeground: Color(0xFFFFFFFF),
    border: Color(0xFF1E2433),
    input: Color(0xFF1E2433),
    ring: Color(0xFF54C5F8),
    destructive: Color(0xFFEF4444),
    radiusSm: 4,
    radiusDefault: 8,
    radiusLg: 12,
    radiusPill: 9999,
  );

  /// Resolves the ambient [NibTheme]: the host app's registered
  /// `ThemeData.extensions` entry if present, otherwise [light]/[dark]
  /// picked from the ambient [Brightness].
  static NibTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<NibTheme>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  NibTheme copyWith({
    Color? background,
    Color? foreground,
    Color? card,
    Color? cardForeground,
    Color? primary,
    Color? primaryForeground,
    Color? secondary,
    Color? secondaryForeground,
    Color? muted,
    Color? mutedForeground,
    Color? accent,
    Color? accentForeground,
    Color? border,
    Color? input,
    Color? ring,
    Color? destructive,
    double? radiusSm,
    double? radiusDefault,
    double? radiusLg,
    double? radiusPill,
  }) {
    return NibTheme(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      card: card ?? this.card,
      cardForeground: cardForeground ?? this.cardForeground,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      border: border ?? this.border,
      input: input ?? this.input,
      ring: ring ?? this.ring,
      destructive: destructive ?? this.destructive,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusDefault: radiusDefault ?? this.radiusDefault,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusPill: radiusPill ?? this.radiusPill,
    );
  }

  @override
  NibTheme lerp(ThemeExtension<NibTheme>? other, double t) {
    if (other is! NibTheme) return this;
    return NibTheme(
      background: Color.lerp(background, other.background, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardForeground: Color.lerp(cardForeground, other.cardForeground, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryForeground: Color.lerp(
        primaryForeground,
        other.primaryForeground,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryForeground: Color.lerp(
        secondaryForeground,
        other.secondaryForeground,
        t,
      )!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentForeground: Color.lerp(
        accentForeground,
        other.accentForeground,
        t,
      )!,
      border: Color.lerp(border, other.border, t)!,
      input: Color.lerp(input, other.input, t)!,
      ring: Color.lerp(ring, other.ring, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusDefault: lerpDouble(radiusDefault, other.radiusDefault, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
      radiusPill: lerpDouble(radiusPill, other.radiusPill, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NibTheme &&
        other.background == background &&
        other.foreground == foreground &&
        other.card == card &&
        other.cardForeground == cardForeground &&
        other.primary == primary &&
        other.primaryForeground == primaryForeground &&
        other.secondary == secondary &&
        other.secondaryForeground == secondaryForeground &&
        other.muted == muted &&
        other.mutedForeground == mutedForeground &&
        other.accent == accent &&
        other.accentForeground == accentForeground &&
        other.border == border &&
        other.input == input &&
        other.ring == ring &&
        other.destructive == destructive &&
        other.radiusSm == radiusSm &&
        other.radiusDefault == radiusDefault &&
        other.radiusLg == radiusLg &&
        other.radiusPill == radiusPill;
  }

  @override
  int get hashCode => Object.hash(
    background,
    foreground,
    card,
    cardForeground,
    primary,
    primaryForeground,
    secondary,
    secondaryForeground,
    muted,
    mutedForeground,
    Object.hash(accent, accentForeground, border, input, ring, destructive),
    Object.hash(radiusSm, radiusDefault, radiusLg, radiusPill),
  );
}
