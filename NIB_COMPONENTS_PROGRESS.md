# NIB_COMPONENTS_PROGRESS.md

Tracks build status for every component in `NIB_COMPONENTS_MASTER_PROMPT.md`
section 3. Status values: `not started` / `in progress` / `built` / `tested`
/ `verified` (visually confirmed by user in `example/`).

Setup infra (git repo, `nib_motion` wiring, `example/` demo app with
Linux+web platforms) completed 2026-07-10.

**2026-07-16 — viewport/safe-area hardening (all anchored overlays).** Root cause
of overlays rendering under the status bar / off-screen on real phones: the shared
positioning core computed the side + offset against the *raw* window, never
subtracting safe-area insets (status bar, nav bar, keyboard) and never clamping the
**main** axis (only the cross axis), and flipped blindly to the opposite side instead
of the roomier one. Fixed by rewriting `overlay_positioning.dart` into one
viewport-aware `resolveOverlayGeometry` (safe insets + both-axis clamp + roomier-side
fallback; new `nibOverlaySafeInsets(MediaQueryData)` helper) and migrating every
consumer: `NibPopover`, `NibHoverCard`, `NibAnchoredOverlay` (nav flyouts/submenus),
context-menu (submenu **and** pointer-anchored root delegate), `NibDatePicker` popover
mode (via `NibAnchoredOverlay`). `NibSelect`/`NibCombobox` (trigger-width-matched, so
horizontally safe already) got safe-area-aware vertical space math; `NibCommandPalette`
wrapped in `SafeArea`. Covered by `test/overlay/overlay_positioning_test.dart` (pure
math incl. status-bar/nav-bar/main-axis regressions) + a phone-viewport widget test in
the hover-card suite. The previously-`verified` overlay components (Select, Combobox,
Date Picker, Popover, Context Menu, Navigation Menu, Command Palette) were touched by
this and warrant a quick re-confirm on a device.

Example drawer now single-lines each entry (ellipsis) with a fixed row extent, and
auto-scrolls the selected component to centre when the drawer (re)opens.

## Known gaps (deferred, not silently dropped)

| Component | Gap | Notes |
|---|---|---|
| Data Table | Screen-reader labels + tap targets fixed (2026-07-10); formal table/row/cell `SemanticsRole` still open | Arrow-key row traversal works for free (native focusable `InkWell`s + Flutter's default directional focus shortcuts — verified by test). Sortable headers now announce label+sort state, selected rows/checkboxes announce selected/checked, header height meets 48px minimum. Not done: Flutter exposes `SemanticsRole.table/row/cell/columnHeader` with debug-mode structural validation this SDK version supports — adopting it would give a screen reader a real "table" reading, but needs its own careful pass to satisfy that validation correctly. Low risk as deferred (current labels are a genuine improvement, not a stub). |
| Data Table | Pagination hook not wired | Pagination (#20) doesn't exist yet; `rows: List<T>` is already page-slice-friendly for when it lands. |
| Data Table | No sticky first column while horizontally scrolled | Plain horizontal scroll (Task 9) covers the actual "doesn't fit on a phone" case; pinning a column during that scroll is deferred, comparable in complexity to Resizable Panels (#3). |
| Navigation Menu | No hover-to-open for horizontal flyouts on desktop | Tap/click-only on every platform per the locked design spec — hover-intent timing (open/close delay tuning to avoid flicker) is explicitly Hover Card's (#12) problem space, not duplicated here. |
| Navigation Menu | No sticky/scroll-into-view for the active item in very long vertical menus | Purely a nice-to-have polish item, not required by any tested behavior; deferred rather than adding untested scroll-position logic. |
| Date Picker | Day-grid keyboard nav relies on Flutter's default directional focus traversal between focusable day `InkWell`s (Tab/arrows move focus, Enter/Space selects); no custom roving-tabindex or type-to-jump | Same approach Data Table took for row traversal. A bespoke arrow-key roving-focus handler (move ±1 day / ±7 for up-down, wrapping across month edges) would be a polish improvement but isn't required by any tested behavior. |
| Date Picker | Tapping an adjacent-month day (shown faded in the grid) selects that date but does not auto-advance the displayed month | Low-impact; the date is still correctly selected. Auto-switching the visible month on out-of-month taps is a follow-up nicety. |
| Select / Dropdown | No type-to-jump in the non-searchable trigger (typing a letter to jump to the next matching option) | Arrow-key nav + Enter/Space/Esc fully cover keyboard use (verified by test); `searchable: true` gives full typeahead. A bespoke printable-key type-ahead handler on the closed/open trigger is a polish nicety, same call Data Table/Date Picker made on roving-focus. |
| Select / Dropdown | Animated exit unmounts the overlay on a duration *estimate* (`transition.duration` + buffer, or ~450ms for springs), not a real per-animation completion callback | `NibPresence` plays the exit; the overlay's `OverlayEntry` is then removed by a timer sized to that estimate. Tween exits are exact; a very slow/custom spring could unmount slightly early. Wiring a true completion signal out of `NibPresence`/`NibMotionAnimator` would remove the estimate — deferred as a small refinement. |
| Dialog / Modal | Animated exit unmounts the `OverlayEntry` on the same duration *estimate* as Select | Identical mechanism/caveat — shares the same deferred "true `NibPresence` completion signal" refinement. Unanimated dialogs remove synchronously (exact). |
| Dialog / Modal | Screen-reader route semantics are `BlockSemantics` + `Semantics(scopesRoute/namesRoute/explicitChildNodes)`, not Flutter's full `ModalRoute` a11y | The overlay-based foundation (chosen to keep the `nib_motion` enter/exit contract) doesn't get `ModalRoute`'s route-announcement/back-button semantics for free. Focus trap, focus restore to the opener, and background semantics-blocking all work; a formal route announcement is the deferred nicety. Low risk. |
| Dialog / Modal | Declarative `NibDialog.trigger` must be non-interactive (wrapped in an opaque tap handler) | A button-style trigger would consume the tap; for a button trigger, drive via `controller` or use the imperative `showNibDialog`. Documented on the `trigger` param. |
| Bottom Sheet | No inner-scroll → sheet-drag handoff | Dragging over a scrollable body scrolls the content; the sheet is moved/dismissed by dragging the handle/title (or any non-scrolling area). Full `DraggableScrollableSheet`-style handoff (inner scroll at extent boundary hands the drag to the sheet, and vice-versa) is RenderObject/scroll-activity-level work disproportionate to the rest — deferred. Verified by test that a title-zone drag settles snaps while a body drag scrolls. |
| Bottom Sheet | Sheet transform is spring/offset-driven, not `NibMotion`-wrapped (flagged deviation, §1.4/§8.5) | The sheet position (enter, drag, snap, exit) is one continuously gesture-controlled `Transform.translate` driven by an internal `AnimationController` + `SpringSimulation`; wrapping it in `NibMotion`'s declarative enter/animate/exit variants would fight the live drag. The opt-in nib_motion contract is still honoured: settle physics flow through `nib_motion` via `transition.spring` (`NibSpringDescription.toFlutter()`), and the **barrier** enter/exit fade routes through `NibMotion`/`NibPresence` — so `animated:true` builds `NibMotion` and `animated:false` builds none (tested). Exit removal uses an exact `TickerFuture` completion (no estimate-timer, unlike Dialog/Select). |
| Bottom Sheet | Content-sized (no `snapPoints`) sheet paints one off-screen frame before the enter animation | Its height isn't known until `MeasureSize` reports after first layout, so the sheet starts fully off-screen for one frame then slides in. Imperceptible in practice; snap-point sheets don't hit this (height known from the fraction immediately). |
| Popover | Flagged one-time reorder (§5.10/§8.5): extracted the flip/clamp/anchor math into `lib/src/overlay/overlay_positioning.dart` | `NibAnchoredOverlay`'s private `_resolveSide`/`_anchorsFor`/`_clampOffsetFor` became pure functions (`resolveOverlaySide`/`overlayAnchorsFor`/`overlayClampOffset`) shared by the primitive (NavMenu) and `NibPopover`, so the anchoring logic lives in one tested place. `NibOverlayPlacement` moved there and is re-exported from `nib_anchored_overlay.dart` (NavMenu untouched). Not a gap — recorded because it's a deliberate deviation from strict "don't touch shared code" and satisfies the master prompt's "get anchoring right once" note. `NibPopover` hand-rolls its own animated overlay (needs the resolved side for its arrow + `nib_motion` enter/exit) rather than calling `NibAnchoredOverlay.show`, which removes immediately and exposes neither. |
| Popover | Animated exit unmounts the `OverlayEntry` on the same duration *estimate* as Select/Dialog | Shares the identical deferred "true `NibPresence` completion signal" refinement. Unanimated popovers remove synchronously (exact). |
| Popover | Arrow is centered on the content panel's own width, not re-aimed at the trigger center when the panel is edge-clamped/offset; filled with the card colour (no border seam) | Cosmetic. Looks right in the common (unclamped) case; a clamped panel near a screen edge can have its arrow sit off the trigger's centre. Re-aiming the arrow to the trigger under clamp is a follow-up nicety. |
| Popover | Non-modal: Escape closes and the panel autofocuses (so keyboard/`Escape` work), but Tab focus is **not** trapped inside the panel | Intentional — a popover isn't a modal; unlike `NibDialog` it doesn't dim/block the app or trap focus. Consumers needing a focus trap should use `NibDialog`/`showNibBottomSheet`. |
| Context Menu | Submenus open on tap / →-arrow / Enter only — no hover-to-open | Hover-intent open/close timing (avoiding flicker) is explicitly Hover Card's (#12) problem space, the same call Navigation Menu made. Rows still highlight on hover; a hover *opens the submenu* only via a deliberate tap/keypress. |
| Context Menu | Enter animation only (via `NibMotion`), no exit motion — the menu (and its whole chain) is removed synchronously on select/dismiss | Matches `NibNavigationMenu`'s flyouts (also enter-only) and conventional native context menus, which disappear instantly. A coordinated exit motion across the chained overlay entries would need `NibPresence`-style deferral on every level at once; deferred as a nicety. `animated:false` builds zero `NibMotion`. |
| Context Menu | Reuses the shared `overlay_positioning.dart` core for **submenu** flip/clamp, but the **root** menu is placed at the pointer by a `SingleChildLayoutDelegate` (pointer-anchored, not widget-anchored) | Correct by design per §5.11 ("positioning at the exact pointer location", not a widget's bounds). The delegate clamps the root within the viewport (nudging up/left off the bottom/right edges); submenus anchor to their parent item and flip end→start via the shared functions. |
| Liquid Glass | True edge refraction/lensing is **Impeller-only** (`ImageFilter.shader`); non-Impeller backends get a frosted `ImageFilter.blur` + painted tint + rim fallback | The `NibGlass` engine (in `nib_motion`, shader `liquid_glass.frag`) auto-detects `ImageFilter.isShaderFilterSupported` and never throws. On Linux run `flutter run -d linux --enable-impeller` to see real lensing; plain runs show the (still glassy) fallback. The shader also needs bounded constraints to size its `uSize` uniform — unbounded layout falls back too. |
| Liquid Glass | Shader visuals (refraction ring, specular rim) are **visual-confirm-only** — not unit-tested (GPU output can't be asserted in the widget-test harness, which runs without Impeller) | TDD covers the testable surface: `glassLightFromPointer` math, fallback rendering (`BackdropFilter` present, no throw), clip selection (`ClipRRect` vs `ClipPath`), `animated` on/off (`NibMotion` present/absent), and interactive pointer handling. The shader itself is compiled-verified (impellerc) and bundles cleanly (nib_motion's 301 tests pass). |
| Liquid Glass | With a custom `clipper` the shader's refraction is still computed from a **rounded-rect SDF**, not the custom path | The clip applies correctly (any shape), and blur/tint/rim look right, but the *lensing ring* follows a rounded rect, so on a very non-rectangular custom shape the refraction won't hug the true edges. Matching the SDF to an arbitrary path would need the path rasterised into the shader (a v2 nicety). Rounded-rect/capsule shapes (the common case) are exact. |
| Liquid Glass | No chromatic aberration / animated caustics | The rim highlight + lens ring cover the core Apple look; per-channel refraction offset and flowing caustics are a v2 polish pass. |
| Carousel | `NibCarouselController` is a `part of nib_carousel.dart` (not a standalone exported controller file like the other components) | Deliberate §8.5 deviation: the controller drives the live `PageController` in the widget's private `State` and must read/write its private members, which cross-file libraries can't do. `part`/`part of` shares the library so the private handshake stays private; the type is still exported transitively via the barrel's `nib_carousel.dart` export. |
| OTP Input | `NibCircularLoader` (custom-painter indeterminate spinner) landed early with OTP, before #32 Progress — Circular | User-requested rich loader for the keypad's confirm-slot loading state. Lives in `lib/src/loader/nib_circular_loader.dart`, exported + reusable. Uses its own `AnimationController` (a continuous indeterminate spinner, like Flutter's `CircularProgressIndicator`) rather than the opt-in `nib_motion` transition contract — that contract is for enter/animate/exit, not a perpetual loop. When #32 Progress — Circular is built it should reuse/extend this rather than duplicate. |
| Accordion | Expand/collapse **height** reveal is driven by a per-section `AnimationController` (ClipRect + `Align(heightFactor)`), not `nib_motion` (§1.4/§8.5 flagged deviation) | Layout height isn't a transform/opacity/rotate, so it can't route through `nib_motion`'s `NibAnim` model — same precedent as Bottom Sheet's gesture transform. The `nib_motion` contract is still honoured for the decorative part: the chevron rotation goes through `NibMotion` (`rotate`), so `animated:true` builds `NibMotion` and `animated:false` builds none (tested). Single-open coordination lives in `NibAccordionController` (the `ExpansionTile` gap). |
| OTP Input | On-screen keypad is `NibOtpKeyboard.onScreen`; system keyboard is the default | Two varieties per the banking/ATM use case. Keypad is fully stylable (`NibOtpKeypadStyle`), has an overridable `confirmButton` slot (bottom-left, opposite backspace), a `loading` state (greys cells + keys, shows `NibCircularLoader` in the confirm slot), and `onConfirm`. Auto-verify = wire `onCompleted` → set `loading`. |
| Carousel | Peek uses `PageView.viewportFraction`, computed once from the first-layout width | `peekExtent` (logical px) → fraction needs the width, so the `PageController` is created lazily on first `LayoutBuilder` pass and kept (recreating on width change would reset scroll). A hard viewport-width change (e.g. desktop resize) keeps the original peek fraction. Pass `viewportFraction:` directly to opt out of px-based peek. |

## Tier A — Hardest

| # | Component | Status | Date |
|---|---|---|---|
| 1 | Data Table | verified | 2026-07-10 |
| 2 | Navigation Menu | verified | 2026-07-11 |
| 3 | Resizable Panels | verified | 2026-07-11 |
| 4 | Command Palette | verified | 2026-07-11 |
| 5 | Combobox | verified | 2026-07-11 |
| 6 | Date Picker / Calendar | verified | 2026-07-12 |
| 7 | Select / Dropdown | verified | 2026-07-12 |
| 8 | Dialog / Modal | verified | 2026-07-13 |
| 9 | Bottom Sheet | verified | 2026-07-13 |
| 10 | Popover | verified | 2026-07-14 |
| 11 | Context Menu | verified | 2026-07-14 |
| 12 | Hover Card | verified | 2026-07-16 |
| 13 | Liquid Glass Container | verified | 2026-07-14 |

> **Reorder (2026-07-14, user-directed, §8.5):** build #13 Liquid Glass Container before
> #12 Hover Card, then return to #12. Design approved; spec in
> `docs/superpowers/plans/2026-07-14-liquid-glass.md`. Shader engine (`NibGlass` +
> `liquid_glass.frag`) lives in the sibling `nib_motion` package; the `nib_components`
> component `NibLiquidGlass` wraps it.

 Liquid Glass Container : a perfect clone of apple liquid glass ui feature that can server multiple purpose like a container can take animation properties and gestures and clip paths to give user all control they need to build exactly what they what with it

## Tier B — Standard

| # | Component | Status | Date |
|---|---|---|---|
| 13 | Carousel | verified | 2026-07-16 |
| 14 | OTP Input | verified | 2026-07-16 |
| 15 | Accordion | verified | 2026-07-16 |
| 16 | Tabs | not started | |
| 17 | Toast | not started | |
| 18 | Button | not started | |
| 19 | Slider | not started | |
| 20 | Pagination | not started | |
| 21 | Breadcrumb | not started | |
| 22 | Textarea | not started | |
| 23 | Input | not started | |
| 24 | Radio Group | not started | |
| 25 | Checkbox | not started | |
| 26 | Switch | not started | |
| 27 | Toggle Group | not started | |
| 28 | Card | not started | |
| 29 | Alert | not started | |
| 30 | Label | not started | |

## Tier C — Simplest

| # | Component | Status | Date |
|---|---|---|---|
| 31 | Skeleton | not started | |
| 32 | Progress — Circular | not started | |
| 33 | Progress — Linear | not started | |
| 34 | Avatar | not started | |
| 35 | Toggle | not started | |
| 36 | Badge | not started | |
| 37 | Separator | not started | |
