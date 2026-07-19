import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibTransition;

import '../theme/nib_theme.dart';
import 'nib_slider_types.dart';

/// Minimum interactive cross-axis thickness (a11y tap target, MASTER_PROMPT
/// §1.1). The visible track is thinner; the band is padded up to this.
const double _kMinTapTarget = 48;

/// Reserved cross-axis lane for the value-label bubble. Constant whether or not
/// a drag is in progress, so the slider never changes size on interaction
/// (see the customization mandate: no resize on internal state).
const double _kLabelLane = 30;

/// A native, token-driven slider with an optional two-thumb range mode.
///
/// Simple by default — `NibSlider(value: v, onChanged: ...)` — with opt-in tick
/// marks ([divisions]), a value label ([showValueLabel]), vertical [axis], and
/// full geometry/colour escape hatches. Animation is opt-in ([animated]); the
/// drag and track-fill always follow the pointer 1:1.
///
/// ```dart
/// NibSlider(value: volume, onChanged: (v) => setState(() => volume = v))
/// NibSlider(value: v, min: 0, max: 100, divisions: 10, showValueLabel: true,
///   onChanged: ...)
/// NibSlider.range(values: price, onChanged: (r) => setState(() => price = r))
/// ```
class NibSlider extends StatefulWidget {
  /// A single-thumb slider (controlled via [value]/[onChanged]).
  const NibSlider({
    super.key,
    required double value,
    ValueChanged<double>? onChanged,
    ValueChanged<double>? onChangeStart,
    ValueChanged<double>? onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.showValueLabel = false,
    this.valueLabelFormatter,
    this.axis = Axis.horizontal,
    this.disabled = false,
    this.trackHeight,
    this.thumbSize,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.tickColor,
    this.trackRadius,
    this.padding,
    this.thumbBuilder,
    this.animated = false,
    this.transition,
    this.label,
    this.focusNode,
    this.autofocus = false,
  }) : _isRange = false,
       // Public param must be named `value`; the field is `_value`.
       // ignore: prefer_initializing_formals
       _value = value,
       _values = null,
       _onChangedSingle = onChanged,
       _onChangeStartSingle = onChangeStart,
       _onChangeEndSingle = onChangeEnd,
       _onChangedRange = null,
       _onChangeStartRange = null,
       _onChangeEndRange = null,
       assert(min < max, 'NibSlider requires min < max.');

  /// A two-thumb range slider (controlled via [values]/[onChanged]). The thumbs
  /// clamp against each other (they never cross).
  const NibSlider.range({
    super.key,
    required NibRangeValues values,
    ValueChanged<NibRangeValues>? onChanged,
    ValueChanged<NibRangeValues>? onChangeStart,
    ValueChanged<NibRangeValues>? onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.showValueLabel = false,
    this.valueLabelFormatter,
    this.axis = Axis.horizontal,
    this.disabled = false,
    this.trackHeight,
    this.thumbSize,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.tickColor,
    this.trackRadius,
    this.padding,
    this.thumbBuilder,
    this.animated = false,
    this.transition,
    this.label,
    this.focusNode,
    this.autofocus = false,
  }) : _isRange = true,
       _value = 0,
       // Public param must be named `values`; the field is `_values`.
       // ignore: prefer_initializing_formals
       _values = values,
       _onChangedSingle = null,
       _onChangeStartSingle = null,
       _onChangeEndSingle = null,
       _onChangedRange = onChanged,
       _onChangeStartRange = onChangeStart,
       _onChangeEndRange = onChangeEnd,
       assert(min < max, 'NibSlider requires min < max.');

  final bool _isRange;
  final double _value;
  final NibRangeValues? _values;
  final ValueChanged<double>? _onChangedSingle;
  final ValueChanged<double>? _onChangeStartSingle;
  final ValueChanged<double>? _onChangeEndSingle;
  final ValueChanged<NibRangeValues>? _onChangedRange;
  final ValueChanged<NibRangeValues>? _onChangeStartRange;
  final ValueChanged<NibRangeValues>? _onChangeEndRange;

  /// Lower bound of the value domain.
  final double min;

  /// Upper bound of the value domain.
  final double max;

  /// If set, the value snaps to `divisions + 1` evenly-spaced ticks and tick
  /// marks are painted on the track.
  final int? divisions;

  /// Shows a value-label bubble above the active thumb while dragging.
  final bool showValueLabel;

  /// Formats the value-label text. Defaults to the rounded value.
  final String Function(double value)? valueLabelFormatter;

  /// Layout orientation. Vertical sliders put [min] at the bottom.
  final Axis axis;

  /// Disables interaction and dims the slider. A `null` `onChanged` does the
  /// same.
  final bool disabled;

  /// Visible track thickness. Defaults to 4.
  final double? trackHeight;

  /// Thumb diameter. Defaults to 20.
  final double? thumbSize;

  /// Active (filled) track colour. Defaults to `NibTheme.primary`.
  final Color? activeColor;

  /// Inactive track colour. Defaults to `NibTheme.border`.
  final Color? inactiveColor;

  /// Thumb fill colour. Defaults to `NibTheme.primary`.
  final Color? thumbColor;

  /// Tick-mark colour. Defaults to `NibTheme.mutedForeground`.
  final Color? tickColor;

  /// Track corner radius. Defaults to a pill (`trackHeight / 2`).
  final BorderRadiusGeometry? trackRadius;

  /// Outer padding around the whole slider.
  final EdgeInsetsGeometry? padding;

  /// Fully custom thumb builder (replaces the built-in circle).
  final NibSliderThumbBuilder? thumbBuilder;

  /// Opt-in `nib_motion`: a thumb press-pop while dragging + value-label
  /// fade-in. `false` builds **zero** [NibMotion] (drag/fill still work).
  final bool animated;

  /// Timing/curve for the [animated] press-pop. `null` → a short ~120ms ease.
  final NibTransition? transition;

  /// Accessible name announced by screen readers for each thumb.
  final String? label;

  /// Optional external focus node for the (first) thumb.
  final FocusNode? focusNode;

  /// Whether to focus the first thumb on mount.
  final bool autofocus;

  @override
  State<NibSlider> createState() => _NibSliderState();
}

class _NibSliderState extends State<NibSlider> {
  int? _draggingThumb;
  int? _focusedThumb;

  late List<FocusNode> _nodes;

  // Geometry, recomputed each build; read by gesture callbacks.
  double _mainExtent = 0;
  double _trackStart = 0;
  double _trackLen = 0;
  double _trackBand = 0;
  double _labelLane = 0;

  @override
  void initState() {
    super.initState();
    _nodes = _buildNodes();
  }

  List<FocusNode> _buildNodes() {
    final count = widget._isRange ? 2 : 1;
    return List<FocusNode>.generate(
      count,
      (i) => (i == 0 ? widget.focusNode : null) ?? FocusNode(),
    );
  }

  @override
  void didUpdateWidget(NibSlider old) {
    super.didUpdateWidget(old);
    if (old._isRange != widget._isRange || old.focusNode != widget.focusNode) {
      for (final n in _nodes) {
        if (n != old.focusNode) n.dispose();
      }
      _nodes = _buildNodes();
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      if (n != widget.focusNode) n.dispose();
    }
    super.dispose();
  }

  bool get _interactive {
    if (widget.disabled) return false;
    return widget._isRange
        ? widget._onChangedRange != null
        : widget._onChangedSingle != null;
  }

  double get _thumbSize => widget.thumbSize ?? 20;
  double get _trackHeight => widget.trackHeight ?? 4;

  double get _step {
    final span = widget.max - widget.min;
    final d = widget.divisions;
    return d != null && d > 0 ? span / d : span / 100;
  }

  double _thumbValue(int i) {
    if (!widget._isRange) return widget._value;
    final v = widget._values!;
    return i == 0 ? v.start : v.end;
  }

  double _snap(double v) {
    final d = widget.divisions;
    var out = v.clamp(widget.min, widget.max).toDouble();
    if (d != null && d > 0) {
      final step = (widget.max - widget.min) / d;
      out = widget.min + ((out - widget.min) / step).round() * step;
    }
    return out.clamp(widget.min, widget.max).toDouble();
  }

  double _fraction(double value) {
    final span = widget.max - widget.min;
    if (span <= 0) return 0;
    return ((value - widget.min) / span).clamp(0.0, 1.0);
  }

  /// Main-axis distance from the track origin for [value] (origin = min end).
  double _posAlong(double value) => _trackStart + _fraction(value) * _trackLen;

  /// Value at a local main-axis coordinate (relative to the gesture box).
  double _valueFromLocalMain(double localMain) {
    final along = widget.axis == Axis.horizontal
        ? localMain
        : (_mainExtent - localMain);
    final frac = _trackLen <= 0
        ? 0.0
        : ((along - _trackStart) / _trackLen).clamp(0.0, 1.0);
    return _snap(widget.min + frac * (widget.max - widget.min));
  }

  int _nearestThumb(double value) {
    if (!widget._isRange) return 0;
    final v = widget._values!;
    final dStart = (value - v.start).abs();
    final dEnd = (value - v.end).abs();
    if (dStart == dEnd) return value >= v.start ? 1 : 0;
    return dStart < dEnd ? 0 : 1;
  }

  // --- emitting -------------------------------------------------------------

  void _emit(int thumb, double value, _Phase phase) {
    if (widget._isRange) {
      final cur = widget._values!;
      final next = thumb == 0
          ? NibRangeValues(math.min(value, cur.end), cur.end)
          : NibRangeValues(cur.start, math.max(value, cur.start));
      switch (phase) {
        case _Phase.start:
          widget._onChangeStartRange?.call(next);
          widget._onChangedRange?.call(next);
        case _Phase.update:
          widget._onChangedRange?.call(next);
        case _Phase.end:
          widget._onChangeEndRange?.call(next);
      }
    } else {
      switch (phase) {
        case _Phase.start:
          widget._onChangeStartSingle?.call(value);
          widget._onChangedSingle?.call(value);
        case _Phase.update:
          widget._onChangedSingle?.call(value);
        case _Phase.end:
          widget._onChangeEndSingle?.call(value);
      }
    }
  }

  // --- pointer --------------------------------------------------------------

  double _localMain(Offset local) =>
      widget.axis == Axis.horizontal ? local.dx : local.dy;

  void _onDragStart(Offset local) {
    if (!_interactive) return;
    final value = _valueFromLocalMain(_localMain(local));
    final thumb = _nearestThumb(value);
    setState(() => _draggingThumb = thumb);
    _nodes[thumb].requestFocus();
    _emit(thumb, value, _Phase.start);
  }

  void _onDragUpdate(Offset local) {
    if (!_interactive || _draggingThumb == null) return;
    final value = _valueFromLocalMain(_localMain(local));
    _emit(_draggingThumb!, value, _Phase.update);
    setState(() {}); // repaint fill/label at the new pointer position
  }

  void _onDragEnd() {
    if (_draggingThumb == null) return;
    final thumb = _draggingThumb!;
    _emit(thumb, _thumbValue(thumb), _Phase.end);
    setState(() => _draggingThumb = null);
  }

  void _onTapUp(Offset local) {
    if (!_interactive) return;
    final value = _valueFromLocalMain(_localMain(local));
    final thumb = _nearestThumb(value);
    _nodes[thumb].requestFocus();
    _emit(thumb, value, _Phase.start);
    _emit(thumb, value, _Phase.end);
  }

  // --- keyboard / semantics -------------------------------------------------

  void _nudge(int thumb, double delta) {
    if (!_interactive) return;
    final value = _snap(
      (_thumbValue(thumb) + delta).clamp(widget.min, widget.max),
    );
    _emit(thumb, value, _Phase.update);
  }

  void _setTo(int thumb, double value) {
    if (!_interactive) return;
    _emit(thumb, _snap(value), _Phase.update);
  }

  KeyEventResult _onKey(int thumb, KeyEvent event) {
    if (!_interactive) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.arrowUp) {
      _nudge(thumb, _step);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowDown) {
      _nudge(thumb, -_step);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.home) {
      _setTo(thumb, widget.min);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.end) {
      _setTo(thumb, widget.max);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // --- build ----------------------------------------------------------------

  String _labelText(double value) =>
      widget.valueLabelFormatter?.call(value) ?? value.round().toString();

  double get _resolvedTrackRadius {
    final r = widget.trackRadius;
    if (r is BorderRadius) return r.topLeft.x;
    return _trackHeight / 2; // pill
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final horizontal = widget.axis == Axis.horizontal;

    _trackBand = math.max(_kMinTapTarget, _thumbSize + 8);
    _labelLane = widget.showValueLabel ? _kLabelLane : 0;
    final crossThickness = _trackBand + _labelLane;

    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final rawMain = horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        _mainExtent = rawMain.isFinite ? rawMain : 200;
        final r = _thumbSize / 2;
        _trackStart = r;
        _trackLen = math.max(0, _mainExtent - _thumbSize);

        final stackSize = horizontal
            ? Size(_mainExtent, crossThickness)
            : Size(crossThickness, _mainExtent);

        final children = <Widget>[
          // Track + active fill + ticks.
          Positioned(
            left: horizontal ? 0 : _labelLane,
            top: horizontal ? _labelLane : 0,
            width: horizontal ? _mainExtent : _trackBand,
            height: horizontal ? _trackBand : _mainExtent,
            child: CustomPaint(
              painter: _NibSliderPainter(
                axis: widget.axis,
                trackStart: _trackStart,
                trackLen: _trackLen,
                trackHeight: _trackHeight,
                radius: _resolvedTrackRadius,
                active: widget.activeColor ?? theme.primary,
                inactive: widget.inactiveColor ?? theme.border,
                tick: widget.tickColor ?? theme.mutedForeground,
                divisions: widget.divisions,
                fillPositions: [
                  for (var i = 0; i < _nodes.length; i++)
                    _posAlong(_thumbValue(i)),
                ],
                isRange: widget._isRange,
              ),
            ),
          ),
          for (var i = 0; i < _nodes.length; i++) _buildThumb(i, theme),
          if (widget.showValueLabel && _draggingThumb != null)
            _buildLabel(_draggingThumb!, theme),
        ];

        return SizedBox.fromSize(
          size: stackSize,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onTapUp(d.localPosition),
            onHorizontalDragStart: horizontal
                ? (d) => _onDragStart(d.localPosition)
                : null,
            onHorizontalDragUpdate: horizontal
                ? (d) => _onDragUpdate(d.localPosition)
                : null,
            onHorizontalDragEnd: horizontal ? (_) => _onDragEnd() : null,
            onVerticalDragStart: horizontal
                ? null
                : (d) => _onDragStart(d.localPosition),
            onVerticalDragUpdate: horizontal
                ? null
                : (d) => _onDragUpdate(d.localPosition),
            onVerticalDragEnd: horizontal ? null : (_) => _onDragEnd(),
            child: Stack(clipBehavior: Clip.none, children: children),
          ),
        );
      },
    );

    if (horizontal) {
      content = SizedBox(
        width: double.infinity,
        height: crossThickness,
        child: content,
      );
    } else {
      content = SizedBox(
        width: crossThickness,
        height: double.infinity,
        child: content,
      );
    }

    if (widget.padding != null) {
      content = Padding(padding: widget.padding!, child: content);
    }

    if (!_interactive) {
      content = Opacity(opacity: 0.5, child: content);
    }
    return content;
  }

  Widget _buildThumb(int i, NibTheme theme) {
    final horizontal = widget.axis == Axis.horizontal;
    final ts = _thumbSize;
    final along = _posAlong(_thumbValue(i));
    final mainCoord = horizontal ? along : (_mainExtent - along);
    final crossCenter = _labelLane + _trackBand / 2;
    final dragging = _draggingThumb == i;
    final focused = _focusedThumb == i;

    Widget knob = widget.thumbBuilder != null
        ? widget.thumbBuilder!(
            context,
            NibSliderThumbState(
              value: _thumbValue(i),
              dragging: dragging,
              focused: focused,
              size: ts,
            ),
          )
        : Container(
            width: ts,
            height: ts,
            decoration: BoxDecoration(
              color: widget.thumbColor ?? theme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: theme.background, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          );

    knob = SizedBox(
      width: ts,
      height: ts,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          knob,
          if (focused && _interactive)
            Positioned(
              left: -4,
              top: -4,
              right: -4,
              bottom: -4,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.ring, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.animated) {
      knob = NibMotion(
        initial: NibAnim.identity,
        animate: dragging ? const NibAnim(scale: 1.3) : NibAnim.identity,
        transition:
            widget.transition ??
            const NibTransition(duration: Duration(milliseconds: 120)),
        child: knob,
      );
    }

    knob = Focus(
      focusNode: _nodes[i],
      canRequestFocus: _interactive,
      autofocus: i == 0 && widget.autofocus,
      onKeyEvent: (_, e) => _onKey(i, e),
      onFocusChange: (f) => setState(() => _focusedThumb = f ? i : null),
      child: knob,
    );

    final v = _thumbValue(i);
    knob = Semantics(
      slider: true,
      enabled: _interactive,
      label: widget.label,
      value: _labelText(v),
      // Both increased/decreased values must be supplied whenever the
      // increase/decrease actions are (Flutter semantics invariant).
      increasedValue: _interactive
          ? _labelText(_snap((v + _step).clamp(widget.min, widget.max)))
          : null,
      decreasedValue: _interactive
          ? _labelText(_snap((v - _step).clamp(widget.min, widget.max)))
          : null,
      onIncrease: _interactive ? () => _nudge(i, _step) : null,
      onDecrease: _interactive ? () => _nudge(i, -_step) : null,
      child: knob,
    );

    return Positioned(
      left: horizontal ? along - ts / 2 : crossCenter - ts / 2,
      top: horizontal ? crossCenter - ts / 2 : mainCoord - ts / 2,
      width: ts,
      height: ts,
      child: knob,
    );
  }

  Widget _buildLabel(int i, NibTheme theme) {
    final horizontal = widget.axis == Axis.horizontal;
    final along = _posAlong(_thumbValue(i));
    final mainCoord = horizontal ? along : (_mainExtent - along);

    Widget bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          _labelText(_thumbValue(i)),
          style: TextStyle(
            color: theme.cardForeground,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ),
    );

    if (widget.animated) {
      bubble = NibMotion(
        initial: const NibAnim(opacity: 0, scale: 0.8),
        animate: const NibAnim(opacity: 1, scale: 1),
        transition:
            widget.transition ??
            const NibTransition(duration: Duration(milliseconds: 120)),
        child: bubble,
      );
    }

    if (horizontal) {
      return Positioned(
        left: along - 40,
        top: 0,
        width: 80,
        height: _labelLane,
        child: Center(child: bubble),
      );
    }
    return Positioned(
      left: 0,
      width: _labelLane + _trackBand / 2 - _thumbSize / 2,
      top: mainCoord - 12,
      child: Align(alignment: Alignment.centerLeft, child: bubble),
    );
  }
}

enum _Phase { start, update, end }

class _NibSliderPainter extends CustomPainter {
  _NibSliderPainter({
    required this.axis,
    required this.trackStart,
    required this.trackLen,
    required this.trackHeight,
    required this.radius,
    required this.active,
    required this.inactive,
    required this.tick,
    required this.divisions,
    required this.fillPositions,
    required this.isRange,
  });

  final Axis axis;
  final double trackStart;
  final double trackLen;
  final double trackHeight;
  final double radius;
  final Color active;
  final Color inactive;
  final Color tick;
  final int? divisions;
  final List<double> fillPositions;
  final bool isRange;

  bool get _h => axis == Axis.horizontal;

  /// Cross-axis centre of the track within the painter's box.
  double _cross(Size size) => _h ? size.height / 2 : size.width / 2;

  Rect _band(Size size, double fromAlong, double toAlong) {
    final c = _cross(size);
    final half = trackHeight / 2;
    if (_h) {
      return Rect.fromLTRB(fromAlong, c - half, toAlong, c + half);
    }
    // Vertical: min end (fromAlong small) sits at the bottom.
    final yFrom = size.height - fromAlong;
    final yTo = size.height - toAlong;
    return Rect.fromLTRB(
      c - half,
      math.min(yFrom, yTo),
      c + half,
      math.max(yFrom, yTo),
    );
  }

  Offset _pt(Size size, double along) => _h
      ? Offset(along, _cross(size))
      : Offset(_cross(size), size.height - along);

  @override
  void paint(Canvas canvas, Size size) {
    final rr = Radius.circular(radius);
    final inactivePaint = Paint()..color = inactive;
    final activePaint = Paint()..color = active;

    // Inactive track (full travel range).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        _band(size, trackStart, trackStart + trackLen),
        rr,
      ),
      inactivePaint,
    );

    // Active fill.
    if (isRange && fillPositions.length == 2) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _band(size, fillPositions[0], fillPositions[1]),
          rr,
        ),
        activePaint,
      );
    } else if (fillPositions.isNotEmpty) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(_band(size, trackStart, fillPositions[0]), rr),
        activePaint,
      );
    }

    // Tick marks.
    final d = divisions;
    if (d != null && d > 0) {
      final tickPaint = Paint()..color = tick;
      for (var i = 0; i <= d; i++) {
        final along = trackStart + (i / d) * trackLen;
        canvas.drawCircle(_pt(size, along), trackHeight / 2 + 0.5, tickPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_NibSliderPainter old) =>
      axis != old.axis ||
      trackStart != old.trackStart ||
      trackLen != old.trackLen ||
      trackHeight != old.trackHeight ||
      radius != old.radius ||
      active != old.active ||
      inactive != old.inactive ||
      tick != old.tick ||
      divisions != old.divisions ||
      isRange != old.isRange ||
      !listEquals(fillPositions, old.fillPositions);
}
