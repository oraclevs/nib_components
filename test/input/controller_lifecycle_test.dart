import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

class _TrackedTextController extends TextEditingController {
  _TrackedTextController({super.text});
  bool get hasAttachedListeners => hasListeners;
}

class _TrackedFocusNode extends FocusNode {
  final callbacks = <VoidCallback>[];
  @override
  void addListener(VoidCallback listener) {
    callbacks.add(listener);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    callbacks.remove(listener);
    super.removeListener(listener);
  }
}

void main() {
  for (final multiline in [false, true]) {
    final name = multiline ? 'NibTextarea' : 'NibInput';
    Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 320, child: child)),
      ),
    );
    Widget field(
      GlobalKey<FormFieldState<String>> key,
      TextEditingController? controller,
      ValueChanged<String> onChanged, {
      FocusNode? focusNode,
    }) => multiline
        ? NibTextarea(
            key: key,
            controller: controller,
            focusNode: focusNode,
            showCounter: true,
            maxLength: 40,
            validator: NibValidators.required(),
            onChanged: onChanged,
          )
        : NibInput(
            key: key,
            controller: controller,
            focusNode: focusNode,
            clearable: true,
            validator: NibValidators.required(),
            onChanged: onChanged,
          );

    testWidgets(
      '$name external text synchronizes form value, chrome and callback once',
      (tester) async {
        final key = GlobalKey<FormFieldState<String>>();
        final controller = _TrackedTextController();
        final changes = <String>[];
        await tester.pumpWidget(wrap(field(key, controller, changes.add)));
        controller.text = 'Ada';
        await tester.pump();
        expect(key.currentState!.value, 'Ada');
        expect(changes, ['Ada']);
        expect(key.currentState!.validate(), isTrue);
        if (multiline) {
          expect(find.text('3/40'), findsOneWidget);
        } else {
          expect(find.byIcon(Icons.close), findsOneWidget);
        }
        controller.selection = const TextSelection.collapsed(offset: 1);
        await tester.pump();
        expect(changes, ['Ada']);
        await tester.enterText(find.byType(TextField), 'Grace');
        await tester.pump();
        expect(changes, ['Ada', 'Grace']);
        controller.clear();
        await tester.pump();
        expect(key.currentState!.value, '');
        expect(key.currentState!.validate(), isFalse);
        expect(changes, ['Ada', 'Grace', '']);
        if (multiline) {
          expect(find.text('0/40'), findsOneWidget);
        } else {
          expect(find.byIcon(Icons.close), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
        expect(controller.hasAttachedListeners, isFalse);
        controller.dispose();
      },
    );

    testWidgets(
      '$name controller replacement detaches old and retains text when internal',
      (tester) async {
        final key = GlobalKey<FormFieldState<String>>();
        final first = _TrackedTextController(text: 'first');
        final second = _TrackedTextController(text: 'second');
        final changes = <String>[];
        await tester.pumpWidget(wrap(field(key, first, changes.add)));
        await tester.pumpWidget(wrap(field(key, second, changes.add)));
        expect(key.currentState!.value, 'second');
        expect(first.hasAttachedListeners, isFalse);
        first.text = 'detached';
        expect(key.currentState!.value, 'second');
        second.selection = const TextSelection.collapsed(offset: 2);
        await tester.pumpWidget(wrap(field(key, null, changes.add)));
        final internal = tester
            .widget<TextField>(find.byType(TextField))
            .controller!;
        expect(internal.text, 'second');
        expect(internal.selection, const TextSelection.collapsed(offset: 2));
        expect(second.hasAttachedListeners, isFalse);
        expect(changes, isEmpty);
        await tester.pumpWidget(const SizedBox());
        first.dispose();
        second.dispose();
      },
    );

    testWidgets(
      '$name detaches external focus and controller listeners on disposal',
      (tester) async {
        final key = GlobalKey<FormFieldState<String>>();
        final focus = _TrackedFocusNode();
        final controller = _TrackedTextController();
        await tester.pumpWidget(
          wrap(field(key, controller, (_) {}, focusNode: focus)),
        );
        expect(focus.callbacks, isNotEmpty);
        await tester.pumpWidget(const SizedBox());
        expect(focus.callbacks, isEmpty);
        expect(controller.hasAttachedListeners, isFalse);
        focus.dispose();
        controller.dispose();
      },
    );
  }
}
