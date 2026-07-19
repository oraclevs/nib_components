# Skeleton — Design

Status: approved, ready for implementation plan.
Component: #31 in `NIB_COMPONENTS_MASTER_PROMPT.md` §3 Tier C build order (spec
in this doc supersedes the one-line Tier C table note at §7 row 31 — scope
grew from "a shimmer-routed bone primitive" to a full auto-shading wrapper
during brainstorming; the shimmer-routing requirement itself is unchanged and
still satisfied).

## Why this is worth a real design (not a Tier C five-minute component)

The ask: wrap a component's **real, already-written** widget tree in
`NibSkeleton` and get a loading-state bone/skeleton version that mirrors its
exact layout — no hand-rebuilding the shape in a second, parallel widget tree
(the standard shadcn/MUI/Chakra `<Skeleton>` approach, and the one explicitly
rejected during brainstorming because it re-creates the whole design).

This needs an algorithm that looks at an arbitrary widget subtree and decides,
per node, "this is a text line," "this is an avatar," "this is just a layout
box, recurse into it," or "no idea, fall back." That algorithm is the entire
scope of this component — everything else it needs (shimmer sweep, dissolve
crossfade) already exists in `nib_motion` and is reused as-is (see below).

## What's reused from `nib_motion` (zero new animation/shader work)

- **`NibShimmer`** (`package:nib_motion`) — GPU shimmer-sweep shader, already
  built. Wraps the bone tree while `loading` and `animated` are both true.
- **`NibPresence` + `NibMotion`** (opacity-only `initial`/`animate`/`exit`,
  keyed children) — the existing keyed-swap/exit-animation primitive used
  elsewhere in `nib_motion`. Reused here to dissolve between the bone tree and
  the real tree on a `loading` flip, instead of introducing `AnimatedSwitcher`
  (forbidden — animation goes exclusively through `nib_motion` per master
  prompt §1.4).

The only new code in this component is the detect-and-shade algorithm and the
widget wiring around it.

## Directory layout

```
lib/src/skeleton/
  nib_skeleton.dart          (NibSkeleton widget, public API)
  nib_skeleton_shade.dart    (pure recursive shading function — no BuildContext
                              dependency except for expanding unknown
                              StatelessWidgets; independently unit-testable)
  nib_skeleton_types.dart    (NibSkeletonBone, NibSkeletonIgnore, NibSkeletonShape)
```

## Widget API

```dart
NibSkeleton({
  super.key,
  required bool loading,
  required Widget child,
  bool animated = false,
  NibTransition? transition,
  Color? baseColor,
  Color? shimmerColor,
  double fallbackWidth = 80,
  double fallbackHeight = 16,
  BorderRadius? borderRadius,
  double boneSpacing = 0,
})
```

`boneSpacing` (added post-launch, user-requested): extra gap inserted between
each pair of consecutive children in a shaded `Row`/`Column`/`Flex`, on top
of whatever real spacing the author's own layout already has (a real
`SizedBox`/`Padding` spacer is always preserved as-is regardless of this
value). `0` (default) adds none — the bone tree mirrors the real layout's
spacing exactly, no more, no less.

- `loading: false` → returns `child` untouched. No traversal, no bone
  computation, zero overhead — this is the hot path for the common case
  where a skeleton wrapper sits around content that's already loaded.
- `loading: true` → returns the shaded bone tree, computed fresh each build
  from `child` (see algorithm below).
- `animated: false` (default) → static bone colors, **instant** swap between
  bone/real tree, zero `NibMotion`/`NibShimmer`/`NibPresence` widgets built.
  Matches the master prompt §7 row 31 contract ("default off → static
  pulse-free placeholder").
- `animated: true` → **each individual bone box** (not the assembled tree as
  a whole) wrapped in its own `NibShimmer(enabled: true, baseColor:,
  shimmerColor:)`, clipped to that bone's own shape (`ClipOval` for circles,
  `ClipRRect` for rectangles). This is deliberate, not incidental: `NibShimmer`
  paints its shader as a single solid rectangle across its *entire* bounding
  box, with no awareness of what shape is underneath — wrapping the whole
  shaded tree in one `NibShimmer` flattens every distinct bone shape into one
  undifferentiated rectangle (caught via user visual confirmation after the
  first implementation; no widget-tree test had covered actual paint output).
  Swap between bone/real tree goes through
  `NibPresence` with each side keyed and wrapped in `NibMotion(initial:
  NibAnim(opacity: 0), animate: NibAnim(opacity: 1), exit: NibAnim(opacity:
  0), transition: transition ?? const NibTransition(duration: Duration(milliseconds: 220)))`
  — a pure opacity dissolve, no slide (this is a state swap, not an entrance).
- `baseColor`/`shimmerColor` default to theme-derived values, never hardcoded
  hex (master prompt rule): `baseColor ??= NibTheme.of(context).muted`,
  `shimmerColor ??= Color.lerp(baseColor, NibTheme.of(context).foreground, 0.12)`
  — a subtle lightening of the base color, direction-agnostic so it looks
  right in both light and dark themes without two separate hardcoded pairs.
- `fallbackWidth`/`fallbackHeight` size the placeholder box used for anything
  the detector can't identify (see "Fallback" below).
- `borderRadius` overrides the *default* radius applied to generic box bones
  (Container/Image-derived). Does not affect text-line bones (always fully
  rounded, see below) or `CircleAvatar`-derived bones (always a perfect
  circle) or nodes that already specify their own shape/radius (preserved
  exactly, see below).

## The shading algorithm (`nib_skeleton_shade.dart`)

A pure function, `Widget shade(BuildContext context, Widget node, _BonePalette palette)`,
called once per build when `loading == true`, dispatching on `node.runtimeType`
into one of four buckets. `_BonePalette` is an internal (unexported) struct
bundling the already-resolved `baseColor`/`shimmerColor`/default radius for
this call — plumbing, not public API.

`NibSkeletonBone` and `NibSkeletonIgnore` (see "Escape hatches" below) are
checked before any of buckets 1–4, since they're explicit author overrides
and should always win over automatic detection.

### 1. Leaf types → bone shape from the node's own constructor params

No RenderObject introspection, no layout/measure pass — every size comes
directly off properties already present on the widget instance:

| Node type | Bone shape |
|---|---|
| `Text` / `RichText` / `SelectableText` | Rectangle bone bar. Width from a `TextPainter` laid out with the node's real `style`/`data`/`text` (capped to incoming constraints); height from the computed line height × line count. Radius = `height / 2` (fully-rounded pill line — the standard skeleton-text look), always, regardless of `borderRadius`. |
| `Icon` | Square bone box sized to `size` (default 24 if unset). Radius = `NibTheme.radiusSm`. |
| `CircleAvatar` | Perfect circle, diameter from `radius * 2` (falling back to `minRadius`/`maxRadius` if `radius` is unset, then a 40px default). Always circular — `borderRadius` param does not apply here. |
| `Image` (bare, no `RawImage`/`FadeInImage` in v1 — see Known gaps) | Rectangle bone sized from `width`/`height` if both set, else `fallbackWidth`/`fallbackHeight`. Uses the `NibSkeleton.borderRadius` default (a `ClipRRect`/`DecoratedBox` ancestor, if any, is a separate node handled by its own bucket). |
| `Container` / `DecoratedBox` / `ColoredBox` **with no `child`** | Rectangle bone. `Container` sizes from its `constraints` when tight (`hasTightWidth`/`hasTightHeight`), else `fallbackWidth`/`fallbackHeight`; its `BoxDecoration.shape`/`borderRadius` is read and preserved exactly (a circular `Container` bones as a circle). `DecoratedBox`/`ColoredBox` have no intrinsic size field at all when childless, so they always use `fallbackWidth`/`fallbackHeight`. |
| `SizedBox` **with no `child` and *both* `width`/`height` set** | Rectangle bone sized to match — this is the "bare `SizedBox` as an image/avatar placeholder" idiom. A childless `SizedBox` with only *one* dimension set (`SizedBox(width: 12)`) is the idiomatic Flutter spacer, not content, and is returned unchanged (invisible) rather than boned — see "Known gaps" for why this needed a fix after the first visual pass. |

### 2. Structural types → pass through unchanged, recurse into children

Explicitly reconstructed with their own non-child fields preserved exactly,
children replaced by their shaded versions — layout stays pixel-identical to
the real tree: `Row`, `Column`, `Flex`, `Padding`, `Align`, `Center`,
`Expanded`, `Flexible`, `Stack`, `Wrap`, `ConstrainedBox`, `SizedBox` /
`Container` / `DecoratedBox` / `ColoredBox` (each **with a `child`** — the
complement of their bucket-1 childless case above).

`GestureDetector` and `SafeArea` need no explicit case — both are plain
`StatelessWidget`s under the hood, so bucket 3's auto-expand already recurses
through them for free. `Positioned` (a `Stack`-only `ParentDataWidget`),
`AspectRatio`/`IntrinsicHeight`/`IntrinsicWidth` (single-child
`RenderObjectWidget`s), `Material`, and `InkWell` (both `StatefulWidget`s) are
**not** given explicit structural cases in v1 — each would need the same
per-field reconstruction effort as `Row`/`Flex`, for lower expected payoff.
They fall through to bucket 4's fallback box; see Known gaps.

### 3. Unrecognized `StatelessWidget` → auto-expand

For any `StatelessWidget` not matched by bucket 1 or 2 (the "your own
`ProfileHeader` class" case), call `(node as StatelessWidget).build(context)`
directly and recurse into the result. This transparently unwraps arbitrary
user composite widgets down to the `Text`/`Icon`/`CircleAvatar`/etc. inside,
with no configuration required.

`build()` is `@protected` by Flutter/`package:meta` convention only — Dart
does not enforce it at the language level, and `build()` must be side-effect
free per Flutter's own contract, so calling it ourselves ahead of the normal
`Element` is safe in practice. `Builder` widgets are handled the same way
(call `builder(context)`, recurse into the result).

Also covers `StatelessWidget`s that resolve to `null`-safe fallback content —
if calling `build()` throws (e.g. a widget that assumes an `InheritedWidget`
only available lower in the real tree at a different point than where
`NibSkeleton` sits), the shader catches and falls back to bucket 4 for that
node rather than crashing the whole tree.

### 4. Fallback — `StatefulWidget`, custom `RenderObjectWidget`, or a bucket-3 expansion failure

A `StatefulWidget` can't be safely expanded this way (`build()` needs a
mounted `State`, which we don't have and won't create speculatively). Same
for custom-painted `RenderObjectWidget`s. These become a plain rectangle bone,
sized `fallbackWidth × fallbackHeight`, radius `NibTheme.radiusDefault`.

## Escape hatches (`nib_skeleton_types.dart`)

Both wrap a **real** subtree — the point is one authored tree, not a second
parallel one:

```dart
NibSkeletonBone({
  super.key,
  required Widget child,
  double? width,
  double? height,
  NibSkeletonShape shape = NibSkeletonShape.rectangle,
})
```
While `loading`, renders an explicit bone box (`width`/`height`/`shape`)
instead of whatever the detector would have produced — the manual override
for the case the detector guesses wrong (e.g. a custom chart). While not
`loading`, renders `child` normally.

```dart
NibSkeletonIgnore({ super.key, required Widget child })
```
Always renders `child` as-is, loading or not — e.g. a static logo/icon that
isn't data-dependent and shouldn't be boned at all. The shader returns
`node.child` unchanged and does not recurse into it (intentionally — if it
happens to contain `Text`, that text is meant to stay visible).

`NibSkeletonShape` is a 2-value enum: `rectangle`, `circle`.

## Interaction while loading

`NibSkeleton` wraps its whole output in `IgnorePointer(ignoring: loading)` at
the top level — one place to disable interaction, rather than hunting down
and neutralizing every `GestureDetector`/`InkWell` inside the shaded tree
individually.

## Narrow-viewport / responsive (§1.7)

Not applicable as a distinct requirement — `NibSkeleton` never introduces its
own layout or fixed sizing; every bone shape is derived from the real node's
own existing size/constraints, and structural nodes pass their real layout
widget through unchanged. There is no new viewport-dependent geometry for
this component to get wrong. (Noted explicitly per the standing convention of
writing down a §1.7 decision rather than silently skipping it.)

## Testing plan (per §1.6)

Most of this is testable as a pure function (`shade(context, node, palette)`)
given a `BuildContext` from a minimal test harness, without needing to pump
and inspect a full render tree for every case:

- Each leaf type (§1 table) produces a bone widget of the right shape/size
  class from representative inputs (a `Text` with a known string/style, an
  `Icon` with a known `size`, a `CircleAvatar` with a known `radius`, a sized
  `Container` with a `BoxDecoration.shape`/`borderRadius`).
- Each structural type (§2 list) preserves its own type and non-child params,
  and its children are individually shaded (verified via `find.descendant`
  after pumping a small real tree).
- A custom `StatelessWidget` composing known leaf types (the `ProfileHeader`
  case) is transparently expanded — the shaded output contains bone versions
  of the `Text`/`CircleAvatar` inside, not a fallback box for the whole thing.
- A `StatefulWidget` child becomes exactly one fallback bone box sized
  `fallbackWidth × fallbackHeight`.
- A bucket-3 expansion that throws during `build()` degrades to a fallback
  box for that node only, without crashing the rest of the tree.
- `NibSkeletonBone` renders its explicit override while `loading`, and
  `child` unchanged while not.
- `NibSkeletonIgnore` renders `child` unchanged in both states, and its
  contents are not recursed into (a `Text` inside stays a real `Text`, never
  boned, even while `loading`).
- `loading: false` returns `child` with no shading pass — assert via identity
  or a spy that the shader function is never invoked.
- `animated: false`: `find.byType(NibMotion), findsNothing` and
  `find.byType(NibShimmer), findsNothing`, both while `loading` and while not.
- `animated: true`: **each individual bone box gets its own `NibShimmer`** —
  a multi-leaf child produces one `NibShimmer` per leaf, not one wrapping the
  whole tree (the regression test for the bug described above); toggling
  `loading` drives a `NibPresence`-keyed swap (both old
  and new sides transiently present with the expected `NibMotion`
  `initial`/`animate`/`exit` opacity values).
- Default `baseColor`/`shimmerColor` resolve from `NibTheme.of(context)` (no
  hardcoded hex reachable in the default path); explicit overrides win.
- Tap/gesture on shaded content is inert while `loading: true` (via the
  top-level `IgnorePointer`), and restored once `loading: false`.

## Known gaps to flag if they surface during implementation

- **Every `nib_components` widget (`NibCard`, `NibButton`, etc.) is a
  `StatefulWidget`** per this library's own stateful-by-default convention —
  meaning none of them qualify for bucket-3 auto-expand (which only handles
  `StatelessWidget`, since expanding `StatefulWidget` safely would need a
  mounted `State`). Wrapping a real `NibCard`/`NibButton` composition in
  `NibSkeleton` currently bones the *entire* `NibCard` as one flat fallback
  box, losing its internal header/padding/child structure entirely — not
  just the interactive button inside it. This is the single biggest practical
  limitation of the v1 detector for real Nib-built UI, as opposed to
  plain-Flutter-widget compositions (which it handles well). If this proves
  too limiting in practice, the fix is giving Nib's own common components
  (starting with `NibCard`, `NibButton`) explicit leaf/structural treatment
  the same way `CircleAvatar`/`Container` already get, rather than relying on
  generic `StatelessWidget` auto-expand — a separate, scoped follow-up, not
  done here pending real-world evidence of how much it matters.
- Two visual bugs only surfaced once actually rendered, not from the widget
  tests: (1) `NibShimmer` was originally wrapped once around the whole shaded
  tree — it paints its shader as one solid rectangle over its entire
  bounding box, so this flattened every distinct bone shape into one
  undifferentiated rectangle; fixed by moving the wrap into `buildBoneBox`
  (one `NibShimmer` + shape clip per bone). (2) a childless single-axis
  `SizedBox` spacer (`SizedBox(width: 12)`) was being boned into a small
  filled connector block, visually merging the two elements it was meant to
  separate; fixed by only boning a childless `SizedBox` when *both*
  dimensions are set. Both are a concrete argument for the project's
  "visual confirmation gate" convention — pure widget-tree tests verify
  structure, not what the shapes actually look like painted.
- `Positioned` (inside a `Stack`), `AspectRatio`, `IntrinsicHeight`,
  `IntrinsicWidth`, `Material`, and `InkWell` get bucket-4's flat fallback
  box in v1 rather than a structural pass-through — each would need the same
  per-field reconstruction as `Row`/`Flex` for comparatively rare payoff.
  A `Positioned` child inside a shaded `Stack` loses its exact position
  (renders as a plain, unpositioned `Stack` child) rather than crashing.
  `RawImage`/`FadeInImage` similarly fall to bucket 4 rather than `Image`'s
  bucket-1 treatment in v1.
- `Image` bones don't currently distinguish "this Image is itself wrapped in
  a circular clip by the caller" — that case already round-trips correctly
  because the clip is a separate ancestor node handled by structural
  recursion, but if implementation finds real-world layouts where this
  produces a visibly wrong shape, it's a candidate for a small dedicated rule
  rather than a silent miss.
- The bucket-3 "unrecognized `StatelessWidget`" expansion assumes `build()`
  is pure/side-effect-free, which is a Flutter convention, not a hard
  guarantee for arbitrary third-party widgets. If this surfaces a real
  problem in practice (not just a theoretical one), it goes in
  `NIB_COMPONENTS_PROGRESS.md`'s Known Gaps table.
