import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_components/src/skeleton/nib_skeleton_shade.dart';

const _palette = NibSkeletonPalette(
  baseColor: Color(0xFFE0E0E0),
  shimmerColor: Color(0xFFF0F0F0),
  radiusSm: 4,
  radiusDefault: 8,
  fallbackWidth: 80,
  fallbackHeight: 16,
  boxRadius: null,
);

class _CustomStateful extends StatefulWidget {
  const _CustomStateful();

  @override
  State<_CustomStateful> createState() => _CustomStatefulState();
}

class _CustomStatefulState extends State<_CustomStateful> {
  @override
  Widget build(BuildContext context) => const Text('stateful content');
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        CircleAvatar(radius: 20),
        Column(
          children: [
            Text('Ada Lovelace'),
            Text('@ada'),
          ],
        ),
      ],
    );
  }
}

class _ThrowsOnBuild extends StatelessWidget {
  const _ThrowsOnBuild();

  @override
  Widget build(BuildContext context) => throw StateError('no ambient dependency');
}

Future<void> _pumpShaded(WidgetTester tester, Widget node) async {
  late Widget result;
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Builder(builder: (context) {
      result = shadeWidget(context, node, _palette);
      return const SizedBox();
    }),
  ));
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: result));
}

void main() {
  testWidgets('unrecognized StatefulWidget becomes a fallback bone box', (tester) async {
    await _pumpShaded(tester, const _CustomStateful());
    final box = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(box.width, 80);
    expect(box.height, 16);
    expect(find.text('stateful content'), findsNothing);
  });

  testWidgets('NibSkeletonBone overrides detection with its explicit shape', (tester) async {
    await _pumpShaded(
      tester,
      const NibSkeletonBone(
        width: 60,
        height: 60,
        shape: NibSkeletonShape.circle,
        child: Text('ignored'),
      ),
    );
    final box = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(box.width, 60);
    expect(box.height, 60);
    expect(find.text('ignored'), findsNothing);
  });

  testWidgets('NibSkeletonIgnore passes its child through unshaded', (tester) async {
    await _pumpShaded(tester, const NibSkeletonIgnore(child: Text('always visible')));
    expect(find.text('always visible'), findsOneWidget);
  });

  testWidgets('Text becomes a fully-rounded bone bar sized from its own style', (tester) async {
    await _pumpShaded(tester, const Text('Hello there', style: TextStyle(fontSize: 20)));
    final decoratedBox = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final decoration = decoratedBox.decoration as BoxDecoration;
    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sizedBox.height, closeTo(20 * 1.2, 4)); // roughly one line at fontSize 20
    expect(decoration.borderRadius, BorderRadius.circular(sizedBox.height! / 2));
    expect(find.text('Hello there'), findsNothing);
  });

  testWidgets('Icon becomes a square bone box sized to its size', (tester) async {
    await _pumpShaded(tester, const Icon(Icons.star, size: 32));
    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sizedBox.width, 32);
    expect(sizedBox.height, 32);
    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('Icon with no size falls back to 24', (tester) async {
    await _pumpShaded(tester, const Icon(Icons.star));
    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sizedBox.width, 24);
    expect(sizedBox.height, 24);
  });

  testWidgets('CircleAvatar becomes a circle bone sized from radius', (tester) async {
    await _pumpShaded(tester, const CircleAvatar(radius: 28));
    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    final decoratedBox = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(sizedBox.width, 56);
    expect(sizedBox.height, 56);
    expect(decoration.shape, BoxShape.circle);
  });

  testWidgets('Image becomes a rectangle bone sized from width/height', (tester) async {
    await _pumpShaded(tester, Image.memory(Uint8List(0), width: 100, height: 60));
    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sizedBox.width, 100);
    expect(sizedBox.height, 60);
  });

  testWidgets('childless sized Container becomes a bone box matching its tight constraints', (tester) async {
    await _pumpShaded(
      tester,
      Container(
        width: 120,
        height: 40,
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
      ),
    );
    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    final decoratedBox = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(sizedBox.width, 120);
    expect(sizedBox.height, 40);
    expect(decoration.borderRadius, BorderRadius.circular(6));
    expect(decoration.color, _palette.baseColor); // real red is replaced by the bone colour
  });

  testWidgets('childless circular Container becomes a circle bone', (tester) async {
    await _pumpShaded(
      tester,
      Container(width: 50, height: 50, decoration: const BoxDecoration(shape: BoxShape.circle)),
    );
    final decoratedBox = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
  });

  testWidgets('childless SizedBox becomes a bone box matching its own size', (tester) async {
    await _pumpShaded(tester, const SizedBox(width: 90, height: 30));
    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sizedBox.width, 90);
    expect(sizedBox.height, 30);
  });

  testWidgets('Row/Column/Padding preserve structure and shade their children', (tester) async {
    await _pumpShaded(
      tester,
      const Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.star, size: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name'),
                Text('Subtitle'),
              ],
            ),
          ],
        ),
      ),
    );
    expect(find.byType(Padding), findsOneWidget);
    final padding = tester.widget<Padding>(find.byType(Padding));
    expect(padding.padding, const EdgeInsets.all(8));
    final row = tester.widget<Row>(find.byType(Row));
    expect(row.mainAxisAlignment, MainAxisAlignment.spaceBetween);
    expect(row.children.length, 2);
    final column = tester.widget<Column>(find.byType(Column));
    expect(column.crossAxisAlignment, CrossAxisAlignment.start);
    expect(column.children.length, 2);
    // 3 leaves (Icon + 2 Text) -> 3 bone boxes, no real Icon/Text left.
    expect(find.byType(DecoratedBox), findsNWidgets(3));
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.text('Name'), findsNothing);
  });

  testWidgets('Center/Align/ConstrainedBox/Expanded/Flexible preserve their own fields', (tester) async {
    await _pumpShaded(
      tester,
      Row(
        children: [
          Expanded(flex: 2, child: const Center(child: Text('centered'))),
          Flexible(
            fit: FlexFit.tight,
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: const Text('constrained'),
              ),
            ),
          ),
        ],
      ),
    );
    final expanded = tester.widget<Expanded>(find.byType(Expanded));
    expect(expanded.flex, 2);
    final flexible = tester.widget<Flexible>(find.byType(Flexible));
    expect(flexible.fit, FlexFit.tight);
    final align = tester.widget<Align>(find.byType(Align));
    expect(align.alignment, Alignment.topLeft);
    final constrainedBox = tester.widget<ConstrainedBox>(
      find.descendant(of: find.byType(Align), matching: find.byType(ConstrainedBox)),
    );
    expect(constrainedBox.constraints, const BoxConstraints(maxWidth: 100));
    expect(find.text('centered'), findsNothing);
    expect(find.text('constrained'), findsNothing);
  });

  testWidgets('Stack and Wrap preserve their own fields', (tester) async {
    await _pumpShaded(
      tester,
      Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.star),
          Wrap(spacing: 6, children: const [Text('a'), Text('b')]),
        ],
      ),
    );
    final stack = tester.widget<Stack>(find.byType(Stack));
    expect(stack.alignment, Alignment.center);
    final wrap = tester.widget<Wrap>(find.byType(Wrap));
    expect(wrap.spacing, 6);
    expect(wrap.children.length, 2);
  });

  testWidgets('Container/DecoratedBox/ColoredBox/SizedBox with a child preserve chrome and shade the child',
      (tester) async {
    await _pumpShaded(
      tester,
      SizedBox(
        width: 200,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.green),
            child: ColoredBox(
              color: Colors.yellow,
              child: const Text('inside'),
            ),
          ),
        ),
      ),
    );
    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sizedBox.width, 200);
    final container = tester.widget<Container>(find.byType(Container));
    expect(container.padding, const EdgeInsets.all(4));
    expect((container.decoration as BoxDecoration).color, Colors.blue);
    final coloredBoxes = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
    expect(coloredBoxes.any((w) => w.color == Colors.yellow), isTrue);
    expect(find.text('inside'), findsNothing);
  });

  testWidgets('a custom StatelessWidget is transparently expanded down to its leaves', (tester) async {
    await _pumpShaded(tester, const _ProfileHeader());
    expect(find.byType(Row), findsOneWidget);
    expect(find.byType(Column), findsOneWidget);
    // CircleAvatar + 2 Text -> 3 bone boxes; none of the real widgets remain.
    expect(find.byType(DecoratedBox), findsNWidgets(3));
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.text('Ada Lovelace'), findsNothing);
  });

  testWidgets('a StatelessWidget that throws during build() degrades to a fallback box, not a crash',
      (tester) async {
    await _pumpShaded(tester, const _ThrowsOnBuild());
    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sizedBox.width, _palette.fallbackWidth);
    expect(sizedBox.height, _palette.fallbackHeight);
    expect(tester.takeException(), isNull);
  });
}
