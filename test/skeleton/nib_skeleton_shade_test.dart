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

Future<void> _pumpShaded(WidgetTester tester, Widget node) async {
  late Widget result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (context) {
      result = shadeWidget(context, node, _palette);
      return const SizedBox();
    }),
  ));
  await tester.pumpWidget(MaterialApp(home: result));
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
}
