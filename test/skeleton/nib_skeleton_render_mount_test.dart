import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_components/src/skeleton/nib_skeleton_render_mount.dart';
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

class _StatefulLeaf extends StatefulWidget {
  const _StatefulLeaf({required this.child});
  final Widget child;

  @override
  State<_StatefulLeaf> createState() => _StatefulLeafState();
}

class _StatefulLeafState extends State<_StatefulLeaf> {
  @override
  Widget build(BuildContext context) => widget.child;
}

Future<Element> _pumpAndFindElement(WidgetTester tester, Widget child, {Key? key}) async {
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Center(child: KeyedSubtree(key: key ?? const Key('root'), child: child)),
  ));
  return tester.element(find.byKey(key ?? const Key('root')));
}

void main() {
  testWidgets('NibSkeletonBone produces one explicit bone command, ignoring what it wraps',
      (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      const NibSkeletonBone(width: 40, height: 40, shape: NibSkeletonShape.circle, child: Text('x')),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(1));
    expect(commands.single.kind, BonePaintKind.bone);
    expect(commands.single.shape, NibSkeletonShape.circle);
    expect(commands.single.rect.size, const Size(40, 40));
  });

  testWidgets('NibSkeletonIgnore produces one realPaintThrough command', (tester) async {
    final element = await _pumpAndFindElement(tester, const NibSkeletonIgnore(child: Icon(Icons.star)));
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(1));
    expect(commands.single.kind, BonePaintKind.realPaintThrough);
  });

  testWidgets('a Text leaf produces one bone command sized to its real measured size',
      (tester) async {
    final element = await _pumpAndFindElement(tester, const Text('Hello there'));
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(1));
    expect(commands.single.kind, BonePaintKind.bone);
    final realSize = (element.renderObject! as RenderBox).size;
    expect(commands.single.rect.size, realSize);
    expect(commands.single.radius, BorderRadius.circular(realSize.height / 2));
  });

  testWidgets('an Icon leaf produces one bone command sized to its real measured size',
      (tester) async {
    final element = await _pumpAndFindElement(tester, const Icon(Icons.star, size: 32));
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(1));
    final realSize = (element.renderObject! as RenderBox).size;
    expect(commands.single.rect.size, realSize);
    expect(commands.single.radius, BorderRadius.circular(_palette.radiusSm));
  });

  testWidgets('a CircleAvatar leaf produces one circle bone command sized to its real size',
      (tester) async {
    final element = await _pumpAndFindElement(tester, const CircleAvatar(radius: 20));
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(1));
    expect(commands.single.shape, NibSkeletonShape.circle);
  });

  testWidgets(
      'a StatefulWidget wrapping a Text is walked through transparently — one bone command '
      'for the real Text, not a flat fallback box (the whole point of this engine)',
      (tester) async {
    final element = await _pumpAndFindElement(tester, const _StatefulLeaf(child: Text('inside')));
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(1));
    expect(commands.single.kind, BonePaintKind.bone);
    // Sized to the real Text, not the generic fallbackWidth/Height default.
    expect(commands.single.rect.size.width, isNot(_palette.fallbackWidth));
  });

  testWidgets('a Row of two Texts produces two independent bone commands at their own offsets',
      (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [Text('A'), Text('BB')],
      ),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(2));
    expect(commands[0].rect.left, lessThan(commands[1].rect.left));
  });

  testWidgets('a childless leaf render object with no recognized type falls back to a bone '
      'sized to its real size (e.g. a bare SizedBox)', (tester) async {
    final element = await _pumpAndFindElement(tester, const SizedBox(width: 50, height: 20));
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(1));
    expect(commands.single.kind, BonePaintKind.bone);
    expect(commands.single.rect.size, const Size(50, 20));
  });

  testWidgets(
      'a DecoratedBox with a child preserves its own real decoration and still bones its child',
      (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      DecoratedBox(
        decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
        child: const Text('inside'),
      ),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(2));
    expect(commands[0].kind, BonePaintKind.decoration);
    final decoration = commands[0].decoration as BoxDecoration;
    expect(decoration.color, Colors.blue);
    expect(commands[1].kind, BonePaintKind.bone);
  });

  testWidgets('a ColoredBox with a child preserves its own real colour and still bones its child',
      (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      const ColoredBox(color: Colors.yellow, child: Text('inside')),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(2));
    expect(commands[0].kind, BonePaintKind.decoration);
    final decoration = commands[0].decoration as BoxDecoration;
    expect(decoration.color, Colors.yellow);
  });

  testWidgets(
      'a StatefulWidget composing a DecoratedBox chrome around a CircleAvatar+Text preserves '
      'the chrome and shades the content (the NibCard shape)', (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      _StatefulLeaf(
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Colors.black12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [CircleAvatar(radius: 16), Text('Name')],
          ),
        ),
      ),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    // 1 decoration (the chrome) + 2 bones (avatar circle, text bar).
    expect(commands.where((c) => c.kind == BonePaintKind.decoration), hasLength(1));
    expect(commands.where((c) => c.kind == BonePaintKind.bone), hasLength(2));
  });

  testWidgets("NibSkeletonRenderMount lays out to exactly its real child's size, no crash",
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Center(
        child: NibSkeletonRenderMount(
          palette: _palette,
          child: const _StatefulLeaf(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [CircleAvatar(radius: 20), Text('Name')],
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    final mountSize = tester.getSize(find.byType(NibSkeletonRenderMount));
    final realSize = tester.getSize(find.byType(Row));
    expect(mountSize, realSize);
  });

  testWidgets('NibSkeletonRenderMount survives a rebuild with a different child (update, not just mount)',
      (tester) async {
    Widget host(String label) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Center(
            child: NibSkeletonRenderMount(
              palette: _palette,
              child: _StatefulLeaf(child: Text(label)),
            ),
          ),
        );
    await tester.pumpWidget(host('first'));
    await tester.pumpWidget(host('second'));
    expect(tester.takeException(), isNull);
  });
}
