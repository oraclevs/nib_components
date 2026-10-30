<p align="center">
  <a href="https://www.nibmotion.xyz"><img src="https://www.nibmotion.xyz/brand/nib-mark.svg" width="240" alt="Nib" /></a>
</p>

# nib_components

[![pub package](https://img.shields.io/pub/v/nib_components.svg?label=pub.dev&color=02569B)](https://pub.dev/packages/nib_components)
[![pub points](https://img.shields.io/pub/points/nib_components?color=02569B)](https://pub.dev/packages/nib_components/score)
[![license](https://img.shields.io/github/license/oraclevs/nib_components?color=02569B)](LICENSE)
[![platform](https://img.shields.io/badge/platform-flutter-54C5F8.svg)](https://flutter.dev)

[Component catalog](https://www.nibmotion.xyz/components) ·
[Documentation](https://www.nibmotion.xyz/docs/components/button) ·
[Examples](https://www.nibmotion.xyz/examples) ·
[Playground](https://www.nibmotion.xyz/playground/components/button)

A Flutter UI component library with 30+ themed widgets built on
[`nib_motion`](https://pub.dev/packages/nib_motion).

Start with a widget and a callback. Register `NibTheme` when your app has its
own colors and radii. Some components also accept a controller for external
state, and several accept `animated: true` for state transitions.

## What is included

- 30+ components for forms, overlays, navigation, data display, and effects.
- Form fields that work inside `Form`, with callbacks for controlled state.
- Controllers for components such as data tables and selects when you need to
  manage their state from outside the widget.
- Light and dark palettes through `NibTheme`, a `ThemeExtension` you can
  register to customize colors and radii.
- Optional `nib_motion` transitions through `animated: true`. Loading indicators
  animate while active.
- Field sizing and equal-width toggle segments for responsive layouts.

## Installation

```bash
flutter pub add nib_components
```

This also installs `nib_motion`. Version 0.2.3 requires Motion 0.3.5 or later
within the 0.3 series, including its water APIs. Keep this requirement in mind
if your app pins or overrides Motion.

The package requires Dart 3.12.1 or later (below 4.0) and Flutter 3.29 or later.
Both constraints apply; use a Flutter SDK that includes a compatible Dart SDK.

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Optional: register NibTheme to customize the design tokens.
      // Omit this and components still work, falling back to the built-in
      // light/dark palettes by ambient brightness.
      theme: ThemeData(extensions: const [NibTheme.light]),
      darkTheme: ThemeData(extensions: const [NibTheme.dark]),
      home: Scaffold(
        body: Center(
          child: NibButton(
            label: 'Click me',
            variant: NibButtonVariant.primary,
            onPressed: () {},
          ),
        ),
      ),
    );
  }
}
```

Reach for a controller when you need external control:

```dart
final controller = NibDataTableController();
// ...
NibDataTable(controller: controller, columns: columns, rows: rows);
// ...
controller.sortBy('name');
```

For a form with a fixed field height and a short input limit:

```dart
NibInput(
  label: 'Event name',
  minHeight: 51,
  maxLength: 90,
  onChanged: (value) {},
)
```

## Components

**Forms & inputs**
Button · Input · Textarea · Checkbox · Switch · Radio Group · Slider · Select ·
Combobox · OTP Input · Toggle Group · Date Picker

**Overlays & popups**
Dialog · Alert · Bottom Sheet · Popover · Hover Card · Context Menu ·
Command Palette · Toast

**Navigation**
Tabs · Breadcrumb · Pagination · Navigation Menu

**Layout & data**
Card · Flip Card · Data Table · Accordion · Carousel · Resizable Panels

**Feedback & effects**
Skeleton · Circular Loader · Liquid Glass · Water Glass (experimental)

`NibWaterGlass` forwards `sampling`, `quality`, `material` and `sampleInterval`
to the shared NibMotion renderer. Choose `NibWaterSampling.live` for changing
underwater content; the default preserves legacy snapshot sampling. Enable
`animated: true` for waves and emitted bubbles.

**Supporting APIs**
`NibTheme` (design tokens) · `NibValidators` (form-field validation helpers)

## Theming

`NibTheme` is a `ThemeExtension<NibTheme>` carrying the design tokens (colors and
border radii). Components read them via `NibTheme.of(context)`.

Without a registered extension, `NibTheme.of` falls back to `NibTheme.light`
or `NibTheme.dark` based on the ambient `Brightness`. Register your own instance
to override tokens:

```dart
ThemeData(
  extensions: [
    NibTheme.light.copyWith(primary: const Color(0xFF6D28D9)),
  ],
);
```

Dialogs, bottom sheets, and toasts also follow the caller's theme when it
changes while they are open.

## Example app

The runnable component gallery lives in [`example/`](example/). Run it with:

```bash
cd example
flutter pub get
flutter run
```

Try the [online component playground](https://www.nibmotion.xyz/playground/components/button)
for interactive examples and configurable source code.

## Help

See the [component catalog](https://www.nibmotion.xyz/components) and
[documentation](https://www.nibmotion.xyz/docs/components/button) for usage guidance. Report bugs
with a small reproduction in the
[issue tracker](https://github.com/oraclevs/nib_components/issues).

## License

[MIT](LICENSE)
