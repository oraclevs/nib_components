# Command Palette Implementation Plan

> **For agentic workers:** solo sessions in `nib_components` write code directly in the main
> session using TDD (per this repo's `CLAUDE.md`) — no fresh-implementer/fresh-reviewer
> subagent pattern by default.

**Goal:** Ship `NibCommandPalette` — component #4 in the Tier A build order.

## Why it's hard (master prompt §5.4)

Global keyboard shortcut capture, focus handling, fuzzy/substring filtering, nested
sub-action drill-down, and it must not conflict with the host app's own shortcuts.

## Architecture decision: wrapping widget, not a `show()` dialog helper

Unlike Data Table/Navigation Menu/Resizable Panels (rendered in place), Command Palette is
overlay-triggered like the not-yet-built Popover/Dialog. But its "global shortcut" requirement
needs *something* mounted for the lifetime of the scope it should work in — a `showDialog`-style
static method can't listen for Cmd+K before it's ever been called.

So `NibCommandPalette` wraps a subtree:

```dart
NibCommandPalette(
  actions: [...],
  child: MyAppOrPageContent(),
)
```

- `build()` returns `widget.child` unchanged when closed — no wrapping `Stack`/`Focus` shim
  in the main tree, so opening/closing the palette never rebuilds `child`'s subtree (satisfies
  master prompt §1.3's "must not rebuild descendant subtree unnecessarily"). The overlay UI
  lives entirely in an `OverlayEntry` inserted via `Overlay.of(context)`, same mechanism
  `NibAnchoredOverlay` already uses (not reused directly — that primitive is anchor-relative
  positioning for triggers with a `LayerLink`; Command Palette is always centered/top-of-screen
  like a modal, closer to `Dialog`'s eventual shape than Popover's).
- The global shortcut is captured via `HardwareKeyboard.instance.addHandler` in `initState`
  (removed in `dispose`), matched against a `ShortcutActivator` (default: a `SingleActivator`
  computed from `defaultTargetPlatform` — `meta: true` on macOS/web-on-mac, `control: true`
  elsewhere) using the activator's own `.accepts(event, HardwareKeyboard.instance)` — this
  reuses Flutter's real shortcut-matching logic instead of hand-rolling modifier-key checks,
  while still firing regardless of where focus currently is (a plain `Shortcuts` widget only
  fires along the focused node's ancestor chain, which is wrong for "works even with nothing
  focused yet"). The handler only consumes (`return true`) the event when it both matches and
  the palette is currently closed; otherwise it returns `false`, so it never blocks the host
  app's own bindings for any other key combination, and doesn't swallow a second press of the
  same combo while already open (harmless no-op, lets typing continue in the search field).
- Escape-to-close, arrow up/down, and Enter are scoped *locally* to the overlay content via
  `CallbackShortcuts` (not another global handler) — the search field autofocuses when the
  overlay opens, so focus is always inside the overlay while it's up, and arrow/escape/enter
  aren't consumed by a single-line `EditableText` (no vertical caret movement), so they bubble
  to `CallbackShortcuts` exactly like `RawAutocomplete`'s own options-list navigation.
- Programmatic (keyboard-free) open goes through `NibCommandPaletteController.open()` —
  required by master prompt §5.4 ("must work without a physical keyboard too") and §1.1's
  accessibility bar. A consumer wires a trigger `IconButton` to the same controller instance
  passed into `NibCommandPalette(controller: ...)`.

## API surface

`lib/src/command_palette/nib_command_action.dart`
- `class NibCommandAction` — `id`, `label`, `subtitle`, `icon` (Widget?), `shortcutLabel`
  (display-only string hint, e.g. `'⌘S'` — not a real shortcut binding), `group` (String?,
  section header key), `children` (`List<NibCommandAction>`, default empty — non-empty means
  selecting this action drills into its children instead of firing selection), `onSelected`
  (`VoidCallback?`), `disabled` (`bool = false`). `bool get hasChildren`.
- `typedef NibCommandActionFilter = bool Function(NibCommandAction action, String query)`.

`lib/src/command_palette/nib_command_palette_filter.dart` (pure, unit-testable, no Flutter
widget imports beyond `foundation`)
- `bool defaultCommandActionFilter(NibCommandAction action, String query)` — case-insensitive
  substring match against `label` OR `subtitle`; empty query always matches.
- `List<NibCommandAction> filterActions(List<NibCommandAction> actions, String query, NibCommandActionFilter filter)`
  — filters, preserving input order (no re-sorting by match position — simplicity over a
  fuzzy-scoring rabbit hole; "fuzzy/substring" per spec is satisfied by substring matching on
  label/subtitle, which is the same bar `Autocomplete`'s own default matcher clears).
- `List<({String? group, List<NibCommandAction> actions})> groupActions(List<NibCommandAction> actions)`
  — clusters by `group`, preserving first-appearance order of each group key; a run of
  consecutive ungrouped (`group == null`) actions becomes one `group: null` bucket (rendered
  without a header) rather than one bucket per item.

`lib/src/command_palette/nib_command_palette_controller.dart`
- `class NibCommandPaletteController extends ChangeNotifier` — `bool get isOpen`, `open()`,
  `close()`, `toggle()`, `List<String> get recentActionIds` (MRU, capped), `recordUsed(String id, int maxRecent)`
  (internal-facing but public so a host app could seed/inspect it), all notifying listeners.
  Never required for basic use — `NibCommandPalette` creates/owns/disposes its own when
  `controller` is null, following the exact `_bindController`/`_unbindController`/
  `_ownsController` pattern from `NibNavigationMenu`/`NibResizablePanels`.

`lib/src/command_palette/nib_command_palette_content.dart` (private-ish overlay body,
exported only if useful for tests; the overlay's actual visible UI)
- Stateful: query text, drill-down stack (`List<NibCommandAction>`, root = `[]`), highlighted
  index within the *currently visible flattened* action list (recomputed on query/stack
  change, clamped to bounds).
- Layout: `LayoutBuilder` centered near the top of the screen (per master prompt §1.7 —
  responsive, not just "technically fits"): `maxWidth = min(640, screenWidth - 32)`,
  `maxHeight = min(420, screenHeight * 0.7)`, scrollable action list inside a bounded
  `ListView` (never eagerly unbounded — reuses the "don't build all rows eagerly" spirit from
  Data Table, though action counts here are expected to be small, not virtualized).
- Renders: search `TextField` (autofocus, `placeholder` hint text), breadcrumb row when the
  drill-down stack is non-empty (parent action labels + a back affordance), grouped/filtered
  action list (section headers from `groupActions`, or the "Recent" pseudo-group first when
  query is empty, `showRecent` is true, and history is non-empty), "no results" text when
  filtered list is empty, each row showing icon/label/subtitle/shortcutLabel/chevron-if-has-children,
  disabled rows dimmed and excluded from keyboard nav and tap.
- Keyboard (`CallbackShortcuts`): arrowDown/arrowUp move highlight among enabled rows only
  (wraps), enter activates the highlighted row (drill in if `hasChildren`, else select+close),
  escape pops one drill-down level if not at root, else closes the whole palette, backspace
  with an empty query also pops one level (common command-palette convention, cheap to add).

`lib/src/command_palette/nib_command_palette.dart`
- `class NibCommandPalette extends StatefulWidget` — constructor: `required child`,
  `required actions`, `openShortcut` (`ShortcutActivator?`), `filter`
  (`NibCommandActionFilter?`), `placeholder = 'Type a command or search…'`,
  `onActionSelected` (`ValueChanged<NibCommandAction>?` — fires for every leaf selection, in
  addition to that action's own `onSelected` if set: action-level first, then this), `showRecent = true`,
  `maxRecent = 5`, `animated = false`, `transition` (`NibTransition?` — matches the
  established codebase convention from `NibNavigationMenu`/`NibResizablePanels`, **not**
  the master prompt §4 skeleton's placeholder `NibAnimationPreset` wording, which no built
  component actually uses), `controller` (`NibCommandPaletteController?`), `semanticLabel`.
- `_NibCommandPaletteState`: binds/owns controller exactly like Nav Menu; listens to it to
  know when to insert/remove the `OverlayEntry`; registers/unregisters the
  `HardwareKeyboard` handler in `initState`/`dispose`; captures
  `FocusManager.instance.primaryFocus` before opening and restores it (`if (node?.context != null) node.requestFocus()`)
  after the overlay is removed, so closing the palette hands focus back to wherever it was.
- Overlay entry content: opaque full-screen barrier (dismiss-on-outside-tap, same
  non-translucent-so-it-doesn't-double-fire rationale as `NibAnchoredOverlay`) behind the
  centered content; when `animated`, wraps content in `NibMotion(initial: fade+scale-down,
  animate: fade+scale-1, exit: fade+scale-down, transition: widget.transition ?? default 160ms)`;
  when not animated, zero `NibMotion` widgets built (test: `find.byType(NibMotion), findsNothing`).

## Global constraints (carried from master prompt §1–2, same as prior components)

- `Nib`-prefixed names throughout; all colors/radii from `NibTheme.of(context)`; correct in
  light+dark with no extra consumer config.
- Zero required pub dependencies beyond the SDK and the existing `nib_motion` path dependency.
- Evidence requirement: run `flutter test` and `flutter analyze` and report actual output
  before claiming anything works (master prompt §1.6). Overlay/positioning component → also
  write the manual verification note (§1.6 last bullet): what was checked re: centering/
  clamping at a narrow viewport, barrier dismiss, escape, nested drill-down, animation.
- Per-action `disabled` is this component's equivalent of a top-level `disabled`/`loading`
  test (the palette itself has no loading state per §5.4's key-parameter list — not adding
  one that isn't asked for).

---

## Task list

1. **Data model + pure filter/group logic** — `nib_command_action.dart`,
   `nib_command_palette_filter.dart` + `test/command_palette/nib_command_palette_filter_test.dart`.
   Cover: substring match (case-insensitive, label and subtitle), empty query matches
   everything, grouping preserves first-appearance order, consecutive ungrouped actions
   collapse into one `null`-group bucket, disabled actions still filter/group normally
   (disabling is a rendering/interaction concern, not a filtering one).
2. **`NibCommandPaletteController`** + `test/command_palette/nib_command_palette_controller_test.dart`.
   Cover: open/close/toggle notify listeners exactly once each, `recordUsed` dedups and caps
   at `maxRecent`, most-recently-used moves to front.
3. **Overlay content widget** (`nib_command_palette_content.dart`). No dedicated unit test
   file — exercised through the wrapper's widget tests in step 5, since its behavior only
   makes sense mounted inside the real overlay/keyboard flow.
4. **`NibCommandPalette` wrapper widget** wiring HardwareKeyboard capture, overlay
   insert/remove, focus restore, barrier.
5. **Widget tests** in `test/command_palette/nib_command_palette_test.dart`. Cover: closed by
   default (no overlay content in the tree), opens on the default shortcut
   (`tester.sendKeyDownEvent`/`sendKeyUpEvent` with control or meta + K depending on
   `debugDefaultTargetPlatformOverride`), opens via `controller.open()` with zero key events,
   typing filters the list, arrow keys move highlight and wrap, enter on a leaf selects and
   closes (`onActionSelected` + action's own `onSelected` both fire), enter on a
   `hasChildren` action drills in without closing, escape pops one level then closes on a
   second press, tapping the barrier closes, a `disabled` action is skipped by arrow nav and
   inert on tap, `animated: false` → `find.byType(NibMotion), findsNothing`, `animated: true`
   → finds it, narrow viewport (e.g. `320x480` `tester.view.physicalSize`) doesn't overflow
   (no `FlutterError` from the test binding).
6. **Examples** in `example/lib/examples/command_palette_examples.dart` — (1) minimal: flat
   action list, default shortcut, no groups/icons; (2) common variant: grouped actions with
   icons and `shortcutLabel`s, plus a visible trigger `IconButton` wired to a shared
   `NibCommandPaletteController`; (3) advanced: nested sub-actions (e.g. "Change theme" →
   "Light"/"Dark"/"System"), `animated: true`, custom `filter`, `showRecent: true`. Register
   all three in `example/lib/catalog.dart` (after Resizable Panels' entries, matching build
   order) and export the new public types from `lib/nib_components.dart`.
7. **Evidence + progress update** — run `flutter test`, `flutter analyze`, paste real output;
   write the manual verification note; set `NIB_COMPONENTS_PROGRESS.md`'s Command Palette row
   to `built — awaiting visual confirm` with today's date. Do not mark `verified` — that's
   reserved for the user's own check in `example/`.
