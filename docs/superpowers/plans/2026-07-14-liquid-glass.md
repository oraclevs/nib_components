# Liquid Glass Container — design & plan (2026-07-14)

Component #13 (built before #12 Hover Card, per user reorder). A "true" Apple
Liquid Glass material: shader-backed backdrop **refraction/lensing** + frosted
blur + tint + specular rim highlight, with a graceful non-shader fallback.

## Architecture — two packages

The shader engine lives in **`nib_motion`** (the effects package that already
ships `.frag` assets + `NibShaderLoader`); the ergonomic component lives in
**`nib_components`**.

### `nib_motion` — the glass engine

- `lib/shaders/liquid_glass.frag` — SDF rounded-rect glass. Uniforms (order
  matters; `ImageFilter.shader` requires the **first** uniform be a `vec2` and at
  least one sampler):
  1. `uSize` (vec2) — widget size, px
  2. `uRadius` (float) — corner radius, px
  3. `uRefraction` (float) — edge lens displacement, px
  4. `uHighlight` (float) — specular intensity 0..1
  5. `uLight` (vec2) — light/pointer direction
  6. `uTint` (vec4) — rgba tint
  7. `uTexture` (sampler2D) — the backdrop, auto-bound by `ImageFilter.shader`

  Logic: rounded-rect SDF → analytic edge normal (radial at corners, axis-aligned
  on flat edges) → displace the backdrop sample along the normal within an edge
  band (the "lens ring") → mix tint → add rim specular where the edge normal
  aligns with `uLight`. GLES y-flip guarded by `IMPELLER_TARGET_OPENGLES`.
- `NibShaderLoader.liquidGlass()` + asset const (mirrors shimmer/dissolve).
- `NibGlass` widget: `LayoutBuilder` → build filter for the known size →
  `ClipRRect(BackdropFilter(filter, child))`.
  - **Impeller** (`ImageFilter.isShaderFilterSupported == true`, program loaded):
    `filter = ImageFilter.compose(outer: ImageFilter.shader(glass), inner:
    ImageFilter.blur(sigma))` — frosted **and** refracted.
  - **Fallback** (non-Impeller / program not ready / unbounded size): frosted
    `ImageFilter.blur` + a painted tint + specular rim overlay. Still reads as
    glass, no lensing. Never throws.
  - Params: `child, borderRadius, blurSigma, tint, refraction, highlight,
    lightDirection`.

### `nib_components` — the component

- `NibLiquidGlass` (`lib/src/liquid_glass/`): wraps `NibGlass` with
  - `NibTheme` token defaults (tint/blur/radius; light+dark),
  - **gesture-driven light** (`interactive` — a `MouseRegion`/`GestureDetector`
    maps the pointer to `lightDirection` via the pure `glassLightFromPointer`
    fn; press adds a subtle scale via `nib_motion` under the `animated` contract),
  - **custom shape** (`clipper: CustomClipper<Path>?` / `borderRadius`) for
    capsule/blob/arbitrary shapes,
  - standard `animated`/`transition` contract (zero `NibMotion` when false).

## What is TDD-tested vs visual-only

- **Unit/widget tests:** `glassLightFromPointer` math; `NibGlass` builds a
  `BackdropFilter` and never throws on the (non-Impeller) test backend;
  param/tint/radius plumbing; `NibLiquidGlass` applies a `ClipPath` when a
  `clipper` is given; `animated` on/off builds `NibMotion` or not; `interactive`
  updates the light on pointer move.
- **Visual-confirm only (GPU):** the actual refraction/highlight. Real lensing
  shows only under Impeller — on Linux run `flutter run -d linux
  --enable-impeller`; plain run shows the fallback. Example demos place glass
  over a colorful/photo backdrop so the effect is visible.

## Build order

1. `nib_motion`: `liquid_glass.frag` → `pubspec.yaml` shaders → `shader_loader`
   asset+loader → `NibGlass` → barrel export → `flutter analyze`/`test` motion.
2. `nib_components`: light math (+test) → `NibLiquidGlass` (+tests) → barrel →
   examples + catalog → full `flutter test` + analyze (pkg + example).
3. Mark `built — awaiting visual confirm`; user confirms under `--enable-impeller`.

## Known risks / deferrals

- Shader path is Impeller-only; documented, with a real fallback (not a stub).
- `NibGlass` needs bounded constraints to size the shader; unbounded → fallback.
- No true chromatic aberration / animated caustics (a v2 nicety); rim + lens ring
  cover the core look.
