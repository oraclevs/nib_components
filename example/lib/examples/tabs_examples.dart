import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// Minimal — two tabs, short content, default underline indicator.
class TabsMinimalExample extends StatelessWidget {
  const TabsMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return NibTabs(
      tabs: [
        NibTab(
          label: 'Account',
          builder: (_) => const _Pad(
            child: Text('Manage your account details, email, and password here.'),
          ),
        ),
        NibTab(
          label: 'Notifications',
          builder: (_) => const _Pad(
            child: Text('Choose which notifications you receive and how.'),
          ),
        ),
      ],
    );
  }
}

/// Common — several tabs with icons, a pill indicator, and a scrollable bar that
/// overflows the width so the active tab auto-scrolls into view.
class TabsIconsScrollableExample extends StatelessWidget {
  const TabsIconsScrollableExample({super.key});

  @override
  Widget build(BuildContext context) {
    NibTab tab(String label, IconData icon, String body) => NibTab(
          label: label,
          icon: icon,
          builder: (_) => _Pad(child: Text(body)),
        );

    return NibTabs(
      scrollable: true,
      indicatorStyle: NibTabsIndicatorStyle.pill,
      tabs: [
        tab('Home', Icons.home_outlined, 'Your personalized home feed.'),
        tab('Explore', Icons.explore_outlined, 'Discover trending topics.'),
        tab('Messages', Icons.chat_bubble_outline, 'Your conversations.'),
        tab('Notifications', Icons.notifications_none, 'Recent activity.'),
        tab('Bookmarks', Icons.bookmark_border, 'Saved for later.'),
        tab('Settings', Icons.settings_outlined, 'App preferences.'),
      ],
    );
  }
}

/// Advanced — the whole point. A tall header scrolls away while the bar pins;
/// each tab's panel is a long, content-sized column of *different* height; a
/// footer follows the panel. Everything is one continuous scroll: scrolling to
/// the bottom of a panel keeps scrolling into the footer (never stuck), the
/// gutter shows when you swipe between tabs, and the footer reflows as tab
/// heights differ. `animated` fades each newly-shown panel in.
class TabsAdvancedScrollExample extends StatelessWidget {
  const TabsAdvancedScrollExample({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);

    Widget panel(String prefix, int count, Color color) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            for (var i = 1; i <= count; i++)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(theme.radiusLg),
                  border: Border.all(color: theme.border),
                ),
                child: Text('$prefix item $i',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
          ],
        );

    return NibTabs(
      animated: true,
      header: _Header(theme: theme),
      footer: _Footer(theme: theme),
      tabs: [
        NibTab(
          label: 'Posts',
          icon: Icons.article_outlined,
          builder: (_) => panel('Post', 14, theme.primary),
        ),
        NibTab(
          label: 'Media',
          icon: Icons.photo_library_outlined,
          builder: (_) => panel('Media', 6, theme.accent),
        ),
        NibTab(
          label: 'Likes',
          icon: Icons.favorite_border,
          builder: (_) => panel('Liked', 22, theme.destructive),
        ),
      ],
    );
  }
}

/// Custom styling — a transparent bar over a tinted surface, custom indicator /
/// label colors, a compact bar height, and no divider. Shows the new styling
/// knobs.
class TabsCustomStyleExample extends StatelessWidget {
  const TabsCustomStyleExample({super.key});

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF7C3AED); // violet
    return ColoredBox(
      color: const Color(0xFFF3EEFF),
      child: NibTabs(
        backgroundColor: Colors.transparent,
        indicatorColor: brand,
        selectedColor: brand,
        unselectedColor: const Color(0xFF9488B0),
        barHeight: 38,
        showDivider: false,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        tabs: [
          NibTab(
            label: 'Overview',
            builder: (_) => const _Pad(child: Text('A compact, transparent bar.')),
          ),
          NibTab(
            label: 'Activity',
            builder: (_) => const _Pad(child: Text('Custom brand indicator + labels.')),
          ),
          NibTab(
            label: 'Details',
            builder: (_) => const _Pad(child: Text('No divider under the bar.')),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme});
  final NibTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.primary, theme.accent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.background,
            child: Icon(Icons.person, color: theme.primary, size: 32),
          ),
          const SizedBox(height: 12),
          Text('Jane Developer',
              style: TextStyle(
                  color: theme.primaryForeground,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text('Scroll down — this header scrolls away, the bar pins.',
              style: TextStyle(
                  color: theme.primaryForeground.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.theme});
  final NibTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: theme.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Footer — below the tabs',
              style: TextStyle(
                  color: theme.foreground, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'You reached here by scrolling straight through the panel — no '
            'getting stuck at its edge. Switch tabs and this footer reflows to '
            'hug each panel.',
            style: TextStyle(color: theme.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(20), child: child);
}
