## 0.2.0

**Fixes**

- `NibInput`, `NibTextarea`, `NibSelect`, `NibCombobox`, `NibCommandPalette`:
  the internal `TextField` no longer inherits an ambient
  `ThemeData.inputDecorationTheme` fill color — a host app setting
  `filled: true, fillColor: ...` globally used to paint a second,
  different-colored background behind just the typed text, independent of
  `backgroundColor`. Fixed by making every internal field explicitly
  `filled: false`.
- Website docs: the `NibInput` example used a `hintText` parameter that
  doesn't exist on the real widget (the real name is `placeholder`).

**New — style escape hatches (no breaking changes)**

- `NibButton`: `backgroundColor`, `foregroundColor`, `borderColor`,
  `borderWidth`.
- `NibInput`, `NibTextarea`: `backgroundColor`, `borderColor`, `borderWidth`.
- `NibSelect`: `backgroundColor`, `borderColor`, `borderWidth`,
  `borderRadius`, `padding`, `placeholderStyle`.
- `NibCombobox`: `backgroundColor`, `borderColor`, `borderWidth`,
  `borderRadius`, `padding`, `hintStyle`.
- `NibCommandPalette`: `backgroundColor`, `hintStyle`.

## 0.1.0

Initial release.

A native Flutter UI component library built on `nib_motion`, with 30+
theme-aware, responsive, controller-driven components:

- **Forms & inputs** — Button, Input, Textarea, Checkbox, Switch, Radio Group,
  Slider, Select, Combobox, OTP Input, Toggle Group, Date Picker.
- **Overlays & popups** — Dialog, Alert, Bottom Sheet, Popover, Hover Card,
  Context Menu, Command Palette, Toast.
- **Navigation** — Tabs, Breadcrumb, Pagination, Navigation Menu.
- **Layout & data** — Card, Flip Card, Data Table, Accordion, Carousel,
  Resizable Panels.
- **Feedback & effects** — Skeleton, Circular Loader, Liquid Glass.
- **Supporting APIs** — `NibTheme` design tokens and `NibValidators` form
  helpers.

Every component is stateful-by-default with an optional `ChangeNotifier`
controller, follows light/dark mode via `NibTheme`, and opts into `nib_motion`
animations only when `animated: true`.
