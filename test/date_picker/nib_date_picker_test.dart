import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart' show NibMotion;

// July 2026: the 1st is a Wednesday. In the Sunday-first 42-day grid
// (Jun 28 – Aug 8) days 9..27 appear exactly once, so they're unambiguous
// finders. Weekdays: Jul 4/11/18 = Sat, Jul 5/12/19 = Sun, Jul 15 = Wed.
final _july = DateTime(2026, 7, 1);

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: const [NibTheme.light]),
    home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
  );
}

void main() {
  testWidgets('inline renders the month header and day grid', (tester) async {
    await tester.pumpWidget(_wrap(NibDatePicker(initialMonth: _july)));
    expect(find.text('July 2026'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('single select fires onDateChanged with the tapped day', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(
      _wrap(NibDatePicker(initialMonth: _july, onDateChanged: (d) => picked = d)),
    );
    await tester.tap(find.text('15'));
    await tester.pump();
    expect(picked, DateTime(2026, 7, 15));
  });

  testWidgets('range select completes with two taps (order-swapped safe)', (tester) async {
    final ranges = <NibDateRange>[];
    await tester.pumpWidget(
      _wrap(
        NibDatePicker(
          mode: NibDatePickerMode.range,
          initialMonth: _july,
          onRangeChanged: (r) { if (r != null) ranges.add(r); },
        ),
      ),
    );
    await tester.tap(find.text('20'));
    await tester.pump();
    expect(ranges.last.isComplete, isFalse);

    await tester.tap(find.text('10'));
    await tester.pump();
    expect(ranges.last.start, DateTime(2026, 7, 10));
    expect(ranges.last.end, DateTime(2026, 7, 20));
  });

  testWidgets('multi select toggles days', (tester) async {
    List<DateTime>? dates;
    await tester.pumpWidget(
      _wrap(
        NibDatePicker(
          mode: NibDatePickerMode.multi,
          initialMonth: _july,
          onDatesChanged: (d) => dates = d,
        ),
      ),
    );
    await tester.tap(find.text('10'));
    await tester.pump();
    await tester.tap(find.text('20'));
    await tester.pump();
    expect(dates, [DateTime(2026, 7, 10), DateTime(2026, 7, 20)]);

    await tester.tap(find.text('10'));
    await tester.pump();
    expect(dates, [DateTime(2026, 7, 20)]);
  });

  testWidgets('days before minDate are inert', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(
      _wrap(
        NibDatePicker(
          initialMonth: _july,
          minDate: DateTime(2026, 7, 12),
          onDateChanged: (d) => picked = d,
        ),
      ),
    );
    await tester.tap(find.text('10')); // before min -> disabled
    await tester.pump();
    expect(picked, isNull);

    await tester.tap(find.text('15'));
    await tester.pump();
    expect(picked, DateTime(2026, 7, 15));
  });

  testWidgets('disabledDayPredicate disables matching days', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(
      _wrap(
        NibDatePicker(
          initialMonth: _july,
          disabledDayPredicate: (d) => d.weekday == DateTime.saturday || d.weekday == DateTime.sunday,
          onDateChanged: (d) => picked = d,
        ),
      ),
    );
    await tester.tap(find.text('18')); // Saturday
    await tester.pump();
    expect(picked, isNull);

    await tester.tap(find.text('15')); // Wednesday
    await tester.pump();
    expect(picked, DateTime(2026, 7, 15));
  });

  testWidgets('month arrows step the displayed month', (tester) async {
    await tester.pumpWidget(_wrap(NibDatePicker(initialMonth: _july)));
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text('August 2026'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    expect(find.text('June 2026'), findsOneWidget);
  });

  testWidgets('quick nav: header -> year grid -> month list -> back to days', (tester) async {
    await tester.pumpWidget(_wrap(NibDatePicker(initialMonth: _july)));
    await tester.tap(find.text('July 2026'));
    await tester.pump();
    // years grid (2021–2032)
    expect(find.text('2021 – 2032'), findsOneWidget);

    await tester.tap(find.text('2028'));
    await tester.pump();
    // months list for 2028
    expect(find.text('March 2028'), findsOneWidget);

    await tester.tap(find.text('March 2028'));
    await tester.pump();
    // back to days on March 2028
    expect(find.text('March 2028'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('popover: trigger opens the calendar, outside tap closes', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NibDatePicker(
          displayMode: NibDatePickerDisplayMode.popover,
          initialMonth: _july,
        ),
      ),
    );
    expect(find.text('July 2026'), findsNothing);

    await tester.tap(find.text('Select date'));
    await tester.pumpAndSettle();
    expect(find.text('July 2026'), findsOneWidget);

    await tester.tapAt(const Offset(780, 580));
    await tester.pumpAndSettle();
    expect(find.text('July 2026'), findsNothing);
  });

  testWidgets('popover single-select closes on pick', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(
      _wrap(
        NibDatePicker(
          displayMode: NibDatePickerDisplayMode.popover,
          initialMonth: _july,
          onDateChanged: (d) => picked = d,
        ),
      ),
    );
    await tester.tap(find.text('Select date'));
    await tester.pump();
    await tester.tap(find.text('15'));
    await tester.pump();
    expect(picked, DateTime(2026, 7, 15));
    expect(find.text('July 2026'), findsNothing); // closed
  });

  testWidgets('dialog display mode opens via controller and picks', (tester) async {
    final controller = NibDatePickerController(displayedMonth: _july);
    DateTime? picked;
    await tester.pumpWidget(
      _wrap(
        NibDatePicker(
          displayMode: NibDatePickerDisplayMode.dialog,
          controller: controller,
          onDateChanged: (d) => picked = d,
        ),
      ),
    );
    controller.open();
    await tester.pump();
    expect(find.text('July 2026'), findsOneWidget);

    await tester.tap(find.text('20'));
    await tester.pump();
    expect(picked, DateTime(2026, 7, 20));
    expect(controller.isOpen, isFalse);
  });

  testWidgets('controller.setSelectableBounds disables out-of-range days at runtime', (tester) async {
    final controller = NibDatePickerController(displayedMonth: _july);
    DateTime? picked;
    await tester.pumpWidget(
      _wrap(NibDatePicker(controller: controller, onDateChanged: (d) => picked = d)),
    );
    controller.setSelectableBounds(DateTime(2026, 7, 12), DateTime(2026, 7, 20));
    await tester.pump();

    await tester.tap(find.text('10')); // now below the runtime min -> inert
    await tester.pump();
    expect(picked, isNull);

    await tester.tap(find.text('15'));
    await tester.pump();
    expect(picked, DateTime(2026, 7, 15));
  });

  testWidgets('dayBuilder renders fully custom cell content', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NibDatePicker(
          initialMonth: _july,
          dayBuilder: (context, state) =>
              Center(child: Text(state.date.day == 15 ? 'PICK' : '${state.date.day}')),
        ),
      ),
    );
    expect(find.text('PICK'), findsOneWidget);
    expect(find.text('15'), findsNothing);
  });

  testWidgets('cellShape square still selects normally', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(
      _wrap(
        NibDatePicker(
          initialMonth: _july,
          cellShape: NibDateCellShape.square,
          onDateChanged: (d) => picked = d,
        ),
      ),
    );
    await tester.tap(find.text('15'));
    await tester.pump();
    expect(picked, DateTime(2026, 7, 15));
  });

  testWidgets('animated month change slides via NibMotion and still navigates', (tester) async {
    await tester.pumpWidget(_wrap(NibDatePicker(initialMonth: _july, animated: true)));
    expect(find.byType(NibMotion), findsOneWidget); // keyed days-body slide
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsOneWidget);
  });

  testWidgets('animated single-select: a moving puck appears and selection still fires', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(
      _wrap(NibDatePicker(initialMonth: _july, animated: true, onDateChanged: (d) => picked = d)),
    );
    await tester.tap(find.text('15'));
    await tester.pump();
    expect(picked, DateTime(2026, 7, 15));
    // month-slide NibMotion + the moving selection puck
    expect(find.byType(NibMotion), findsAtLeastNWidgets(2));
  });

  testWidgets('animated multi-select pops cells and still toggles', (tester) async {
    List<DateTime>? dates;
    await tester.pumpWidget(
      _wrap(
        NibDatePicker(
          mode: NibDatePickerMode.multi,
          initialMonth: _july,
          animated: true,
          onDatesChanged: (d) => dates = d,
        ),
      ),
    );
    await tester.tap(find.text('10'));
    await tester.pump();
    expect(dates, [DateTime(2026, 7, 10)]);
    // month-slide NibMotion + at least one selected-cell pop
    expect(find.byType(NibMotion), findsAtLeastNWidgets(2));
  });

  testWidgets('animated: false builds zero NibMotion widgets', (tester) async {
    await tester.pumpWidget(_wrap(NibDatePicker(initialMonth: _july)));
    expect(find.byType(NibMotion), findsNothing);
  });

  testWidgets('animated: true wraps the calendar in a NibMotion', (tester) async {
    await tester.pumpWidget(_wrap(NibDatePicker(initialMonth: _july, animated: true)));
    expect(find.byType(NibMotion), findsOneWidget);
  });

  testWidgets('narrow viewport does not overflow', (tester) async {
    tester.view.physicalSize = const Size(280, 620);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(NibDatePicker(initialMonth: _july)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
