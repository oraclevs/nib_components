import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:nib_motion/nib_motion.dart' show NibAnim, NibMotion, NibTransition;

import '../loader/nib_circular_loader.dart';
import '../theme/nib_theme.dart';
import 'nib_button_types.dart';

/// The minimum interactive target, per the a11y contract (MASTER_PROMPT §1.1).
/// The button's *visual* box may be shorter (e.g. an `sm` 36px pill); the tap
/// area is padded up to this without changing what's painted.
const double _kMinTapTarget = 48;

/// A native, token-driven button.
///
/// Simple by default — `NibButton(label: 'Save', onPressed: ...)` already looks
/// finished — with five [NibButtonVariant]s, three [NibButtonSize] presets, and
/// opt-in `nib_motion` on tap.
///
/// All variants share identical box geometry for a given size: a filled and an
/// outline button of the same `height`/`width` render at the **same** footprint
/// and inner content position, because every variant reserves the same 1px
/// border inset (drawn *inside* the bounds) and the focus ring is a
/// layout-neutral overlay.
///
/// ```dart
/// NibButton(label: 'Save', onPressed: () {})                       // primary
/// NibButton(label: 'Cancel', variant: NibButtonVariant.outline, onPressed: () {})
/// NibButton(onPressed: () {}, leadingIcon: Icon(Icons.add), semanticLabel: 'Add')
/// ```
class NibButton extends StatefulWidget {
  const NibButton({
    super.key,
    this.label,
    required this.onPressed,
    this.variant = NibButtonVariant.primary,
    this.size = NibButtonSize.md,
    this.height,
    this.width,
    this.padding,
    this.borderRadius,
    this.loading = false,
    this.disabled = false,
    this.leadingIcon,
    this.trailingIcon,
    this.content,
    this.expand = false,
    this.pill = false,
    this.tooltip,
    this.semanticLabel,
    this.toggled,
    this.focusNode,
    this.autofocus = false,
    this.animated = false,
    this.transition,
    this.loadingWidget,
    this.loadingText,
  })  : assert(
          content != null ||
              label != null ||
              leadingIcon != null ||
              trailingIcon != null,
          'NibButton needs content, a label, and/or at least one icon to render.',
        ),
        assert(
          label != null || content != null || semanticLabel != null,
          'An icon-only NibButton (no label, no content) requires a '
          'semanticLabel for accessibility.',
        );

  /// The button text. `null` renders an icon-only button (requires
  /// [semanticLabel]).
  final String? label;

  /// Tapped/activated callback. `null` renders the button disabled.
  final VoidCallback? onPressed;

  /// Visual style. Defaults to [NibButtonVariant.primary].
  final NibButtonVariant variant;

  /// Size preset (drives default height, text/icon size, padding).
  final NibButtonSize size;

  /// Exact visual box height, overriding [size]'s default. The ≥48 tap target
  /// is preserved independently, so a custom `44` still renders `44`.
  final double? height;

  /// Exact visual box width. `null` ⇒ content-sized (or square when icon-only,
  /// or full-width when [expand]).
  final double? width;

  /// Content padding. `null` ⇒ the [size] preset's horizontal padding (and zero
  /// for icon-only). Set it — including `EdgeInsets.zero` — to take full control.
  final EdgeInsetsGeometry? padding;

  /// Corner radius of the box (and its ripple/focus ring). `null` ⇒ the pill
  /// radius when [pill], otherwise the default radius. Overrides [pill] when set.
  final BorderRadius? borderRadius;

  /// Shows a built-in [NibCircularLoader] in place of the content and blocks
  /// taps. Override the spinner with [loadingWidget].
  final bool loading;

  /// Disables interaction and dims the button. [onPressed] `== null` does the
  /// same.
  final bool disabled;

  /// Optional icon before the label.
  final Widget? leadingIcon;

  /// Optional icon after the label.
  final Widget? trailingIcon;

  /// A fully custom child, replacing the built-in [leadingIcon]/[label]/
  /// [trailingIcon] layout. When set, the button still owns tap/ripple/focus,
  /// shape ([borderRadius]/[pill]), sizing, [padding], and the [loading]
  /// overlay — you own everything inside. Style-defaults ([NibTheme] foreground
  /// on plain `Text`/`Icon`) still apply but any explicit style you set wins.
  final Widget? content;

  /// Stretch to the parent's full width.
  final bool expand;

  /// Use the pill (fully-rounded) radius instead of the default radius.
  final bool pill;

  /// Optional hover/long-press tooltip.
  final String? tooltip;

  /// Accessible name. Required when [label] is `null`; overrides the label for
  /// screen readers when both are set.
  final String? semanticLabel;

  /// Marks this button as a toggle/pressed control for assistive tech
  /// (`SemanticsFlag.isToggled`) — e.g. a segment in `NibToggleGroup`.
  /// `null` (the default) omits the flag entirely, matching a plain button.
  final bool? toggled;

  /// Optional external focus node.
  final FocusNode? focusNode;

  /// Whether to focus this button on mount.
  final bool autofocus;

  /// Opt-in `nib_motion` tap scale-pop. `false` builds **zero** [NibMotion]
  /// (ripple/press feedback still work — that's native, not motion).
  final bool animated;

  /// Timing/curve for the [animated] tap pop. `null` → a short ~120ms ease.
  final NibTransition? transition;

  /// Replaces the built-in [NibCircularLoader] while [loading]. Combine with
  /// [loadingText] to show a custom indicator *and* a label.
  final Widget? loadingWidget;

  /// Optional text shown beside the loading indicator (the default spinner, or
  /// [loadingWidget] if given). Lets a loading button read "⟳ Saving…". Any of
  /// text-only, widget-only, or both is valid.
  final String? loadingText;

  @override
  State<NibButton> createState() => _NibButtonState();
}

class _NibButtonState extends State<NibButton> {
  FocusNode? _internalNode;
  bool _focused = false;
  int _tapCount = 0;

  FocusNode get _effectiveNode =>
      widget.focusNode ?? (_internalNode ??= FocusNode());

  bool get _interactive =>
      !widget.disabled && !widget.loading && widget.onPressed != null;

  bool get _iconOnly => widget.label == null && widget.content == null;

  NibTransition get _transition =>
      widget.transition ??
      const NibTransition(duration: Duration(milliseconds: 120));

  @override
  void dispose() {
    _internalNode?.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!_interactive) return;
    setState(() => _tapCount++);
    widget.onPressed!();
  }

  _VariantColors _colorsFor(NibTheme theme) {
    switch (widget.variant) {
      case NibButtonVariant.primary:
        return _VariantColors(
          fill: theme.primary,
          foreground: theme.primaryForeground,
          border: Colors.transparent,
          hover: Colors.black.withValues(alpha: 0.08),
        );
      case NibButtonVariant.secondary:
        return _VariantColors(
          fill: theme.secondary,
          foreground: theme.secondaryForeground,
          border: Colors.transparent,
          hover: theme.secondaryForeground.withValues(alpha: 0.06),
        );
      case NibButtonVariant.outline:
        return _VariantColors(
          fill: Colors.transparent,
          foreground: theme.foreground,
          border: theme.border,
          hover: theme.muted,
        );
      case NibButtonVariant.ghost:
        return _VariantColors(
          fill: Colors.transparent,
          foreground: theme.foreground,
          border: Colors.transparent,
          hover: theme.muted,
        );
      case NibButtonVariant.destructive:
        return _VariantColors(
          fill: theme.destructive,
          foreground: const Color(0xFFFFFFFF),
          border: Colors.transparent,
          hover: Colors.black.withValues(alpha: 0.1),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final metrics = NibButtonSizeMetrics.of(widget.size);
    final colors = _colorsFor(theme);

    final height = widget.height ?? metrics.height;
    final radius = widget.borderRadius ??
        BorderRadius.circular(
          widget.pill ? theme.radiusPill : theme.radiusDefault,
        );
    final padding = widget.padding ??
        EdgeInsets.symmetric(
          horizontal: _iconOnly ? 0 : metrics.horizontalPadding,
        );

    // Content: the icon(s)/label, or — while loading — the loading indicator
    // overlaid on the *invisible-but-space-reserving* normal content, so the
    // button never shrinks when the loader appears.
    final Widget normalContent = _buildContent(metrics, colors.foreground);
    final Widget content = widget.loading
        ? Stack(
            alignment: Alignment.center,
            children: [
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: ExcludeSemantics(child: normalContent),
              ),
              _buildLoadingContent(metrics, colors.foreground),
            ],
          )
        : normalContent;

    final double? resolvedWidth = widget.width ??
        (_iconOnly ? height : (widget.expand ? double.infinity : null));

    Widget box = SizedBox(
      height: height,
      width: resolvedWidth,
      child: DecoratedBox(
        // The 1px border is reserved on *every* variant (transparent where not
        // outline) so all variants share the exact same inner content box.
        decoration: BoxDecoration(
          color: colors.fill,
          borderRadius: radius,
          border: Border.all(color: colors.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: _interactive ? _handleTap : null,
            focusNode: _effectiveNode,
            autofocus: widget.autofocus,
            canRequestFocus: _interactive,
            onFocusChange: (f) => setState(() => _focused = f),
            customBorder: RoundedRectangleBorder(borderRadius: radius),
            hoverColor: colors.hover,
            highlightColor: colors.foreground.withValues(alpha: 0.06),
            splashColor: colors.foreground.withValues(alpha: 0.12),
            mouseCursor: _interactive
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: Padding(
              padding: padding,
              child: Center(widthFactor: 1, heightFactor: 1, child: content),
            ),
          ),
        ),
      ),
    );

    // Dim only for the disabled/null state — a loading button stays full-opacity
    // (the loader itself signals busy).
    final bool dimmed =
        (widget.disabled || widget.onPressed == null) && !widget.loading;
    if (dimmed) box = Opacity(opacity: 0.5, child: box);

    // Opt-in tap scale-pop. Keyed by tap count so it replays on each tap; the
    // first build uses identity so the button doesn't pop on mount.
    if (widget.animated) {
      box = NibMotion(
        key: ValueKey(_tapCount),
        initial: _tapCount == 0 ? NibAnim.identity : const NibAnim(scale: 0.94),
        animate: NibAnim.identity,
        transition: _transition,
        child: box,
      );
    }

    // Focus ring — a layout-neutral overlay (painted outside the box via a
    // negative Positioned in a non-clipping Stack), equal for all variants.
    final Widget ringed = Stack(
      clipBehavior: Clip.none,
      children: [
        box,
        if (_focused && _interactive)
          Positioned(
            left: -3,
            top: -3,
            right: -3,
            bottom: -3,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: theme.ring, width: 2),
                ),
              ),
            ),
          ),
      ],
    );

    Widget result = _TapTargetPadding(
      minSize: const Size(_kMinTapTarget, _kMinTapTarget),
      child: ringed,
    );

    result = MergeSemantics(
      child: Semantics(
        button: true,
        enabled: _interactive,
        // `null` for text buttons → the label Text supplies the accessible name.
        label: widget.semanticLabel,
        toggled: widget.toggled,
        child: result,
      ),
    );

    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }
    return result;
  }

  /// The loading indicator (custom [NibButton.loadingWidget] or the default
  /// spinner) plus an optional [NibButton.loadingText] beside it. Any of
  /// text-only, widget-only, or both is supported.
  Widget _buildLoadingContent(NibButtonSizeMetrics metrics, Color foreground) {
    final Widget indicator = widget.loadingWidget ??
        NibCircularLoader(
          size: metrics.fontSize + 6,
          strokeWidth: 2,
          color: foreground,
        );

    if (widget.loadingText == null) return indicator;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        indicator,
        SizedBox(width: metrics.gap),
        Flexible(
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: foreground,
              fontSize: metrics.fontSize,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
            child: Text(
              widget.loadingText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(NibButtonSizeMetrics metrics, Color foreground) {
    final iconTheme = IconThemeData(color: foreground, size: metrics.iconSize);

    // A fully custom child wins over the built-in icon/label layout. Merge the
    // variant defaults so a bare Text/Icon looks right; the consumer's own
    // styles still take precedence.
    if (widget.content != null) {
      return IconTheme.merge(
        data: iconTheme,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground, fontSize: metrics.fontSize),
          child: widget.content!,
        ),
      );
    }

    if (_iconOnly) {
      final icon = widget.leadingIcon ?? widget.trailingIcon!;
      return IconTheme.merge(data: iconTheme, child: icon);
    }

    final label = DefaultTextStyle.merge(
      style: TextStyle(
        color: foreground,
        fontSize: metrics.fontSize,
        fontWeight: FontWeight.w600,
        height: 1.0,
      ),
      child: Flexible(
        child: Text(
          widget.label!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.leadingIcon != null) ...[
          IconTheme.merge(data: iconTheme, child: widget.leadingIcon!),
          SizedBox(width: metrics.gap),
        ],
        label,
        if (widget.trailingIcon != null) ...[
          SizedBox(width: metrics.gap),
          IconTheme.merge(data: iconTheme, child: widget.trailingIcon!),
        ],
      ],
    );
  }
}

class _VariantColors {
  const _VariantColors({
    required this.fill,
    required this.foreground,
    required this.border,
    required this.hover,
  });

  final Color fill;
  final Color foreground;
  final Color border;
  final Color hover;
}

/// Enlarges the *hit-test* region up to [minSize] without changing what the
/// child paints or how large it lays out visually — the child is centred and
/// taps anywhere within the padded box are forwarded to it. This is Flutter's
/// own `_InputPadding` idiom (used by Material buttons for `MaterialTapTargetSize`).
class _TapTargetPadding extends SingleChildRenderObjectWidget {
  const _TapTargetPadding({required this.minSize, super.child});

  final Size minSize;

  @override
  _RenderTapTargetPadding createRenderObject(BuildContext context) =>
      _RenderTapTargetPadding(minSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTapTargetPadding renderObject,
  ) {
    renderObject.minSize = minSize;
  }
}

class _RenderTapTargetPadding extends RenderShiftedBox {
  _RenderTapTargetPadding(this._minSize) : super(null);

  Size get minSize => _minSize;
  Size _minSize;
  set minSize(Size value) {
    if (_minSize == value) return;
    _minSize = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(child?.getMinIntrinsicWidth(height) ?? 0.0, minSize.width);

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(child?.getMinIntrinsicHeight(width) ?? 0.0, minSize.height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.max(child?.getMaxIntrinsicWidth(height) ?? 0.0, minSize.width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(child?.getMaxIntrinsicHeight(width) ?? 0.0, minSize.height);

  Size _computeSize({
    required BoxConstraints constraints,
    required ChildLayouter layoutChild,
  }) {
    if (child != null) {
      final Size childSize = layoutChild(child!, constraints);
      final double width = math.max(childSize.width, minSize.width);
      final double height = math.max(childSize.height, minSize.height);
      return constraints.constrain(Size(width, height));
    }
    return Size.zero;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _computeSize(
        constraints: constraints,
        layoutChild: ChildLayoutHelper.dryLayoutChild,
      );

  @override
  void performLayout() {
    size = _computeSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.layoutChild,
    );
    if (child != null) {
      final BoxParentData childParentData = child!.parentData! as BoxParentData;
      childParentData.offset =
          Alignment.center.alongOffset(size - child!.size as Offset);
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final Offset center = child!.size.center(Offset.zero);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(center),
      position: center,
      hitTest: (BoxHitTestResult result, Offset position) {
        assert(position == center);
        return child!.hitTest(result, position: center);
      },
    );
  }
}
