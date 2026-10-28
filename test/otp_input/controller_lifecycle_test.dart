import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

class _OtpHost extends StatefulWidget {
  const _OtpHost({super.key, required this.controller});
  final NibOtpController controller;
  @override
  State<_OtpHost> createState() => _OtpHostState();
}

class _OtpHostState extends State<_OtpHost> {
  late NibOtpController controller = widget.controller;
  final changes = <String>[];
  final completed = <String>[];
  void replace(NibOtpController next) => setState(() => controller = next);
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: LayoutBuilder(
        builder: (_, _) => NibOtpInput(
          length: 4,
          controller: controller,
          onChanged: (value) => setState(() => changes.add(value)),
          onCompleted: (value) => setState(() => completed.add(value)),
        ),
      ),
    ),
  );
}

void main() {
  for (final initial in ['12', '1234', 'a12-34b56']) {
    testWidgets(
      'prefilled controller $initial is adopted without edit callbacks during layout',
      (tester) async {
        final controller = NibOtpController()..setValue(initial);
        addTearDown(controller.dispose);
        final host = GlobalKey<_OtpHostState>();
        await tester.pumpWidget(_OtpHost(key: host, controller: controller));
        expect(tester.takeException(), isNull);
        final field = tester.widget<TextField>(find.byType(TextField));
        final expected = initial == '12' ? '12' : '1234';
        expect(field.controller!.text, expected);
        expect(host.currentState!.changes, isEmpty);
        expect(host.currentState!.completed, isEmpty);
        await tester.pump();
        expect(
          host.currentState!.changes,
          isEmpty,
          reason: 'Binding must not defer a synthetic edit either.',
        );
        controller.clear();
        await tester.pump();
        expect(host.currentState!.changes, ['']);
        controller.setValue('5678');
        await tester.pump();
        expect(host.currentState!.changes, ['', '5678']);
        expect(host.currentState!.completed, ['5678']);
        controller.setValue('5678');
        await tester.pump();
        expect(host.currentState!.completed, ['5678']);
        await tester.enterText(find.byType(TextField), '1234');
        await tester.pump();
        expect(controller.value, '1234');
        expect(host.currentState!.completed, ['5678', '1234']);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.setValue('90');
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'controller replacement adopts value silently and detaches the old listener',
    (tester) async {
      final first = NibOtpController()..setValue('12');
      final second = NibOtpController()..setValue('5678');
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final host = GlobalKey<_OtpHostState>();
      await tester.pumpWidget(_OtpHost(key: host, controller: first));
      expect(tester.takeException(), isNull);
      host.currentState!.replace(second);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '5678',
      );
      expect(host.currentState!.changes, isEmpty);
      expect(host.currentState!.completed, isEmpty);
      first.setValue('3333');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '5678',
      );
      expect(host.currentState!.changes, isEmpty);
      second.clear();
      await tester.pump();
      expect(host.currentState!.changes, ['']);
      second.setValue('5678');
      await tester.pump();
      expect(host.currentState!.completed, ['5678']);
      await tester.pumpWidget(const SizedBox.shrink());
      second.setValue('00');
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
