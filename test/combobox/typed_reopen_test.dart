import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

void main() {
  for (final asynchronous in [false, true]) {
    testWidgets(
      'typing reopens ${asynchronous ? 'async' : 'local'} options using the first query',
      (tester) async {
        final controller = NibComboboxController<String>();
        addTearDown(controller.dispose);
        final queries = <String>[];
        String? submitted;
        const options = [
          NibComboboxOption(value: 'apple', label: 'Apple'),
          NibComboboxOption(value: 'banana', label: 'Banana'),
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: NibCombobox<String>(
                  controller: controller,
                  options: options,
                  animated: false,
                  allowFreeText: true,
                  onFreeTextSubmitted: (value) => submitted = value,
                  asyncOptionsLoader: asynchronous
                      ? (query) async {
                          queries.add(query);
                          return options
                              .where(
                                (option) => option.label.toLowerCase().contains(
                                  query.toLowerCase(),
                                ),
                              )
                              .toList();
                        }
                      : null,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apple'));
        await tester.pumpAndSettle();
        expect(controller.isOpen, isFalse);
        // The field stays focused after a choice. Replacing its text must use
        // that first query, without a second tap or a second character.
        await tester.enterText(find.byType(TextField), 'Dragonfruit');
        await tester.pumpAndSettle();
        expect(find.text('Apple'), findsNothing);
        expect(find.text('Banana'), findsNothing);
        expect(controller.query, 'Dragonfruit');
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(
          field.controller!.selection,
          const TextSelection.collapsed(offset: 11),
        );
        if (asynchronous) expect(queries.last, 'Dragonfruit');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(submitted, 'Dragonfruit');
        expect(controller.selectedValue, 'apple');
        expect(controller.isOpen, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
