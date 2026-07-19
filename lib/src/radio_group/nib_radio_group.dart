import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibTransition;

import '../theme/nib_theme.dart';
import 'nib_radio_group_types.dart';

/// A single-select group of radio options with roving-tabindex keyboard
/// navigation — one tab stop for the whole group, arrow keys move (and
/// select) between options, matching native `<input type="radio">` groups.
///
/// Controlled, like [NibTheme]'s other inputs: the group's entire state is
/// its [value], already owned by the [value]/[onChanged] pair, so there is
/// no separate controller.
///
/// ```dart
/// NibRadioGroup<String>(
///   options: const [
///     NibRadioOption(value: 'a', label: 'Alpha'),
///     NibRadioOption(value: 'b', label: 'Beta'),
///   ],
///   value: selected,
///   onChanged: (v) => setState(() => selected = v),
/// )
/// ```
class NibRadioGroup<T> extends StatefulWidget {
  /// Creates a radio group.
  const NibRadioGroup({
    super.key,
    required this.options,
    required this.value,
    this.onChanged,
    this.direction = Axis.vertical,
    this.disabled = false,
    this.spacing,
    this.dotSize,
    this.activeColor,
    this.contentPadding,
    this.optionBuilder,
    this.animated = false,
    this.transition,
    this.semanticLabel,
    this.autofocus = false,
  });

  /// The selectable options.
  final List<NibRadioOption<T>> options;

  /// The currently selected value, or `null` when nothing is selected.
  final T? value;

  /// Called with the newly selected value. `null` renders the whole group
  /// disabled.
  final ValueChanged<T>? onChanged;

  /// Stack the options vertically (default) or flow them horizontally
  /// (wrapping instead of overflowing at narrow widths).
  final Axis direction;

  /// Disables every option regardless of their own [NibRadioOption.disabled].
  final bool disabled;

  /// Gap between options. Defaults to 12.
  final double? spacing;

  /// Diameter of the radio dot. Defaults to 20.
  final double? dotSize;

  /// The selected ring/dot colour. Defaults to `NibTheme.primary`.
  final Color? activeColor;

  /// Padding around each option row's content. Defaults to
  /// `EdgeInsets.symmetric(vertical: 8, horizontal: 4)`.
  final EdgeInsetsGeometry? contentPadding;

  /// Replaces the default dot+label row with a fully custom widget. The
  /// group still owns tap/ripple/focus/keyboard for that option.
  final NibRadioOptionBuilder<T>? optionBuilder;

  /// Opt-in `nib_motion`: the selected dot pops in. `false` builds **zero**
  /// [NibMotion].
  final bool animated;

  /// Timing/curve for [animated]. `null` → a short ~150ms ease.
  final NibTransition? transition;

  /// Accessible name for the whole group.
  final String? semanticLabel;

  /// Autofocuses the group's single tab stop (the selected option, or the
  /// first enabled one) on first build.
  final bool autofocus;

  @override
  State<NibRadioGroup<T>> createState() => _NibRadioGroupState<T>();
}

class _NibRadioGroupState<T> extends State<NibRadioGroup<T>> {
  List<FocusNode> _nodes = [];

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(
      widget.options.length,
      (_) => FocusNode(debugLabel: 'nib-radio-option'),
    );
  }

  @override
  void didUpdateWidget(covariant NibRadioGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.length != widget.options.length) {
      for (final node in _nodes) {
        node.dispose();
      }
      _nodes = List.generate(
        widget.options.length,
        (_) => FocusNode(debugLabel: 'nib-radio-option'),
      );
    }
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  double get _spacing => widget.spacing ?? 12;

  NibTransition get _transition =>
      widget.transition ??
      const NibTransition(duration: Duration(milliseconds: 150));

  bool _rowEnabled(int index) =>
      !widget.disabled &&
      widget.onChanged != null &&
      !widget.options[index].disabled;

  int _tabStopIndex() {
    if (widget.options.isEmpty) return -1;
    if (widget.value != null) {
      final selected = widget.options.indexWhere(
        (o) => o.value == widget.value && !o.disabled,
      );
      if (selected != -1) return selected;
    }
    return widget.options.indexWhere((o) => !o.disabled);
  }

  int? _siblingEnabled(int from, int step) {
    final n = widget.options.length;
    if (n == 0) return null;
    var i = from;
    for (var count = 0; count < n; count++) {
      i = (i + step) % n;
      if (i < 0) i += n;
      if (!widget.options[i].disabled) return i;
    }
    return null;
  }

  void _select(int index, {bool requestFocus = false}) {
    if (!_rowEnabled(index)) return;
    if (requestFocus) _nodes[index].requestFocus();
    final option = widget.options[index];
    if (option.value == widget.value) return;
    widget.onChanged!(option.value);
  }

  KeyEventResult _handleKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _select(index);
      return KeyEventResult.handled;
    }

    int? target;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowRight) {
      target = _siblingEnabled(index, 1);
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowLeft) {
      target = _siblingEnabled(index, -1);
    }
    if (target == null) return KeyEventResult.ignored;

    _select(target, requestFocus: true);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final tabStop = _tabStopIndex();
    final rows = [
      for (var i = 0; i < widget.options.length; i++)
        _buildOption(context, theme, i, i == tabStop),
    ];

    final Widget body;
    if (widget.direction == Axis.horizontal) {
      body = Wrap(
        spacing: _spacing,
        runSpacing: _spacing,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: rows,
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: _spacing),
            rows[i],
          ],
        ],
      );
    }

    if (widget.semanticLabel == null) return body;
    return Semantics(container: true, label: widget.semanticLabel, child: body);
  }

  Widget _buildOption(
    BuildContext context,
    NibTheme theme,
    int index,
    bool isTabStop,
  ) {
    final option = widget.options[index];
    final selected = widget.value != null && widget.value == option.value;
    final enabled = _rowEnabled(index);

    final content = widget.optionBuilder != null
        ? widget.optionBuilder!(context, option, selected, !enabled)
        : _defaultRow(theme, option, selected, enabled);

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      label: option.label,
      child: Focus(
        focusNode: _nodes[index],
        skipTraversal: !isTabStop,
        autofocus: widget.autofocus && isTabStop,
        onKeyEvent: (node, event) => _handleKey(index, event),
        child: InkWell(
          onTap: enabled ? () => _select(index, requestFocus: true) : null,
          borderRadius: BorderRadius.circular(theme.radiusDefault),
          child: content,
        ),
      ),
    );
  }

  Widget _defaultRow(
    NibTheme theme,
    NibRadioOption<T> option,
    bool selected,
    bool enabled,
  ) {
    final labelColor = enabled ? theme.foreground : theme.mutedForeground;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.centerLeft,
      padding:
          widget.contentPadding ??
          const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildDot(theme, selected, enabled),
          const SizedBox(width: 10),
          if (option.leading != null) ...[
            option.leading!,
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.label,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (option.description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      option.description!,
                      style: TextStyle(
                        color: theme.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(NibTheme theme, bool selected, bool enabled) {
    final size = widget.dotSize ?? 20;
    final ringColor = !enabled
        ? theme.border
        : selected
        ? (widget.activeColor ?? theme.primary)
        : theme.mutedForeground;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2),
      ),
      child: selected ? _buildInnerDot(theme, size, enabled) : null,
    );
  }

  Widget _buildInnerDot(NibTheme theme, double outerSize, bool enabled) {
    final dotColor = enabled
        ? (widget.activeColor ?? theme.primary)
        : theme.mutedForeground;
    final inner = Container(
      width: outerSize * 0.5,
      height: outerSize * 0.5,
      decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
    );
    if (!widget.animated) return inner;
    return NibMotion(
      initial: const NibAnim(scale: 0),
      animate: const NibAnim(scale: 1),
      transition: _transition,
      child: inner,
    );
  }
}
