# nib_components

[![pub package](https://img.shields.io/pub/v/nib_components.svg?label=pub.dev&color=02569B)](https://pub.dev/packages/nib_components)
[![pub points](https://img.shields.io/pub/points/nib_components?color=02569B)](https://pub.dev/packages/nib_components/score)
[![license](https://img.shields.io/github/license/oraclevs/nib_components?color=02569B)](LICENSE)
[![platform](https://img.shields.io/badge/platform-flutter-54C5F8.svg)](https://flutter.dev)

[Component catalog](https://www.nibmotion.xyz/components) ·
[Documentation](https://www.nibmotion.xyz/docs) ·
[pub.dev](https://pub.dev/packages/nib_components)

A Flutter UI component library with 30+ themed widgets built on
[`nib_motion`](https://pub.dev/packages/nib_motion).

Start with a widget and a callback. Register `NibTheme` when your app has its
own colors and radii. Some components also accept a controller for external
state, and several accept `animated: true` for state transitions.

## Highlights

- **30+ components** — inputs, overlays, navigation, data display, and effects.
- **Ordinary Flutter state** — form fields work inside `Form`; controlled
  widgets report changes through callbacks.
- **Controllers where useful** — data tables, selects, and other components
  expose controllers when their state needs outside control.
- **Theme-aware** — every color and radius comes from `NibTheme`, a
  `ThemeExtension`. Works out of the box and follows light/dark by ambient
  brightness; register the extension to customize the tokens.
- **Motion built in** — many state transitions opt into `nib_motion` with
  `animated: true`. Loading indicators animate while active.
- **Responsive controls** — size fields and equal-width toggle segments to
  fit a layout without changing the host app's design system.

## Installation

```bash
flutter pub add nib_components
```

This also pulls in `nib_motion`, the animation layer the components are built on.

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
Skeleton · Circular Loader · Liquid Glass

**Supporting APIs**
`NibTheme` (design tokens) · `NibValidators` (form-field validation helpers)

## Theming

`NibTheme` is a `ThemeExtension<NibTheme>` carrying the design tokens (colors and
border radii). Components read them via `NibTheme.of(context)`:

- **Zero config** — if you don't register the extension, `NibTheme.of` falls back
  to `NibTheme.light` / `NibTheme.dark` based on the ambient `Brightness`.
- **Customize** — register your own instance to override tokens:

  ```dart
  ThemeData(
    extensions: [
      NibTheme.light.copyWith(primary: const Color(0xFF6D28D9)),
    ],
  );
  ```

Dialogs, bottom sheets, and toasts also follow the caller's theme when it
changes while they are open. Your theme can change its mind; the dialog keeps
up.

## Example app

A runnable gallery of every component lives in [`example/`](example/). Run it on
desktop with:

```bash
cd example
flutter run
```

## License

[MIT](LICENSE)
