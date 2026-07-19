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
