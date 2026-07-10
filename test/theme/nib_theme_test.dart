import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

void main() {
  test('light token values match the locked design system table', () {
    expect(NibTheme.light.background, const Color(0xFFFFFFFF));
    expect(NibTheme.light.foreground, const Color(0xFF0A0A0A));
    expect(NibTheme.light.primary, const Color(0xFF02569B));
    expect(NibTheme.light.primaryForeground, const Color(0xFFFFFFFF));
    expect(NibTheme.light.border, const Color(0xFFE2E8F0));
    expect(NibTheme.light.destructive, const Color(0xFFEF4444));
    expect(NibTheme.light.radiusSm, 4);
    expect(NibTheme.light.radiusDefault, 8);
    expect(NibTheme.light.radiusLg, 12);
    expect(NibTheme.light.radiusPill, 9999);
  });

  test('dark token values match the locked design system table', () {
    expect(NibTheme.dark.background, const Color(0xFF0A0A0A));
    expect(NibTheme.dark.foreground, const Color(0xFFFAFAFA));
    expect(NibTheme.dark.primary, const Color(0xFF54C5F8));
    expect(NibTheme.dark.primaryForeground, const Color(0xFF0A0A0A));
    expect(NibTheme.dark.border, const Color(0xFF1E2433));
    expect(NibTheme.dark.destructive, const Color(0xFFEF4444));
  });

  testWidgets('NibTheme.of falls back to brightness when not registered', (
    tester,
  ) async {
    late NibTheme resolvedLight;
    late NibTheme resolvedDark;
    await tester.pumpWidget(
      MaterialApp(
        home: Theme(
          data: ThemeData(brightness: Brightness.light),
          child: Builder(
            builder: (context) {
              resolvedLight = NibTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(resolvedLight, NibTheme.light);

    await tester.pumpWidget(
      MaterialApp(
        home: Theme(
          data: ThemeData(brightness: Brightness.dark),
          child: Builder(
            builder: (context) {
              resolvedDark = NibTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(resolvedDark, NibTheme.dark);
  });

  testWidgets('NibTheme.of prefers a registered extension', (tester) async {
    const custom = NibTheme(
      background: Color(0xFF123456),
      foreground: Color(0xFFFFFFFF),
      card: Color(0xFF123456),
      cardForeground: Color(0xFFFFFFFF),
      primary: Color(0xFFFFFFFF),
      primaryForeground: Color(0xFF000000),
      secondary: Color(0xFF000000),
      secondaryForeground: Color(0xFFFFFFFF),
      muted: Color(0xFF000000),
      mutedForeground: Color(0xFFFFFFFF),
      accent: Color(0xFF000000),
      accentForeground: Color(0xFFFFFFFF),
      border: Color(0xFF000000),
      input: Color(0xFF000000),
      ring: Color(0xFF000000),
      destructive: Color(0xFFEF4444),
      radiusSm: 4,
      radiusDefault: 8,
      radiusLg: 12,
      radiusPill: 9999,
    );
    late NibTheme resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [custom]),
        home: Builder(
          builder: (context) {
            resolved = NibTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(resolved, custom);
  });
}
