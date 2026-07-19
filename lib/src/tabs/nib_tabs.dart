import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibTransition;

import '../theme/nib_theme.dart';
import 'nib_tabs_controller.dart';

/// One tab in a [NibTabs]: a [label] (with an optional [icon]) shown in the bar,
/// and a [builder] that lazily builds the panel shown when the tab is selected.
class NibTab {
  const NibTab({required this.label, this.icon, required this.builder});

  /// The bar label.
  final String label;

  /// Optional icon shown before the label.
  final IconData? icon;

  /// Builds the panel body. Called lazily the first time the tab is shown.
  final WidgetBuilder builder;
}

/// How the active-tab indicator is drawn in the bar.
enum NibTabsIndicatorStyle {
  /// A short bar under the active tab (the default).
  underline,

  /// A filled rounded pill behind the active tab's label.
  pill,

  /// No indicator.
  none,
}

/// A tab set that solves the two things "floater tabs" get wrong:
///
/// 1. **No stuck scroll.** `NibTabs` owns exactly one vertical scroll (an
///    internal [CustomScrollView]): your [header] scrolls away, the bar pins, the
///    active panel scrolls as part of that *same* scroll, then your [footer]
///    scrolls in. Because the panel is not its own [Scrollable], reaching its end
///    just keeps scrolling the page — it can never trap the user.
/// 2. **A gutter between panels.** Swiping (or tapping) from one tab to the next
///    separates the outgoing and incoming panels by [panelGap] so they never look
///    glued together, and the pager height reflows smoothly between panels of
///    different heights.
///
/// **Contract:** put "content above" in [header] and "content below" in [footer];
/// do **not** wrap `NibTabs` in another vertical `ListView`/`SingleChildScrollView`
/// — that reintroduces the nested-scroll bug this widget exists to prevent.
/// `NibTabs` expects a bounded height (it fills its parent, like any scroll view).
///
/// ```dart
/// NibTabs(
///   header: MyHero(),
///   tabs: [
///     NibTab(label: 'Posts', builder: (_) => PostsList()),
///     NibTab(label: 'About', builder: (_) => AboutPanel()),
///   ],
///   footer: MyFooter(),
/// )
/// ```
class NibTabs extends StatefulWidget {
  const NibTabs({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.controller,
    this.header,
    this.footer,
    this.scrollable = false,
    this.indicatorStyle = NibTabsIndicatorStyle.underline,
    this.panelGap = 16,
    this.swipeable = true,
    this.animated = false,
    this.transition,
    this.onChanged,
    this.backgroundColor,
    this.indicatorColor,
    this.selectedColor,
    this.unselectedColor,
    this.barHeight = 44,
    this.labelPadding = const EdgeInsets.symmetric(horizontal: 16),
    this.showDivider = true,
    this.dividerColor,
  }) : assert(tabs.length > 0, 'NibTabs needs at least one tab'),
       assert(initialIndex >= 0),
       assert(barHeight > 0);

  /// The tabs, in bar order. Must be non-empty.
  final List<NibTab> tabs;

  /// The tab shown first (ignored when a [controller] is supplied — its `index`
  /// wins).
  final int initialIndex;

  /// Optional external controller. Never required — `NibTabs` owns one internally
  /// when this is `null`, disposing it on unmount/controller-swap.
  final NibTabsController? controller;

  /// Content shown above the bar (your "content above"). Scrolls away as the user
  /// scrolls; the bar pins beneath it.
  final Widget? header;

  /// Content shown below the active panel (your "content below"). Scrolls in after
  /// the panel, separated from it by [panelGap].
  final Widget? footer;

  /// When `true` the bar takes intrinsic-width tabs inside a horizontal scroll and
  /// keeps the active tab in view; when `false` (default) tabs share the width
  /// equally.
  final bool scrollable;

  /// How the active-tab indicator is drawn.
  final NibTabsIndicatorStyle indicatorStyle;

  /// The gutter between adjacent panels during a switch, and the margin before
  /// [footer]. Defaults to 16.
  final double panelGap;

  /// Whether a horizontal swipe on the panel changes tab. Tapping the bar always
  /// works.
  final bool swipeable;

  /// Opt-in `nib_motion` fade on the newly-shown panel. `false` (default) builds
  /// zero `NibMotion`. The indicator glide / pager slide / height reflow always
  /// animate regardless — those are gesture/layout-driven (see the flagged
  /// §1.4 deviation), not `nib_motion`.
  final bool animated;

  /// Timing/curve for programmatic and settle animations. `null` → ~250ms ease.
  final NibTransition? transition;

  /// Called with the new index whenever the selected tab changes.
  final ValueChanged<int>? onChanged;

  /// Bar background. `null` → `NibTheme.background`. Pass `Colors.transparent`
  /// for no fill (the bar then shows content scrolling behind it).
  final Color? backgroundColor;

  /// Indicator (underline bar / pill) color. `null` → `NibTheme.primary`.
  final Color? indicatorColor;

  /// Active tab label + icon color. `null` → `NibTheme.primary` (or
  /// `primaryForeground` for the `pill` style, which sits on a filled pill).
  final Color? selectedColor;

  /// Idle tab label + icon color. `null` → `NibTheme.mutedForeground`.
  final Color? unselectedColor;

  /// Height of the tab bar. Shrinking it also tightens the gap between the
  /// (vertically-centered) label and an `underline` indicator. Defaults to 44.
  final double barHeight;

  /// Padding around each tab's icon+label. Defaults to 16px horizontal.
  final EdgeInsetsGeometry labelPadding;

  /// Whether to draw the 1px divider under the bar. Defaults to `true`.
  final bool showDivider;

  /// Divider color when [showDivider]. `null` → `NibTheme.border`.
  final Color? dividerColor;

  @override
  State<NibTabs> createState() => _NibTabsState();
}

class _NibTabsState extends State<NibTabs> with SingleTickerProviderStateMixin {
  late final AnimationController _page = AnimationController.unbounded(
    vsync: this,
  );
  final ScrollController _barScroll = ScrollController();

  late NibTabsController _controller;
  late bool _ownsController;

  late int _currentIndex;
  late List<double?> _heights;
  late List<double?> _tabWidths;

  bool _dragging = false;
  double _dragStartPage = 0;
  double _dragAccum = 0;
  double _viewportWidth = 0;

  int get _n => widget.tabs.length;

  @override
  void initState() {
    super.initState();
    _heights = List<double?>.filled(_n, null, growable: true);
    _tabWidths = List<double?>.filled(_n, null, growable: true);
    _bindController(widget.controller);
    _currentIndex = _controller.index.clamp(0, _n - 1);
    _page.value = _currentIndex.toDouble();
  }

  @override
  void didUpdateWidget(covariant NibTabs old) {
    super.didUpdateWidget(old);
    if (widget.controller != old.controller) {
      _unbindController();
      _bindController(widget.controller);
      _currentIndex = _controller.index.clamp(0, _n - 1);
      _page.value = _currentIndex.toDouble();
    }
    if (widget.tabs.length != old.tabs.length) {
      _heights = List<double?>.filled(_n, null, growable: true);
      _tabWidths = List<double?>.filled(_n, null, growable: true);
      _currentIndex = _currentIndex.clamp(0, _n - 1);
      _page.value = _page.value.clamp(0, (_n - 1).toDouble());
    }
  }

  @override
  void dispose() {
    _unbindController();
    _page.dispose();
    _barScroll.dispose();
    super.dispose();
  }

  // --- Controller wiring (mirrors NibAccordion's ownership pattern) ---

  void _bindController(NibTabsController? external) {
    _controller =
        external ?? NibTabsController(initialIndex: widget.initialIndex);
    _ownsController = external == null;
    _controller.addListener(_onController);
  }

  void _unbindController() {
    _controller.removeListener(_onController);
    if (_ownsController) _controller.dispose();
  }

  /// Fires when an *external* (app) `animateTo`/`jumpTo` moves the controller.
  /// Internal tap/swipe changes set [_currentIndex] first, so this early-returns
  /// on their `syncIndex` echo.
  void _onController() {
    final target = _controller.index.clamp(0, _n - 1);
    if (target == _currentIndex) return;
    _goTo(target, animate: _controller.animateOnChange, notify: true);
  }

  // --- Selection ---

  NibTransition get _transition =>
      widget.transition ??
      const NibTransition(duration: Duration(milliseconds: 250));

  Duration get _duration => _transition.duration;

  void _handleUserSelect(int index) {
    final target = index.clamp(0, _n - 1);
    final changed = target != _currentIndex;
    _goTo(target, animate: true, notify: changed);
    if (_controller.index != target) _controller.syncIndex(target);
  }

  void _goTo(int index, {required bool animate, required bool notify}) {
    setState(() => _currentIndex = index);
    if (animate) {
      _page.animateTo(
        index.toDouble(),
        duration: _duration,
        curve: Curves.easeOutCubic,
      );
    } else {
      _page.value = index.toDouble();
    }
    _ensureTabVisibleSoon(index);
    if (notify) widget.onChanged?.call(index);
  }

  // --- Swipe ---

  void _onDragStart(DragStartDetails _) {
    _dragging = true;
    _dragStartPage = _page.value;
    _dragAccum = 0;
    _page.stop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _dragAccum += d.primaryDelta ?? d.delta.dx;
    final unit = _viewportWidth + widget.panelGap;
    if (unit <= 0) return;
    _page.value = (_dragStartPage - _dragAccum / unit).clamp(
      0.0,
      (_n - 1).toDouble(),
    );
  }

  void _onDragEnd(DragEndDetails d) {
    _dragging = false;
    final v = d.primaryVelocity ?? 0;
    final current = _page.value;
    int target;
    if (v < -400) {
      target = current.floor() + 1;
    } else if (v > 400) {
      target = current.ceil() - 1;
    } else {
      target = current.round();
    }
    _handleUserSelect(target);
  }

  // --- Height measurement ---

  void _reportHeight(int index, double height) {
    if (index < 0 || index >= _heights.length) return;
    if (_heights[index] == height) return;
    setState(() => _heights[index] = height);
  }

  double _heightFor(double page) {
    final lo = page.floor().clamp(0, _n - 1);
    final hi = page.ceil().clamp(0, _n - 1);
    final frac = page - page.floor();
    final fallback = _heights[_currentIndex] ?? 0.0;
    final hLo = _heights[lo] ?? fallback;
    final hHi = _heights[hi] ?? hLo;
    return lerpDouble(hLo, hHi, frac) ?? 0.0;
  }

  // --- Bar scroll-into-view (scrollable mode) ---

  void _reportTabWidth(int index, double width) {
    if (index < 0 || index >= _tabWidths.length) return;
    if (_tabWidths[index] == width) return;
    setState(() => _tabWidths[index] = width);
  }

  double _tabLeft(int index) {
    var sum = 0.0;
    for (var i = 0; i < index; i++) {
      sum += _tabWidths[i] ?? 0;
    }
    return sum;
  }

  void _ensureTabVisibleSoon(int index) {
    if (!widget.scrollable) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_barScroll.hasClients) return;
      final left = _tabLeft(index);
      final w = _tabWidths[index] ?? 0;
      final vp = _barScroll.position.viewportDimension;
      final cur = _barScroll.offset;
      var target = cur;
      if (left < cur) {
        target = left;
      } else if (left + w > cur + vp) {
        target = left + w - vp;
      }
      target = target.clamp(
        _barScroll.position.minScrollExtent,
        _barScroll.position.maxScrollExtent,
      );
      if ((target - cur).abs() > 1) {
        _barScroll.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportWidth = constraints.maxWidth;
        return CustomScrollView(
          slivers: [
            if (widget.header != null)
              SliverToBoxAdapter(child: widget.header!),
            SliverPersistentHeader(
              pinned: true,
              delegate: _BarDelegate(
                height: widget.barHeight,
                builder: (c) => _buildBar(theme, constraints.maxWidth),
              ),
            ),
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _page,
                builder: (context, _) => _buildPager(theme),
              ),
            ),
            if (widget.footer != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: widget.panelGap),
                  child: widget.footer!,
                ),
              ),
          ],
        );
      },
    );
  }

  // --- Pager ---

  Widget _buildPager(NibTheme theme) {
    final page = _page.value;
    final settled = !_dragging && (page - page.round()).abs() < 0.001;

    final Widget body;
    if (settled) {
      body = _singlePage(page.round().clamp(0, _n - 1));
    } else {
      final width = _viewportWidth;
      final lo = page.floor().clamp(0, _n - 1);
      final hi = page.ceil().clamp(0, _n - 1);
      final indices = lo == hi ? <int>[lo] : <int>[lo, hi];
      body = SizedBox(
        height: _heightFor(page),
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final i in indices)
                // top + width only → the Stack hands the panel an unbounded
                // vertical constraint, so it lays out at its natural height
                // (measurable), painting past the clipped [SizedBox] height.
                Positioned(
                  top: 0,
                  left: (i - page) * (width + widget.panelGap),
                  width: width,
                  child: _measured(i, _panelContent(i)),
                ),
            ],
          ),
        ),
      );
    }

    if (!widget.swipeable || _n < 2) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: body,
    );
  }

  /// The settled single panel: content-sized (natural height → always correct,
  /// no clip) and measured. No opacity animation here — the panel is revealed by
  /// the slide/height transition, so fading it again on settle would double up
  /// and blink. The `animated` decoration lives on the tab bar (a scale-pop on
  /// the newly-active tab), mirroring `NibAccordion`'s chevron.
  Widget _singlePage(int index) => _measured(index, _panelContent(index));

  Widget _panelContent(int index) => KeyedSubtree(
    key: ValueKey('nib-tab-panel-$index'),
    child: Builder(builder: widget.tabs[index].builder),
  );

  Widget _measured(int index, Widget child) => _MeasureSize(
    onChange: (size) => _reportHeight(index, size.height),
    child: child,
  );

  // --- Bar ---

  Widget _buildBar(NibTheme theme, double width) {
    return Container(
      key: const ValueKey('nib-tabs-bar'),
      height: widget.barHeight,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? theme.background,
        border: widget.showDivider
            ? Border(
                bottom: BorderSide(color: widget.dividerColor ?? theme.border),
              )
            : null,
      ),
      child: widget.scrollable
          ? _scrollableBar(theme)
          : _fixedBar(theme, width),
    );
  }

  Widget _fixedBar(NibTheme theme, double width) {
    final slot = _n == 0 ? width : width / _n;
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _page,
          builder: (_, _) => _indicator(theme, (i) => i * slot, (i) => slot),
        ),
        // Positioned.fill makes the tab Row fill the full bar height, so each
        // tab's content is vertically centered (not pinned to the top).
        Positioned.fill(
          child: Row(
            children: [
              for (var i = 0; i < _n; i++)
                Expanded(child: _tabButton(theme, i, expand: true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scrollableBar(NibTheme theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _barScroll,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _page,
            builder: (_, _) =>
                _indicator(theme, _tabLeft, (i) => _tabWidths[i] ?? 0),
          ),
          Row(
            children: [
              for (var i = 0; i < _n; i++)
                _MeasureSize(
                  onChange: (s) => _reportTabWidth(i, s.width),
                  child: _tabButton(theme, i, expand: false),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _indicator(
    NibTheme theme,
    double Function(int) leftOf,
    double Function(int) widthOf,
  ) {
    if (widget.indicatorStyle == NibTabsIndicatorStyle.none) {
      return const SizedBox.shrink();
    }
    final page = _page.value.clamp(0.0, (_n - 1).toDouble());
    final lo = page.floor();
    final hi = page.ceil();
    final frac = page - lo;
    final left = lerpDouble(leftOf(lo), leftOf(hi), frac) ?? leftOf(lo);
    final w = lerpDouble(widthOf(lo), widthOf(hi), frac) ?? widthOf(lo);
    if (w <= 0) return const SizedBox.shrink();
    final color = widget.indicatorColor ?? theme.primary;

    if (widget.indicatorStyle == NibTabsIndicatorStyle.pill) {
      const pad = 6.0;
      return Positioned(
        left: left + pad,
        width: (w - 2 * pad).clamp(0, double.infinity),
        top: pad,
        bottom: pad,
        child: DecoratedBox(
          key: const ValueKey('nib-tabs-indicator'),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(theme.radiusPill),
          ),
        ),
      );
    }

    // underline
    const inset = 10.0;
    final underlineW = (w - 2 * inset).clamp(0, double.infinity).toDouble();
    return Positioned(
      left: left + (w - underlineW) / 2,
      width: underlineW,
      bottom: 0,
      height: 2.5,
      child: DecoratedBox(
        key: const ValueKey('nib-tabs-indicator'),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
      ),
    );
  }

  Widget _tabButton(NibTheme theme, int index, {required bool expand}) {
    final tab = widget.tabs[index];
    final activeColor =
        widget.selectedColor ??
        (widget.indicatorStyle == NibTabsIndicatorStyle.pill
            ? theme.primaryForeground
            : theme.primary);
    final idleColor = widget.unselectedColor ?? theme.mutedForeground;

    return InkWell(
      onTap: () => _handleUserSelect(index),
      child: AnimatedBuilder(
        animation: _page,
        builder: (_, _) {
          final nearness = (1 - (_page.value - index).abs()).clamp(0.0, 1.0);
          final color = Color.lerp(idleColor, activeColor, nearness)!;
          final label = Text(
            tab.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          );
          final row = Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (tab.icon != null) ...[
                Icon(tab.icon, size: 18, color: color),
                const SizedBox(width: 8),
              ],
              // Only flex when the tab has a bounded (equal-share) width; in the
              // scrollable bar tabs take intrinsic width, where Flexible can't.
              if (expand) Flexible(child: label) else label,
            ],
          );
          final padded = Padding(padding: widget.labelPadding, child: row);
          // Fixed tabs fill the bar height via Positioned.fill (centered by the
          // Row); scrollable tabs size to content, so pin them to bar height.
          final content = expand
              ? padded
              : SizedBox(
                  height: widget.barHeight,
                  child: Center(child: padded),
                );

          if (!widget.animated) return content;
          // Decorative `nib_motion` (the flagged §1.4 opt-in, cf. Accordion's
          // chevron): the newly-active tab pops in via a scale. Keying by
          // active-ness replays it only when this tab *becomes* active; inactive
          // tabs mount at identity, so nothing pops on them. `animated:false`
          // builds zero NibMotion.
          final active = index == _currentIndex;
          return NibMotion(
            key: ValueKey('nib-tab-pop-$index-$active'),
            initial: NibAnim(scale: active ? 0.85 : 1.0),
            animate: NibAnim.identity,
            transition: _transition,
            child: content,
          );
        },
      ),
    );
  }
}

/// Pinned-bar sliver delegate. The bar is cheap, so it rebuilds whenever the host
/// [State] rebuilds; the indicator animates via an inner [AnimatedBuilder] without
/// relaying the sliver out.
class _BarDelegate extends SliverPersistentHeaderDelegate {
  _BarDelegate({required this.height, required this.builder});

  final double height;
  final WidgetBuilder builder;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => builder(context);

  @override
  bool shouldRebuild(covariant _BarDelegate old) => true;
}

/// Reports its child's laid-out size after each layout. Used to drive the pager's
/// adaptive height and (in scrollable mode) the indicator's per-tab width.
typedef _SizeCallback = void Function(Size size);

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required Widget super.child});

  final _SizeCallback onChange;

  @override
  _RenderMeasureSize createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  _SizeCallback onChange;
  Size? _old;

  @override
  void performLayout() {
    super.performLayout();
    final size = child?.size ?? Size.zero;
    if (size != _old) {
      _old = size;
      WidgetsBinding.instance.addPostFrameCallback((_) => onChange(size));
    }
  }
}
