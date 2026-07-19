# nib_components

A native, installable Flutter UI component library — 30+ themed, animated,
controller-driven widgets built on [`nib_motion`](https://pub.dev/packages/nib_motion).

`nib_components` is a batteries-included widget set inspired by the ergonomics of
modern web component libraries: every component works with zero configuration,
adapts to light and dark mode automatically, stays responsive on narrow
viewports, and exposes an optional controller for programmatic control when you
need it.

## Highlights

- **30+ components** — inputs, overlays, navigation, data display, and effects.
- **Stateful by default** — pass plain parameters; each widget manages its own
  loading/selection/sort state internally. No wiring required for basic use.
- **Optional controllers** — reach for a `Nib<Component>Controller` (a
  `ChangeNotifier`) only when you want to drive a component from the outside.
- **Theme-aware** — every color and radius comes from `NibTheme`, a
  `ThemeExtension`. Works out of the box and follows light/dark by ambient
  brightness; register the extension to customize the tokens.
- **Motion built in** — animations route through `nib_motion`. Every component
  is static by default and animates only when you opt in with `animated: true`.
- **Responsive** — components fall back to a scrollable axis instead of clipping
  or squishing content when space is tight.

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

## Example app

A runnable gallery of every component lives in [`example/`](example/). Run it on
desktop with:

```bash
cd example
flutter run
```

## License

[MIT](LICENSE)
