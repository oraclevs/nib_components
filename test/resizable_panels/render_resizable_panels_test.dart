import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/src/resizable_panels/render_resizable_panels.dart';

Widget _slot(Key key) => SizedBox.expand(key: key);

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets(
    'horizontal: lays out panels at their given fractions with fixed handle slots between them',
    (tester) async {
      final panel0 = GlobalKey();
      final handle0 = GlobalKey();
      final panel1 = GlobalKey();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            height: 100,
            child: NibResizablePanelsLayout(
              direction: Axis.horizontal,
              sizes: const [0.5, 0.5],
              children: [_slot(panel0), _slot(handle0), _slot(panel1)],
            ),
          ),
        ),
      );

      final panelsMain = 400 - kNibResizablePanelsHandleHitWidth;
      expect(tester.getSize(find.byKey(panel0)), Size(panelsMain * 0.5, 100));
      expect(tester.getTopLeft(find.byKey(panel0)), Offset.zero);

      expect(
        tester.getSize(find.byKey(handle0)),
        const Size(kNibResizablePanelsHandleHitWidth, 100),
      );
      expect(
        tester.getTopLeft(find.byKey(handle0)),
        Offset(panelsMain * 0.5, 0),
      );

      expect(tester.getSize(find.byKey(panel1)), Size(panelsMain * 0.5, 100));
      expect(
        tester.getTopLeft(find.byKey(panel1)),
        Offset(panelsMain * 0.5 + kNibResizablePanelsHandleHitWidth, 0),
      );
    },
  );

  testWidgets(
    'vertical: lays out panels stacked top-to-bottom with fixed handle slots between them',
    (tester) async {
      final panel0 = GlobalKey();
      final handle0 = GlobalKey();
      final panel1 = GlobalKey();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 100,
            height: 300,
            child: NibResizablePanelsLayout(
              direction: Axis.vertical,
              sizes: const [0.5, 0.5],
              children: [_slot(panel0), _slot(handle0), _slot(panel1)],
            ),
          ),
        ),
      );

      final panelsMain = 300 - kNibResizablePanelsHandleHitWidth;
      expect(tester.getSize(find.byKey(panel0)), Size(100, panelsMain * 0.5));
      expect(
        tester.getSize(find.byKey(handle0)),
        const Size(100, kNibResizablePanelsHandleHitWidth),
      );
      expect(
        tester.getTopLeft(find.byKey(handle0)),
        Offset(0, panelsMain * 0.5),
      );
    },
  );

  testWidgets(
    'uneven sizes produce proportionally uneven extents; the last panel absorbs any rounding remainder',
    (tester) async {
      final panel0 = GlobalKey();
      final panel1 = GlobalKey();
      final panel2 = GlobalKey();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 300,
            height: 50,
            child: NibResizablePanelsLayout(
              direction: Axis.horizontal,
              sizes: const [0.2, 0.3, 0.5],
              children: [
                _slot(panel0),
                _slot(GlobalKey()),
                _slot(panel1),
                _slot(GlobalKey()),
                _slot(panel2),
              ],
            ),
          ),
        ),
      );

      final panelsMain = 300 - (2 * kNibResizablePanelsHandleHitWidth);
      expect(
        tester.getSize(find.byKey(panel0)).width,
        closeTo(panelsMain * 0.2, 0.01),
      );
      expect(
        tester.getSize(find.byKey(panel1)).width,
        closeTo(panelsMain * 0.3, 0.01),
      );
      expect(
        tester.getSize(find.byKey(panel2)).width,
        closeTo(panelsMain * 0.5, 0.01),
      );

      final totalWidth =
          tester.getSize(find.byKey(panel0)).width +
          tester.getSize(find.byKey(panel1)).width +
          tester.getSize(find.byKey(panel2)).width +
          (2 * kNibResizablePanelsHandleHitWidth);
      expect(totalWidth, closeTo(300, 0.01));
    },
  );

  testWidgets('every child (panel and handle) fills the full cross extent', (
    tester,
  ) async {
    final panel0 = GlobalKey();
    final handle0 = GlobalKey();

    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 200,
          height: 80,
          child: NibResizablePanelsLayout(
            direction: Axis.horizontal,
            sizes: const [0.5, 0.5],
            children: [_slot(panel0), _slot(handle0), _slot(GlobalKey())],
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(panel0)).height, 80);
    expect(tester.getSize(find.byKey(handle0)).height, 80);
  });
}
