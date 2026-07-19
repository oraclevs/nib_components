# Skeleton Render-Mount — Offset Correctness, Stock-Material Chrome, Shimmer

Status: approved, ready for implementation plan.
Extends: `docs/superpowers/specs/2026-07-19-skeleton-render-mount.md` (the
render-mount engine). Read that first — this doc covers three follow-up fixes
to that engine's walker (`computeBonePaintCommands`) and render object
(`RenderNibSkeletonMount`), scoped and approved together in one brainstorm.

## What prompted this (and what the investigation actually found)

The render-mount engine shipped with two documented gaps: (1)
"`Material`/`PhysicalShape` chrome isn't preserved — a `NibButton`'s
pill-shaped background is missing under its correctly-boned label", and (2)
"render-mounted bones are always static — `animated: true`'s shimmer doesn't
apply to them".

Diagnostic probes against the real `NibButton`/`NibCard` sources and the
exact example-app card changed the picture substantially:

- **Gap 1's diagnosis was wrong.** `NibButton`'s pill fill is a plain
  `DecoratedBox` (`nib_button.dart` — `BoxDecoration(color: fill,
  borderRadius:, border:)`); its `Material` is `type:
  MaterialType.transparency`, which paints nothing. Same for `NibCard`. The
  walker already emits a correct decoration command for the button's chrome —
  at the wrong place. The real bug: `_childOffset` adds
  `child.renderObject.parentData.offset` on **every Element hop**, but
  `Element.renderObject` resolves to the nearest *descendant* render object,
  so a chain of N `ComponentElement`s above one render box re-adds that box's
  offset N times. Probe evidence from the example card: the avatar's
  `CircleAvatar → AnimatedContainer → Container → ConstrainedBox` chain (all
  resolving to the same `RenderConstrainedBox`, pd=(0,104)) accumulated
  (16,120) → (16,224) → (16,328) → (16,432); the Follow button's
  `NibButton → MergeSemantics` hop doubled its Row offset (170.5 → 357),
  pushing its chrome and label entirely off the 320px-wide card. That is the
  observed "floating bar, no backdrop" — the backdrop was painted, off-card.
- **The literal Material/PhysicalShape gap is real only for stock Material
  widgets.** Probe-confirmed: `ElevatedButton` and `Card` chrome go through
  `Material → _MaterialInterior → PhysicalShape → RenderPhysicalShape`
  (shapeless `Material(color:)` goes through `AnimatedPhysicalModel →
  PhysicalModel`). No Nib component needs this; a real app mixing stock
  Material widgets into a mounted subtree does.
- **Gap 2's approach is fully de-risked by `RenderNibShimmer`'s own source**:
  a raw `Ticker` writes elapsed seconds into a `MotionValue<double>`; the
  render object listens and calls `markNeedsPaint` (zero rebuilds per frame);
  the fragment shader (`shimmer.frag`) takes
  time/speed/baseColor/shimmerColor/size/angle uniforms; when the program
  hasn't loaded (which includes the entire `flutter test` harness), it
  degrades to static painting.

Scope decision (user-approved): fix all three — **A** the offset bug, **B**
stock-Material chrome, **C** shimmer on mounted bones.

## Fix A — offsets from render-tree geometry, not walk accumulation

`computeBonePaintCommands(Element element, Offset offset, NibSkeletonPalette
palette)` keeps its public signature (every existing test calls it this way),
but the recursion stops threading accumulated offsets entirely:

- At entry, resolve `rootBox = element.renderObject` once. If it isn't a
  `RenderBox`, return `const []` (nothing measurable to walk).
- Recurse passing only elements. Every command emission derives its rect by
  asking the render tree where the box actually is:

```dart
Rect _rectOf(RenderBox box, RenderBox rootBox, Offset base) {
  final position =
      MatrixUtils.transformPoint(box.getTransformTo(rootBox), Offset.zero);
  return (base + position) & box.size;
}
```

- All three command kinds (bone, decoration, realPaintThrough) use it.
  `_childOffset` is deleted. The bug class — "accumulate while walking a tree
  whose element hops don't map 1:1 to render hops" — is removed, not patched.
- `getTransformTo` composes `applyPaintTransform` up the chain, so children
  positioned by `RenderTransform`/`RenderFractionalTranslation` translations
  land correctly too (the accumulating walk was blind to those even in its
  fixed form). Stated approximation, unchanged in kind from the previous
  design: a *rotated/scaled* child positions at its transformed origin but
  keeps its untransformed size — bones are axis-aligned rects by design.
- Cost: `getTransformTo` is O(depth) per emitted command, on skeleton-sized
  subtrees (tens of nodes) during paint — negligible, and it buys correctness
  that offset-threading demonstrably didn't deliver.

Why not the minimal diff (only add `parentData.offset` when the child's
resolved render object differs from the parent element's)? It fixes the
double-add but keeps position logic spread across the recursion and stays
blind to transform-positioned children; both options were presented and the
render-geometry approach chosen.

## Fix B — stock-Material chrome (`PhysicalShape`/`PhysicalModel`)

Two new element-level cases in the walker, slotted beside the existing
`DecoratedBox`/`ColoredBox` chrome block, both "paint real chrome, then keep
recursing into children":

| Widget | Painted as |
|---|---|
| `PhysicalModel` | `BoxDecoration(color: node.color, shape: node.shape)`, plus `borderRadius: node.borderRadius` only when `shape == BoxShape.rectangle` (`BoxDecoration` asserts `borderRadius == null` for circles; `PhysicalModel` itself ignores `borderRadius` for circles too) |
| `PhysicalShape` whose `clipper is ShapeBorderClipper` | `ShapeDecoration(color: node.color, shape: clipper.shape)` — this is exactly what `_MaterialInterior` produces for `ElevatedButton`/`Card`/etc. |
| `PhysicalShape` with any other clipper | `BoxDecoration(color: node.color)` plain rect fallback |

Both reuse the existing `BonePaintCommand.decoration` kind unchanged
(`Decoration` already covers `ShapeDecoration`). Deliberate choices:

- **No elevation shadows.** Bones are flat; a skeleton casting Material
  elevation shadows would read as real chrome. (The existing `DecoratedBox`
  path paints whatever the real `BoxDecoration` contains — including its
  `boxShadow` if the author wrote one — that behavior is unchanged; we just
  don't *synthesize* shadows from `elevation`.)
- `Material(type: transparency)` (every Nib component's usage) never builds a
  `PhysicalShape`, so it keeps painting nothing — already correct.
- `Ink(decoration:)` paints onto the ancestor `Material`'s
  `_RenderInkFeatures`, which this engine never lets paint — its decoration
  is still lost. Known gap (see below), not attempted here.

`RenderNibSkeletonMount` also gains a `TextDirection` field, captured in the
Element's `_pushRoot` via `Directionality.of` and passed into the
`ImageConfiguration` used for decoration painting — directional decorations
(e.g. `BorderDirectional`, directional `ShapeBorder`s) resolve correctly.
This also fixes the same latent omission in the existing `DecoratedBox`
painting path.

## Fix C — shimmer on render-mounted bones

### nib_motion (sibling package, one-line change)

`NibShaderLoader` (`src/shaders/shader_loader.dart`) is written as
public-facing API (its own docs tell host apps to preload via it) but was
never exported from `lib/nib_motion.dart`. Add the export. Nothing else in
nib_motion changes.

### The driver widget (nib_components)

`NibSkeletonMountShimmerDriver` — a `StatefulWidget` +
`SingleTickerProviderStateMixin` living in `nib_skeleton_render_mount.dart`,
deliberately **not** exported from the package barrel (same convention as
`NibSkeletonPalette`: internal plumbing, importable by tests via the src
path). Its `State` replicates `_NibShimmerState`'s proven pattern exactly:

- `MotionValue<double> _time`; a ticker created from the mixin writes
  `elapsed.inMicroseconds / microsecondsPerSecond` into it each frame —
  `TickerMode`/lifecycle muting comes with the mixin for free.
- `NibShaderLoader.shimmer()` resolved async into `FragmentProgram? _program`
  (stays `null` forever in environments without shader support — including
  `flutter test` — and on failure).
- Builds `NibSkeletonRenderMount(palette:, time: _time, program: _program,
  child:)`.

`shadeWidget`'s bucket 4 becomes:

```dart
if (node is StatefulWidget) {
  return palette.shimmerEnabled
      ? NibSkeletonMountShimmerDriver(palette: palette, child: node)
      : NibSkeletonRenderMount(palette: palette, child: node);
}
```

`animated: false` therefore still builds **zero** animation machinery — no
driver, no ticker, no `MotionValue` — preserving the existing contract.

### The render object

`RenderNibSkeletonMount` gains:

- `MotionValue<double>? time` — listener calls `markNeedsPaint`; the setter
  swaps listeners and `dispose` removes it, mirroring `RenderNibShimmer.time`
  exactly.
- `FragmentProgram? program` — a `FragmentShader` instance is created once
  per program change.

In `paint`, a bone command with a live shader is drawn **origin-normalized**:

```dart
canvas.save();
canvas.translate(rect.left, rect.top);
// clip to the bone's own shape at the origin (oval, rrect, or rect),
canvas.drawRect(Offset.zero & rect.size, Paint()..shader = shader);
canvas.restore();
```

with uniforms per bone: `uTime = time.value`, `uSpeed = 1.5`,
`uBaseColor`/`uShimmerColor` from the palette, `uWidth`/`uHeight` = that
bone's size, `uAngle = -0.3` (mirroring `NibShimmer`'s constructor defaults —
the widget path's per-bone `NibShimmer`s run the same values). The shader
paints base fill + sweep band, so no separate solid fill is drawn under it.
Per-bone sizing is deliberate: it matches the widget path's
one-`NibShimmer`-per-bone look (each bone sweeps its own box), not one
coherent sweep across the whole mount.

- Chrome (decoration) and realPaintThrough commands stay static — parity
  with the widget path, where only bone boxes shimmer.
- Shader not (yet) loaded → the existing static solid fill — parity with
  `NibShimmer`'s own fallback.
- **No command caching**: the walker re-runs each paint frame. It's a pure
  element-tree traversal of tens of nodes (no layout, no canvas work), and a
  cache would go stale on descendant-only rebuilds the render object can't
  observe (e.g. an animating `DecoratedBox` color inside the mounted child,
  which never re-runs `_pushRoot` and needn't relayout).

### Origin-normalization note (why translate instead of drawing at offset)

`shimmer.frag` computes its band from `FlutterFragCoord()` against `uWidth`,
with no origin uniform. Drawing a bone's shader rect at a large canvas offset
without translating would shift the band's phase by that offset (and for
offsets beyond the sweep range, park the band permanently outside the bone).
Translating the canvas to the bone's top-left makes the draw's coordinates
bone-local under transform-aware `FlutterFragCoord` semantics — at worst
identical, at best exactly right. If visual confirmation still shows
far-from-origin bones not shimmering, the cause is `shimmer.frag`'s
coordinate handling and the fix belongs in nib_motion (add an origin uniform)
— flagged as a possible follow-up, not attempted here.

## Testing (per §1.6, TDD — failing test first for every behavior)

Fix A:
- Regression: a multi-hop component chain above a `Padding`-positioned child
  (`Padding(padding: EdgeInsets.all(20), child:
  _StatefulLeaf(_StatefulLeaf(Text(...))))`) emits its bone at the padding
  offset exactly once — the minimal mirror of the avatar chain's
  quadruple-add.
- The card-shape regression: a `NibButton` at the end of a positioned `Row`
  emits (a) its chrome decoration command with a rect inside the walked
  root's bounds, and (b) its label bone inside that chrome rect. (This is the
  exact shape the example app renders and the user saw broken.)
- All pre-existing render-mount walker tests pass unchanged (public
  signature and correct-by-construction expectations preserved).

Fix B:
- A `Material(color:, borderRadius:)`-chromed subtree (e.g. a plain
  `Material` with shape, and/or an `ElevatedButton`) produces a decoration
  command carrying the right color and shape, ordered before its label bone.
- A `Material(type: transparency)` subtree produces no decoration command.
- `PhysicalModel` (circle and rounded-rect) produces the matching
  `BoxDecoration` command.

Fix C:
- `animated: true` + `loading: true` → the driver widget is present, and
  `tester.binding.transientCallbackCount > 0` (a real ticker is running);
  unmounting produces no ticker-leak failure.
- `animated: false` → no driver widget anywhere,
  `transientCallbackCount == 0`, and the existing zero-`NibShimmer` contract
  test keeps passing.
- Command-level walker tests are unaffected by shimmer (commands carry
  geometry, not paint state).
- Actual shimmer pixels are unverifiable under `flutter test` (shader never
  resolves — nib_motion's own `NibShimmer` tests document this) → the moving
  sweep lands on the user's visual-confirmation gate, per repo convention.

## Interaction with the rest of NibSkeleton

Unchanged: `loading: false` passthrough, the `NibPresence`/`NibMotion`
dissolve, `boneSpacing`, escape hatches, theme-derived colors. Fix C slots
into the existing `palette.shimmerEnabled` plumbing that `buildBoneBox`
already consumes on the widget path.

## Known gaps after this work

- `Ink(decoration:)` inside a mounted subtree still loses its decoration
  (painted by the ancestor `Material`'s `_RenderInkFeatures`, which the
  engine never paints). Scoped follow-up if it surfaces in practice.
- Rotated/scaled (non-translation-transformed) children bone at their
  transformed origin with untransformed size — axis-aligned bones by design.
- Synthesized elevation shadows for `PhysicalShape`/`PhysicalModel` chrome
  are deliberately not painted (flat skeleton aesthetic).
- If visual confirmation shows far-from-origin mounted bones without a
  visible sweep, `shimmer.frag` needs an origin uniform (nib_motion
  follow-up; see origin-normalization note).
- `boneSpacing` still doesn't apply inside a render-mounted subtree
  (paint-only interception — unchanged from the render-mount design).
