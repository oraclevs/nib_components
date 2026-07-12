import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibAnimPresets, NibKeyframe, NibMotion, NibTransition;

import '../overlay/nib_anchored_overlay.dart';
import '../theme/nib_theme.dart';
import 'nib_calendar_math.dart';
import 'nib_date_picker_controller.dart';
import 'nib_date_picker_types.dart';

const double _kCellSize = 44;
const double _kGridWidth = _kCellSize * 7;
const double _kBodyHeight = _kCellSize * 6 + 28; // 6 week rows + weekday header

/// A native calendar / date picker with single, range, and multi-date
/// selection, month + year quick navigation, min/max bounds, a disabled-day
/// predicate, locale-aware labels, and three display modes: [inline],
/// [popover], and [dialog].
///
/// Simplest usage is an inline single-date calendar:
///
/// ```dart
/// NibDatePicker(onDateChanged: (day) => print(day))
/// ```
class NibDatePicker extends StatefulWidget {
  const NibDatePicker({
    super.key,
    this.mode = NibDatePickerMode.single,
    this.displayMode = NibDatePickerDisplayMode.inline,
    this.selectedDate,
    this.selectedRange,
    this.selectedDates,
    this.initialMonth,
    this.minDate,
    this.maxDate,
    this.disabledDayPredicate,
    this.locale,
    this.onDateChanged,
    this.onRangeChanged,
    this.onDatesChanged,
    this.placeholder = 'Select date',
    this.disabled = false,
    this.closeOnSelect = true,
    this.cellShape = NibDateCellShape.circle,
    this.dayBuilder,
    this.animated = false,
    this.transition,
    this.controller,
  });

  final NibDatePickerMode mode;
  final NibDatePickerDisplayMode displayMode;

  /// Initial single-mode selection (ignored when a [controller] is supplied).
  final DateTime? selectedDate;

  /// Initial range-mode selection (ignored when a [controller] is supplied).
  final NibDateRange? selectedRange;

  /// Initial multi-mode selection (ignored when a [controller] is supplied).
  final List<DateTime>? selectedDates;

  /// Which month the calendar first shows. Defaults to the month of the
  /// current selection, else today.
  final DateTime? initialMonth;

  final DateTime? minDate;
  final DateTime? maxDate;
  final NibDisabledDayPredicate? disabledDayPredicate;

  /// Overrides the locale for month/weekday names and first-day-of-week. When
  /// `null`, the ambient [Localizations] locale is used.
  final Locale? locale;

  final ValueChanged<DateTime?>? onDateChanged;
  final ValueChanged<NibDateRange?>? onRangeChanged;
  final ValueChanged<List<DateTime>>? onDatesChanged;

  /// Trigger text shown for [popover]/[dialog] modes when nothing is selected.
  final String placeholder;

  final bool disabled;

  /// Whether picking closes the overlay (popover/dialog modes). Single mode
  /// closes on any pick; range mode closes when the range completes; multi
  /// never auto-closes.
  final bool closeOnSelect;

  /// Shape of the selected-day background when using the built-in cell.
  /// Ignored when [dayBuilder] is supplied.
  final NibDateCellShape cellShape;

  /// Fully overrides how each day cell's content is rendered. The calendar
  /// still owns the tap target and 44px sizing; the builder returns only the
  /// cell content for the given [NibCalendarDayState].
  final NibCalendarDayBuilder? dayBuilder;

  final bool animated;
  final NibTransition? transition;

  final NibDatePickerController? controller;

  @override
  State<NibDatePicker> createState() => _NibDatePickerState();
}

class _NibDatePickerState extends State<NibDatePicker> {
  late NibDatePickerController _controller;
  late bool _ownsController;
  final _link = LayerLink();
  OverlayEntry? _dialogEntry;
  NibAnchoredOverlayHandle? _popoverHandle;

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant NibDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _unbindController();
      _bindController(widget.controller);
    }
  }

  @override
  void dispose() {
    _teardownOverlays();
    _unbindController();
    super.dispose();
  }

  void _bindController(NibDatePickerController? external) {
    _controller = external ??
        NibDatePickerController(
          selectedDate: widget.selectedDate,
          selectedRange: widget.selectedRange,
          selectedDates: widget.selectedDates,
          displayedMonth: widget.initialMonth,
        );
    _ownsController = external == null;
    _controller.addListener(_handleControllerChanged);
    if (_controller.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleControllerChanged();
      });
    }
  }

  void _unbindController() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) _controller.dispose();
  }

  void _handleControllerChanged() {
    if (widget.displayMode != NibDatePickerDisplayMode.inline) {
      if (_controller.isOpen) {
        _showOverlay();
      } else {
        _teardownOverlays();
      }
    }
    if (mounted) setState(() {});
  }

  // --- Selection ------------------------------------------------------------

  void _onDaySelected(DateTime day) {
    switch (widget.mode) {
      case NibDatePickerMode.single:
        _controller.setSingle(day);
        widget.onDateChanged?.call(_controller.selectedDate);
        _maybeClose();
      case NibDatePickerMode.range:
        final next = nextRange(_controller.selectedRange, day);
        _controller.setRange(next);
        widget.onRangeChanged?.call(next);
        if (next.isComplete) _maybeClose();
      case NibDatePickerMode.multi:
        final next = toggleDate(_controller.selectedDates, day);
        _controller.setMulti(next);
        widget.onDatesChanged?.call(next);
    }
  }

  void _maybeClose() {
    if (widget.displayMode != NibDatePickerDisplayMode.inline && widget.closeOnSelect) {
      _controller.close();
    }
  }

  // --- Overlays -------------------------------------------------------------

  void _showOverlay() {
    if (widget.displayMode == NibDatePickerDisplayMode.popover) {
      _showPopover();
    } else if (widget.displayMode == NibDatePickerDisplayMode.dialog) {
      _showDialog();
    }
  }

  void _teardownOverlays() {
    _popoverHandle?.remove();
    _popoverHandle = null;
    _dialogEntry?.remove();
    _dialogEntry = null;
  }

  void _showPopover() {
    if (_popoverHandle != null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    _popoverHandle = NibAnchoredOverlay.show(
      context,
      link: _link,
      targetRenderBox: box,
      onDismissed: _controller.close,
      contentBuilder: (ctx) => AnimatedBuilder(
        animation: _controller,
        builder: (ctx, _) => _buildCalendarCard(NibTheme.of(context)),
      ),
    );
  }

  void _showDialog() {
    if (_dialogEntry != null || !mounted) return;
    _dialogEntry = OverlayEntry(
      builder: (ctx) {
        final theme = NibTheme.of(context);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _controller.close,
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (ctx, _) => _buildCalendarCard(theme),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_dialogEntry!);
  }

  // --- Building -------------------------------------------------------------

  Widget _buildCalendarCard(NibTheme theme) {
    Widget card = Material(
      color: theme.card,
      elevation: widget.displayMode == NibDatePickerDisplayMode.inline ? 0 : 8,
      borderRadius: BorderRadius.circular(theme.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.border),
          borderRadius: BorderRadius.circular(theme.radiusLg),
        ),
        child: _CalendarView(
          controller: _controller,
          mode: widget.mode,
          minDate: _controller.minSelectable ?? widget.minDate,
          maxDate: _controller.maxSelectable ?? widget.maxDate,
          disabledDayPredicate: widget.disabledDayPredicate,
          cellShape: widget.cellShape,
          dayBuilder: widget.dayBuilder,
          animated: widget.animated,
          transition: widget.transition,
          onDaySelected: _onDaySelected,
        ),
      ),
    );

    // Entrance animation only for the overlay display modes — inline mounts
    // once, so an entrance would be invisible; there, the visible animation is
    // the month-to-month slide handled inside _CalendarView.
    if (widget.animated && widget.displayMode != NibDatePickerDisplayMode.inline) {
      card = NibMotion(
        initial: const NibAnim(opacity: 0, scale: 0.97, y: -6),
        animate: const NibAnim(opacity: 1, scale: 1, y: 0),
        transition: widget.transition ?? const NibTransition(duration: Duration(milliseconds: 150)),
        child: card,
      );
    }

    // Hug the calendar's natural width instead of stretching to fill the
    // parent, and scale down (rather than overflow) when the parent is
    // narrower than the calendar.
    card = FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topCenter, child: card);

    if (widget.locale != null) {
      card = Localizations.override(context: context, locale: widget.locale, child: card);
    }
    return card;
  }

  String _triggerText(MaterialLocalizations ml) {
    switch (widget.mode) {
      case NibDatePickerMode.single:
        final d = _controller.selectedDate;
        return d == null ? widget.placeholder : ml.formatMediumDate(d);
      case NibDatePickerMode.range:
        final r = _controller.selectedRange;
        if (r == null) return widget.placeholder;
        final end = r.end == null ? '…' : ml.formatShortDate(r.end!);
        return '${ml.formatShortDate(r.start)} – $end';
      case NibDatePickerMode.multi:
        final n = _controller.selectedDates.length;
        return n == 0 ? widget.placeholder : '$n selected';
    }
  }

  bool get _hasSelection => switch (widget.mode) {
        NibDatePickerMode.single => _controller.selectedDate != null,
        NibDatePickerMode.range => _controller.selectedRange != null,
        NibDatePickerMode.multi => _controller.selectedDates.isNotEmpty,
      };

  Widget _buildTrigger(NibTheme theme, MaterialLocalizations ml) {
    final empty = !_hasSelection;
    return CompositedTransformTarget(
      link: _link,
      child: Semantics(
        button: true,
        label: _triggerText(ml),
        child: InkWell(
          onTap: widget.disabled ? null : _controller.open,
          borderRadius: BorderRadius.circular(theme.radiusDefault),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.disabled ? theme.muted : theme.background,
              border: Border.all(color: _controller.isOpen ? theme.ring : theme.border),
              borderRadius: BorderRadius.circular(theme.radiusDefault),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 18, color: theme.mutedForeground),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _triggerText(ml),
                      style: TextStyle(color: empty ? theme.mutedForeground : theme.foreground),
                    ),
                  ),
                  if (!empty && !widget.disabled)
                    InkWell(
                      onTap: () {
                        _controller.clear();
                        _fireCleared();
                      },
                      borderRadius: BorderRadius.circular(theme.radiusPill),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.close, size: 16, color: theme.mutedForeground),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _fireCleared() {
    switch (widget.mode) {
      case NibDatePickerMode.single:
        widget.onDateChanged?.call(null);
      case NibDatePickerMode.range:
        widget.onRangeChanged?.call(null);
      case NibDatePickerMode.multi:
        widget.onDatesChanged?.call(const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final ml = MaterialLocalizations.of(context);
    if (widget.displayMode == NibDatePickerDisplayMode.inline) {
      return _buildCalendarCard(theme);
    }
    return _buildTrigger(theme, ml);
  }
}

enum _PickerMode { days, months, years }

class _CalendarView extends StatefulWidget {
  const _CalendarView({
    required this.controller,
    required this.mode,
    required this.minDate,
    required this.maxDate,
    required this.disabledDayPredicate,
    required this.cellShape,
    required this.dayBuilder,
    required this.animated,
    required this.transition,
    required this.onDaySelected,
  });

  final NibDatePickerController controller;
  final NibDatePickerMode mode;
  final DateTime? minDate;
  final DateTime? maxDate;
  final NibDisabledDayPredicate? disabledDayPredicate;
  final NibDateCellShape cellShape;
  final NibCalendarDayBuilder? dayBuilder;
  final bool animated;
  final NibTransition? transition;
  final ValueChanged<DateTime> onDaySelected;

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  _PickerMode _pickerMode = _PickerMode.days;
  late int _navYear;
  late int _yearGridStart;
  int _slideDir = 1; // +1 = next month enters from the right, -1 = from the left

  // Moving selection "puck" state (single-select, animated). Tracks the puck's
  // previous and current grid cell so it can animate between them; `_puckSeq`
  // is bumped on each move to re-key (and so replay) the keyframe animation.
  int _puckIndex = -1;
  int _puckFromIndex = -1;
  int _puckSeq = 0;

  bool get _usePuck =>
      widget.animated && widget.mode == NibDatePickerMode.single && widget.dayBuilder == null;

  NibDatePickerController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onControllerChanged);
    _navYear = _c.displayedMonth.year;
    _yearGridStart = _navYear - 5;
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  bool _dayDisabled(DateTime day) => isDayDisabled(
        day,
        minDate: widget.minDate,
        maxDate: widget.maxDate,
        predicate: widget.disabledDayPredicate,
      );

  // --- Header ---------------------------------------------------------------

  Widget _headerLabel(NibTheme theme, MaterialLocalizations ml) {
    final String text;
    VoidCallback? onTap;
    switch (_pickerMode) {
      case _PickerMode.days:
        text = ml.formatMonthYear(_c.displayedMonth);
        onTap = () => setState(() {
              _navYear = _c.displayedMonth.year;
              _yearGridStart = _navYear - 5;
              _pickerMode = _PickerMode.years;
            });
      case _PickerMode.months:
        text = '$_navYear';
        onTap = () => setState(() {
              _yearGridStart = _navYear - 5;
              _pickerMode = _PickerMode.years;
            });
      case _PickerMode.years:
        text = '$_yearGridStart – ${_yearGridStart + 11}';
        onTap = null;
    }
    return TextButton(
      onPressed: onTap,
      child: Text(text, style: TextStyle(color: theme.foreground, fontWeight: FontWeight.w600)),
    );
  }

  void _stepBack() {
    switch (_pickerMode) {
      case _PickerMode.days:
        _slideDir = -1;
        _c.showMonth(addMonths(_c.displayedMonth, -1));
      case _PickerMode.months:
        setState(() => _navYear -= 1);
      case _PickerMode.years:
        setState(() => _yearGridStart -= 12);
    }
  }

  void _stepForward() {
    switch (_pickerMode) {
      case _PickerMode.days:
        _slideDir = 1;
        _c.showMonth(addMonths(_c.displayedMonth, 1));
      case _PickerMode.months:
        setState(() => _navYear += 1);
      case _PickerMode.years:
        setState(() => _yearGridStart += 12);
    }
  }

  Widget _buildHeader(NibTheme theme, MaterialLocalizations ml) {
    return Row(
      children: [
        IconButton(
          onPressed: _stepBack,
          icon: Icon(Icons.chevron_left, color: theme.mutedForeground),
          tooltip: 'Previous',
        ),
        Expanded(child: Center(child: _headerLabel(theme, ml))),
        IconButton(
          onPressed: _stepForward,
          icon: Icon(Icons.chevron_right, color: theme.mutedForeground),
          tooltip: 'Next',
        ),
      ],
    );
  }

  // --- Days grid ------------------------------------------------------------

  Widget _buildWeekdayRow(NibTheme theme, MaterialLocalizations ml) {
    final first = ml.firstDayOfWeekIndex;
    return SizedBox(
      height: 28,
      width: _kGridWidth,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            SizedBox(
              width: _kCellSize,
              child: Center(
                child: Text(
                  ml.narrowWeekdays[(first + i) % 7],
                  style: TextStyle(color: theme.mutedForeground, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  NibCalendarDayState _dayStateFor(DateTime day) {
    final displayed = _c.displayedMonth;
    final outOfMonth = day.month != displayed.month || day.year != displayed.year;
    final disabled = _dayDisabled(day);
    final today = isSameDay(day, DateTime.now());

    var isSelected = false;
    var inRange = false;
    var isStart = false;
    var isEnd = false;
    switch (widget.mode) {
      case NibDatePickerMode.single:
        final d = _c.selectedDate;
        isSelected = d != null && isSameDay(day, d);
      case NibDatePickerMode.multi:
        isSelected = _c.selectedDates.any((d) => isSameDay(d, day));
      case NibDatePickerMode.range:
        final r = _c.selectedRange;
        if (r != null) {
          isStart = isSameDay(day, r.start);
          isEnd = r.end != null && isSameDay(day, r.end!);
          isSelected = isStart || isEnd;
          inRange = r.end != null && !isSelected && isInRange(day, r.start, r.end!);
        }
    }

    return NibCalendarDayState(
      date: day,
      selected: isSelected,
      inRange: inRange,
      isRangeStart: isStart,
      isRangeEnd: isEnd,
      today: today,
      outOfMonth: outOfMonth,
      disabled: disabled,
    );
  }

  BoxShape _boxShape() => widget.cellShape == NibDateCellShape.circle ? BoxShape.circle : BoxShape.rectangle;

  BorderRadius? _borderRadius(NibTheme theme) {
    switch (widget.cellShape) {
      case NibDateCellShape.circle:
        return null; // driven by BoxShape.circle
      case NibDateCellShape.square:
        return BorderRadius.zero;
      case NibDateCellShape.rounded:
        return BorderRadius.circular(theme.radiusSm);
      case NibDateCellShape.pill:
        return BorderRadius.circular(theme.radiusPill);
    }
  }

  Widget _defaultCellContent(NibTheme theme, NibCalendarDayState s) {
    final Color fg;
    if (s.disabled) {
      fg = theme.mutedForeground.withValues(alpha: 0.4);
    } else if (s.selected) {
      fg = theme.primaryForeground;
    } else if (s.outOfMonth) {
      fg = theme.mutedForeground;
    } else {
      fg = theme.foreground;
    }

    final radius = _borderRadius(theme);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: s.selected
              ? theme.primary
              : s.inRange
                  ? theme.secondary
                  : null,
          shape: s.selected || s.inRange ? _boxShape() : BoxShape.rectangle,
          borderRadius: s.selected || s.inRange ? radius : BorderRadius.circular(theme.radiusSm),
          border: s.today && !s.selected ? Border.all(color: theme.primary) : null,
        ),
        child: Center(
          child: Text('${s.date.day}', style: TextStyle(color: fg, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildDayCell(NibTheme theme, DateTime day) {
    final state = _dayStateFor(day);
    var content = widget.dayBuilder?.call(context, state) ?? _defaultCellContent(theme, state);

    // Multi/range don't use the moving puck (there can be many selected cells),
    // so give each newly-selected cell a quick pop to confirm the tap. Keyed by
    // (day, selected) so it replays only when the cell's selected state flips.
    if (widget.animated &&
        widget.mode != NibDatePickerMode.single &&
        widget.dayBuilder == null &&
        state.selected) {
      content = NibMotion(
        key: ValueKey('pop-${day.year}-${day.month}-${day.day}-${state.selected}'),
        keyframes: NibAnimPresets.pulse,
        transition: const NibTransition(duration: Duration(milliseconds: 220)),
        child: content,
      );
    }

    final tapShape = widget.cellShape == NibDateCellShape.circle
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: _borderRadius(theme) ?? BorderRadius.zero);

    return Semantics(
      button: !state.disabled,
      selected: state.selected,
      label: '${day.year}-${day.month}-${day.day}',
      child: SizedBox(
        width: _kCellSize,
        height: _kCellSize,
        child: Material(
          type: MaterialType.transparency,
          shape: tapShape,
          child: InkWell(
            customBorder: tapShape,
            onTap: state.disabled ? null : () => widget.onDaySelected(day),
            excludeFromSemantics: true,
            child: content,
          ),
        ),
      ),
    );
  }

  Offset _cellOffset(int index) => Offset((index % 7) * _kCellSize, (index ~/ 7) * _kCellSize);

  int _singleSelIndex(List<DateTime> days) {
    final d = _c.selectedDate;
    if (d == null) return -1;
    return days.indexWhere((x) => isSameDay(x, d));
  }

  /// The moving selection highlight for single-select. Slides between cells
  /// when they're near, arcs (hops) when they're far apart, and lands with a
  /// small pop. Sits *behind* the day numbers, which keep the static highlight
  /// so the target reads as selected the instant it's tapped.
  Widget _puck(NibTheme theme, int index) {
    final from = _cellOffset(_puckFromIndex >= 0 ? _puckFromIndex : index);
    final to = _cellOffset(index);
    final far = (to - from).distance > 100;
    final apexY = math.min(from.dy, to.dy) - 26;
    final midX = (from.dx + to.dx) / 2;

    final keyframes = <NibKeyframe>[
      NibKeyframe(at: 0, value: NibAnim(x: from.dx, y: from.dy, scale: 1)),
      if (far) NibKeyframe(at: 0.45, value: NibAnim(x: midX, y: apexY, scale: 1.06)),
      NibKeyframe(at: 0.82, value: NibAnim(x: to.dx, y: to.dy, scale: 1.14)),
      NibKeyframe(at: 1, value: NibAnim(x: to.dx, y: to.dy, scale: 1)),
    ];

    return Positioned(
      left: 0,
      top: 0,
      child: IgnorePointer(
        child: NibMotion(
          key: ValueKey(_puckSeq),
          keyframes: keyframes,
          transition: NibTransition(duration: Duration(milliseconds: far ? 300 : 190)),
          child: SizedBox(
            width: _kCellSize,
            height: _kCellSize,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.primary,
                  shape: _boxShape(),
                  borderRadius: _boxShape() == BoxShape.circle ? null : _borderRadius(theme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDaysBody(NibTheme theme, MaterialLocalizations ml) {
    final days = calendarDays(_c.displayedMonth, ml.firstDayOfWeekIndex);

    final sel = _usePuck ? _singleSelIndex(days) : -1;
    if (_usePuck && sel != _puckIndex) {
      _puckFromIndex = _puckIndex;
      _puckIndex = sel;
      _puckSeq++;
    }

    final rows = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var week = 0; week < 6; week++)
          SizedBox(
            width: _kGridWidth,
            child: Row(
              children: [
                for (var d = 0; d < 7; d++) _buildDayCell(theme, days[week * 7 + d]),
              ],
            ),
          ),
      ],
    );

    final Widget daysArea = (_usePuck && sel >= 0)
        ? SizedBox(
            width: _kGridWidth,
            height: _kCellSize * 6,
            child: Stack(
              clipBehavior: Clip.none, // let the hop arc rise above the grid
              children: [_puck(theme, sel), rows],
            ),
          )
        : rows;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildWeekdayRow(theme, ml),
        daysArea,
      ],
    );
  }

  // --- Months / years pickers ----------------------------------------------

  Widget _buildMonthsBody(NibTheme theme, MaterialLocalizations ml) {
    return SizedBox(
      width: _kGridWidth,
      height: _kBodyHeight,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          for (var m = 1; m <= 12; m++)
            InkWell(
              borderRadius: BorderRadius.circular(theme.radiusSm),
              onTap: () {
                final target = DateTime(_navYear, m, 1);
                _slideDir = target.isAfter(_c.displayedMonth) ? 1 : -1;
                _c.showMonth(target);
                setState(() => _pickerMode = _PickerMode.days);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  ml.formatMonthYear(DateTime(_navYear, m)),
                  style: TextStyle(color: theme.foreground),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildYearsBody(NibTheme theme) {
    return SizedBox(
      width: _kGridWidth,
      height: _kBodyHeight,
      child: GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        padding: const EdgeInsets.all(8),
        children: [
          for (var i = 0; i < 12; i++)
            Builder(builder: (context) {
              final year = _yearGridStart + i;
              final selected = year == _navYear;
              return Padding(
                padding: const EdgeInsets.all(4),
                child: Material(
                  color: selected ? theme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(theme.radiusSm),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                    onTap: () => setState(() {
                      _navYear = year;
                      _pickerMode = _PickerMode.months;
                    }),
                    child: Center(
                      child: Text(
                        '$year',
                        style: TextStyle(color: selected ? theme.primaryForeground : theme.foreground),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final ml = MaterialLocalizations.of(context);

    Widget body;
    switch (_pickerMode) {
      case _PickerMode.days:
        body = _buildDaysBody(theme, ml);
        // Slide the new month in from the nav direction. Keyed by the month so
        // it remounts (and replays) on every month change; direction comes
        // from which arrow / picker choice triggered it.
        if (widget.animated) {
          body = NibMotion(
            key: ValueKey(_c.displayedMonth),
            initial: NibAnim(opacity: 0, x: _slideDir * 28.0),
            animate: const NibAnim(opacity: 1, x: 0),
            transition: widget.transition ?? const NibTransition(duration: Duration(milliseconds: 180)),
            child: body,
          );
        }
      case _PickerMode.months:
        body = _buildMonthsBody(theme, ml);
      case _PickerMode.years:
        body = _buildYearsBody(theme);
    }

    return SizedBox(
      width: _kGridWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme, ml),
            SizedBox(width: _kGridWidth, child: body),
          ],
        ),
      ),
    );
  }
}
