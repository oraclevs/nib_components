import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('NibSkeletonBone', () {
    testWidgets('renders child directly when built standalone', (tester) async {
      await tester.pumpWidget(_wrap(
        const NibSkeletonBone(
          width: 40,
          height: 40,
          shape: NibSkeletonShape.circle,
          child: Text('real content'),
        ),
      ));
      expect(find.text('real content'), findsOneWidget);
    });
  });

  group('NibSkeletonIgnore', () {
    testWidgets('renders child directly when built standalone', (tester) async {
      await tester.pumpWidget(_wrap(
        const NibSkeletonIgnore(child: Text('static logo')),
      ));
      expect(find.text('static logo'), findsOneWidget);
    });
  });
}
