import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibTransition;

import '../button/nib_button.dart';
import '../button/nib_button_types.dart';
import '../theme/nib_theme.dart';
import 'nib_toggle_group_types.dart';

class _NibToggleMoveIntent extends Intent {
  const _NibToggleMoveIntent(this.step);
  final int step;
}

/// A row of segments where one ([NibToggleGroup.new]) or several
/// ([NibToggleGroup.multiple]) can be pressed at once — each segment is a
/// [NibButton], so it inherits focus/ripple/tap-target/semantics for free.
///
/// Roving-tabindex keyboard model: the group has **one** tab stop; arrow
/// keys move focus between segments (wrapping past the ends, skipping
/// disabled ones) without changing selection, and Enter/Space/tap toggles
/// the focused segment — matching a native toolbar's toggle-button group,
/// not a radio group (arrows don't auto-select here).
///
/// ```dart
/// NibToggleGroup<String>(
///   options: const [
///     NibToggleOption(value: 'left', icon: Icon(Icons.format_align_left)),
///     NibToggleOption(value: 'center', icon: Icon(Icons.format_align_center)),
///   ],
///   value: align,
///   onChanged: (v) => setState(() => align = v),
/// )
/// NibToggleGroup<String>.multiple(
///   options: const [
///     NibToggleOption(value: 'bold', label: 'B'),
///     NibToggleOption(value: 'italic', label: 'I'),
///   ],
///   values: activeStyles,
///   onChanged: (v) => setState(() => activeStyles = v),
/// )
/// ```
class NibToggleGroup<T> extends StatefulWidget {
  /// A single-select toggle group (controlled via [value]/[onChanged]).
  /// Pressing the already-selected segment deselects it back to `null`.
  const NibToggleGroup({
    super.key,
    required this.options,
    required T? value,
    ValueChanged<T?>? onChanged,
    this.direction = Axis.horizontal,
    this.disabled = false,
    this.size = NibButtonSize.md,
    this.itemWidth,
    this.fillWidth = false,
    this.spacing,
    this.animated = false,
    this.transition,
    this.semanticLabel,
    this.autofocus = false,
  }) : _multiple = false,
       // Public param must be named `value`; the field is `_value`.
       // ignore: prefer_initializing_formals
       _value = value,
       _values = null,
       _onChangedSingle = onChanged,
       _onChangedMultiple = null;

  /// A multi-select toggle group (controlled via [values]/[onChanged]) —
  /// each segment toggles independently.
  const NibToggleGroup.multiple({
    super.key,
    required this.options,
    required Set<T> values,
    ValueChanged<Set<T>>? onChanged,
    this.direction = Axis.horizontal,
    this.disabled = false,
    this.size = NibButtonSize.md,
    this.itemWidth,
    this.fillWidth = false,
    this.spacing,
    this.animated = false,
    this.transition,
    this.semanticLabel,
    this.autofocus = false,
  }) : _multiple = true,
       _value = null,
       // Public param must be named `values`; the field is `_values`.
       // ignore: prefer_initializing_formals
       _values = values,
       _onChangedSingle = null,
       _onChangedMultiple = onChanged;

  /// The segments.
  final List<NibToggleOption<T>> options;

  final bool _multiple;
  final T? _value;
  final Set<T>? _values;
  final ValueChanged<T?>? _onChangedSingle;
  final ValueChanged<Set<T>>? _onChangedMultiple;

  /// Stack the segments vertically (default horizontal, wrapping instead of
  /// overflowing at narrow widths).
  final Axis direction;

  /// Disables every segment regardless of their own
  /// [NibToggleOption.disabled].
  final bool disabled;

  /// Size preset shared by every segment's [NibButton].
  final NibButtonSize size;

  /// Fixed width applied to every segment. `null` sizes each to its content.
  final double? itemWidth;

  /// Gives horizontal segments equal shares of the available width. The
  /// parent must provide a finite width. Ignored for vertical groups.
  final bool fillWidth;

  /// Gap between segments. Defaults to 8.
  final double? spacing;

  /// Opt-in `nib_motion`: a newly-selected segment pops in. `false` builds
  /// **zero** [NibMotion].
  final bool animated;

  /// Timing/curve for [animated]. `null` → a short ~150ms ease.
  final NibTransition? transition;

  /// Accessible name for the whole group.
  final String? semanticLabel;

  /// Autofocuses the group's single tab stop on first build.
  final bool autofocus;

  bool _isSelected(T value) =>
      _multiple ? (_values?.contains(value) ?? false) : _value == value;

  @override
  State<NibToggleGroup<T>> createState() => _NibToggleGroupState<T>();
}

class _NibToggleGroupState<T> extends State<NibToggleGroup<T>> {
  List<FocusNode> _nodes = [];
  List<VoidCallback> _listeners = [];
  int _tabStopIndex = 0;

  @override
  void initState() {
    super.initState();
    _buildNodes();
  }

  void _buildNodes() {
    _nodes = List.generate(
      widget.options.length,
      (_) => FocusNode(debugLabel: 'nib-toggle-option'),
    );
    _listeners = List.generate(_nodes.length, (i) {
      void listener() {
        if (_nodes[i].hasFocus) setState(() => _tabStopIndex = i);
      }

      _nodes[i].addListener(listener);
      return listener;
    });
    _tabStopIndex = _initialTabStop();
  }

  void _disposeNodes() {
    for (var i = 0; i < _nodes.length; i++) {
      _nodes[i].removeListener(_listeners[i]);
      _nodes[i].dispose();
    }
  }

  int _initialTabStop() {
    for (var i = 0; i < widget.options.length; i++) {
      final option = widget.options[i];
      if (!option.disabled && widget._isSelected(option.value)) return i;
    }
    final firstEnabled = widget.options.indexWhere((o) => !o.disabled);
    return firstEnabled == -1 ? 0 : firstEnabled;
  }

  @override
  void didUpdateWidget(covariant NibToggleGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.length != widget.options.length) {
      _disposeNodes();
      _buildNodes();
    }
  }

  @override
  void dispose() {
    _disposeNodes();
    super.dispose();
  }

  double get _spacing => widget.spacing ?? 8;

  NibTransition get _transition =>
      widget.transition ??
      const NibTransition(duration: Duration(milliseconds: 150));

  bool _rowEnabled(int index) {
    final onChanged = widget._multiple
        ? widget._onChangedMultiple != null
        : widget._onChangedSingle != null;
    return !widget.disabled && onChanged && !widget.options[index].disabled;
  }

  void _toggle(int index) {
    if (!_rowEnabled(index)) return;
    final option = widget.options[index];
    if (widget._multiple) {
      final current = widget._values ?? const {};
      final next = Set<T>.from(current);
      if (!next.remove(option.value)) next.add(option.value);
      widget._onChangedMultiple!(next);
    } else {
      widget._onChangedSingle!(
        widget._value == option.value ? null : option.value,
      );
    }
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

  void _moveFocus(int step) {
    final target = _siblingEnabled(_tabStopIndex, step);
    if (target != null) _nodes[target].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    for (var i = 0; i < _nodes.length; i++) {
      _nodes[i].skipTraversal = i != _tabStopIndex;
    }

    final cells = [
      for (var i = 0; i < widget.options.length; i++) _buildCell(theme, i),
    ];

    final Widget row = widget.direction == Axis.horizontal
        ? widget.fillWidth
              ? Row(
                  children: [
                    for (var i = 0; i < cells.length; i++) ...[
                      if (i > 0) SizedBox(width: _spacing),
                      Expanded(child: cells[i]),
                    ],
                  ],
                )
              : Wrap(spacing: _spacing, runSpacing: _spacing, children: cells)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cells.length; i++) ...[
                if (i > 0) SizedBox(height: _spacing),
                cells[i],
              ],
            ],
          );

    final body = Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowRight): _NibToggleMoveIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowDown): _NibToggleMoveIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _NibToggleMoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _NibToggleMoveIntent(-1),
      },
      child: Actions(
        actions: {
          _NibToggleMoveIntent: CallbackAction<_NibToggleMoveIntent>(
            onInvoke: (intent) {
              _moveFocus(intent.step);
              return null;
            },
          ),
        },
        child: row,
      ),
    );

    if (widget.semanticLabel == null) return body;
    return Semantics(container: true, label: widget.semanticLabel, child: body);
  }

  Widget _buildCell(NibTheme theme, int index) {
    final option = widget.options[index];
    final selected = widget._isSelected(option.value);
    final enabled = _rowEnabled(index);
    final isTabStop = index == _tabStopIndex;

    Widget button = NibButton(
      label: option.label,
      leadingIcon: option.icon,
      variant: selected ? NibButtonVariant.primary : NibButtonVariant.outline,
      size: widget.size,
      width: widget.itemWidth,
      semanticLabel: option.semanticLabel,
      toggled: selected,
      focusNode: _nodes[index],
      autofocus: widget.autofocus && isTabStop,
      onPressed: enabled ? () => _toggle(index) : null,
    );

    if (widget.animated && selected) {
      button = NibMotion(
        initial: const NibAnim(scale: 0.9),
        animate: NibAnim.identity,
        transition: _transition,
        child: button,
      );
    }

    return button;
  }
}
