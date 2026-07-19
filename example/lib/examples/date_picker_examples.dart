import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

String _iso(DateTime d) => d.toIso8601String().split('T').first;

/// 1. Minimal/default — an inline single-date calendar. Now hugs its natural
/// width instead of stretching.
class DatePickerInlineExample extends StatefulWidget {
  const DatePickerInlineExample({super.key});

  @override
  State<DatePickerInlineExample> createState() =>
      _DatePickerInlineExampleState();
}

class _DatePickerInlineExampleState extends State<DatePickerInlineExample> {
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Selected: ${_selected == null ? 'none' : _iso(_selected!)}'),
        const SizedBox(height: 8),
        // animated: the selected highlight slides between nearby days and hops
        // (arcs) between far ones, landing with a small pop.
        NibDatePicker(
          animated: true,
          onDateChanged: (d) => setState(() => _selected = d),
        ),
      ],
    );
  }
}

/// 2. Common variant — a range picker in a popover, restricted to the 5th–25th
/// of the current month so the greyed, non-selectable days are clearly visible.
class DatePickerRangePopoverExample extends StatefulWidget {
  const DatePickerRangePopoverExample({super.key});

  @override
  State<DatePickerRangePopoverExample> createState() =>
      _DatePickerRangePopoverExampleState();
}

class _DatePickerRangePopoverExampleState
    extends State<DatePickerRangePopoverExample> {
  NibDateRange? _range;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Booking window — only the 5th–25th are selectable (rest greyed)',
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 300,
          child: NibDatePicker(
            mode: NibDatePickerMode.range,
            displayMode: NibDatePickerDisplayMode.popover,
            animated: true,
            minDate: DateTime(now.year, now.month, 5),
            maxDate: DateTime(now.year, now.month, 25),
            placeholder: 'Pick a date range',
            onRangeChanged: (r) => setState(() => _range = r),
          ),
        ),
        const SizedBox(height: 8),
        if (_range != null)
          Text(
            'Range: ${_iso(_range!.start)} – ${_range!.end == null ? '…' : _iso(_range!.end!)}',
          ),
      ],
    );
  }
}

/// 3. Advanced — multi-date selection in a dialog, weekends disabled via a
/// predicate, animated (watch the month slide), and an external controller
/// driving "Today" and "Clear".
class DatePickerAdvancedExample extends StatefulWidget {
  const DatePickerAdvancedExample({super.key});

  @override
  State<DatePickerAdvancedExample> createState() =>
      _DatePickerAdvancedExampleState();
}

class _DatePickerAdvancedExampleState extends State<DatePickerAdvancedExample> {
  final _controller = NibDatePickerController();
  List<DateTime> _dates = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Pick working days (multi, dialog, weekends off, animated)'),
        const SizedBox(height: 8),
        SizedBox(
          width: 300,
          child: NibDatePicker(
            mode: NibDatePickerMode.multi,
            displayMode: NibDatePickerDisplayMode.dialog,
            controller: _controller,
            animated: true,
            placeholder: 'Choose days',
            disabledDayPredicate: (d) =>
                d.weekday == DateTime.saturday || d.weekday == DateTime.sunday,
            onDatesChanged: (d) => setState(() => _dates = d),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () => _controller.showMonth(DateTime.now()),
              child: const Text('Today'),
            ),
            OutlinedButton(
              onPressed: _controller.clear,
              child: const Text('Clear'),
            ),
            Text('${_dates.length} selected'),
          ],
        ),
      ],
    );
  }
}

/// 4. Fully custom — a `dayBuilder` renders each selected day as a diamond
/// (proof you can draw any shape, not just the built-in circle/square/pill),
/// plus buttons that change the selectable range at runtime via the controller.
class DatePickerCustomCellExample extends StatefulWidget {
  const DatePickerCustomCellExample({super.key});

  @override
  State<DatePickerCustomCellExample> createState() =>
      _DatePickerCustomCellExampleState();
}

class _DatePickerCustomCellExampleState
    extends State<DatePickerCustomCellExample> {
  final _controller = NibDatePickerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _diamondCell(BuildContext context, NibCalendarDayState state) {
    final theme = NibTheme.of(context);
    final label = Text(
      '${state.date.day}',
      style: TextStyle(
        fontSize: 13,
        color: state.selected
            ? theme.primaryForeground
            : state.disabled
            ? theme.mutedForeground.withValues(alpha: 0.4)
            : state.outOfMonth
            ? theme.mutedForeground
            : theme.foreground,
      ),
    );
    if (!state.selected) return Center(child: label);
    return Center(
      child: Transform.rotate(
        angle: math.pi / 4, // 45° -> diamond
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Transform.rotate(angle: -math.pi / 4, child: label),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Custom diamond cells + runtime selectable range'),
        const SizedBox(height: 8),
        NibDatePicker(
          controller: _controller,
          dayBuilder: _diamondCell,
          onDateChanged: (_) {},
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _controller.setSelectableBounds(
                now,
                now.add(const Duration(days: 7)),
              ),
              child: const Text('Only next 7 days'),
            ),
            OutlinedButton(
              onPressed: () => _controller.setSelectableBounds(
                DateTime(now.year, now.month, 1),
                DateTime(now.year, now.month + 1, 0),
              ),
              child: const Text('This month only'),
            ),
            OutlinedButton(
              onPressed: () => _controller.setSelectableBounds(null, null),
              child: const Text('Clear limit'),
            ),
          ],
        ),
      ],
    );
  }
}
