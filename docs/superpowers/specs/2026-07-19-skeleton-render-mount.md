# Skeleton Render-Mount Engine — Design

Status: approved, ready for implementation plan.
Extends: `docs/superpowers/specs/2026-07-18-skeleton-design.md` (component
#31). Read that first — this doc only covers the new fallback path added to
bucket 4 of `shadeWidget`'s dispatch.

## Why this exists

The original design's bucket 4 (`StatefulWidget` → flat fallback box) turned
out to be a hard technical wall, not a tunable risk: `State.widget` has no
public setter, so `createState()` + calling `.build(context)` directly throws
immediately for *any* `StatefulWidget`, trivial or not — confirmed against
`NibCard`/`NibButton`'s actual `State` classes, neither of which even has a
custom `initState`. Since every `nib_components` widget is a `StatefulWidget`
by this library's own convention, and "real app" cards/rows/lists are built
almost entirely from `nib_components` widgets, this wall meant essentially no
real composition auto-shaded past its outermost layer — confirmed visually:
wrapping a `NibCard` (header avatar+text, body text, footer `NibButton`s) in
`NibSkeleton` produced one small flat box, not a shaped mirror.

## Approach: mount for real, intercept only the paint

The real child is mounted as a genuine tree child — real `initState`, real
`vsync`/tickers, everything Flutter normally does. Nothing about lifecycle is
faked; a `StatefulWidget` resolves exactly as it would anywhere else. The
**only** thing this engine changes is what happens at *paint* time: instead
of letting the mounted subtree paint its real pixels, a custom `RenderObject`
walks the now-fully-resolved **Element tree** (not a render-level type table)
and substitutes bone boxes for recognized content, or keeps recursing.

This reuses the *exact same* recognized-type rules bucket 1 already has
(`Text`/`RichText`/`SelectableText`/`Icon`/`CircleAvatar`/`Image`) — the only
difference is that instead of estimating size from constructor params
(`TextPainter`, etc.), the real, already-laid-out `RenderBox.size` is read
directly. This is strictly more accurate, and it's why no separate
render-level type table is needed: `Element.widget.runtimeType` still tells
us what something *is*; only *how big it actually turned out* changes source.

Walking the Element tree instead of the render tree specifically (rather than
walking `RenderObject`s and trying to infer type from render-object shape) is
what lets this handle arbitrary nesting depth for free: `Element.visitChildren`
walks through `ComponentElement`s (`StatelessElement`/`StatefulElement`) and
`RenderObjectElement`s identically — a user's own `StatefulWidget`, wrapped
three levels deep inside someone else's `StatelessWidget`, gets walked
through with zero special-casing per wrapper type, because nothing here cares
what *kind* of Element it is, only whether its `widget` matches a recognized
content type.

### When this activates

`shadeWidget`'s bucket 4 (currently: `StatefulWidget` → `buildBoneBox(palette)`
flat fallback) becomes: `StatefulWidget` → `NibSkeletonRenderMount(child: node,
palette: palette)`. This is a **targeted fallback**, not a replacement for the
existing bucket 1–3 machinery — `Text`, `Container`, plain `StatelessWidget`
composites like the `_ProfileHeader` example all continue through the
existing, already-tested, cheaper pure-function path unchanged. Only nodes
that are themselves a `StatefulWidget` (or, transitively, contain one) go
through the render-mount engine.

## The custom Element

`SingleChildRenderObjectElement`'s actual implementation (`framework.dart`)
is ~30 lines: track a single `Element? _child`, forward `mount`/`update` to
`updateChild`, and wire `insertRenderObjectChild`/`removeRenderObjectChild`/
`moveRenderObjectChild` to the render object's single-child slot.
`_NibSkeletonMountElement` re-implements this exact pattern (its private
`_child` field isn't reachable from outside `framework.dart`, so it can't be
subclassed directly) with one addition: after every `mount`/`update`, it
pushes its own `_child` Element reference to the render object:

```dart
class _NibSkeletonMountElement extends RenderObjectElement {
  _NibSkeletonMountElement(NibSkeletonRenderMount super.widget);

  Element? _child;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) visitor(_child!);
  }

  @override
  void forgetChild(Element child) {
    assert(child == _child);
    _child = null;
    super.forgetChild(child);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _child = updateChild(_child, (widget as NibSkeletonRenderMount).child, null);
    _pushRoot();
  }

  @override
  void update(NibSkeletonRenderMount newWidget) {
    super.update(newWidget);
    _child = updateChild(_child, (widget as NibSkeletonRenderMount).child, null);
    _pushRoot();
  }

  void _pushRoot() {
    (renderObject as RenderNibSkeletonMount)
      ..rootElement = _child
      ..palette = (widget as NibSkeletonRenderMount).palette;
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    (renderObject as RenderNibSkeletonMount).child = child;
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    assert(false);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    (renderObject as RenderNibSkeletonMount).child = null;
  }
}
```

## The custom RenderObject

`RenderNibSkeletonMount extends RenderProxyBox` — layout/size behavior is
inherited unchanged (delegates to `child`'s own layout, same as
`RenderNibShimmer` already does). Only `paint` is overridden:

```dart
@override
void paint(PaintingContext context, Offset offset) {
  final root = rootElement;
  if (root == null) return;
  _paintElement(context, root, offset);
}
```

`_paintElement(context, element, offset)` — the walker, extracted as a
top-level pure-ish function taking a small **callback** for the actual draw
step (see "Testing" below for why):

1. **`NibSkeletonIgnore`** → paint the real subtree normally (find its
   `RenderBox` via `element.renderObject`, call `context.paintChild`).
2. **`NibSkeletonBone`** → paint an explicit bone box at `offset`, sized from
   the widget's own `width`/`height`/`shape` (falling back to
   `element.renderObject`'s real size if unset).
3. **Recognized content leaf** (`Text`/`RichText`/`SelectableText`/`Icon`/
   `CircleAvatar`/`Image`, plus a childless `Container`/`SizedBox` — same
   predicate bucket 1 already has) → paint a bone box at `offset`, sized from
   `element.renderObject!.size` (a `RenderBox`), shaped per the same rules
   bucket 1 already encodes (text → fully-rounded bar, icon → `radiusSm`
   square, avatar → circle, etc.).
4. **`DecoratedBox`/`ColoredBox` with a child** → paint the *real* decoration
   only (via `decoration.createBoxPainter().paint(canvas, offset,
   ImageConfiguration(size: renderBox.size))` for `DecoratedBox`, or a plain
   `canvas.drawRect`/`drawOval` of `node.color` for `ColoredBox` — deliberately
   **not** calling the real `RenderDecoratedBox.paint()`, which would
   internally repaint its real child too and defeat the whole interception),
   then recurse into the child via step 6.
5. **A leaf with no children and no recognized type** (e.g. a bare
   `CustomPaint`) → bone box sized to `element.renderObject!.size` — better
   than the old fixed-fallback default, since the real size is now known.
6. **Everything else** (`Row`/`Column`/`Padding`/`Align`/any `ComponentElement`
   including arbitrary `StatelessWidget`/`StatefulWidget` wrappers) → call
   `element.visitChildren`, and for each child compute its offset as
   `offset + (child.renderObject!.parentData as BoxParentData).offset` (valid
   regardless of how many `ComponentElement` hops sit between `element` and
   the next real `RenderObjectElement` — `parentData.offset` is a render-tree
   concept set by the actual render parent, which Flutter always resolves
   past `ComponentElement`s to the nearest real one), then recurse.

   **[Superseded 2026-07-19:** the parenthetical claim above was wrong — and
   was the cause of the "missing `NibButton` backdrop" symptom. Because
   `Element.renderObject` resolves to the nearest *descendant* render object,
   per-hop accumulation re-adds the same box's `parentData.offset` once per
   `ComponentElement` in a chain (e.g. `CircleAvatar → AnimatedContainer →
   Container → ConstrainedBox`, all resolving to one `RenderConstrainedBox`,
   added its offset four times; the example card's Follow button chrome
   landed at x=357 inside a 320px-wide card). Command rects are now derived
   from `RenderBox.getTransformTo` against the walked root's render box —
   no offset threading at all. See
   `2026-07-19-skeleton-mount-offsets-chrome-shimmer-design.md`, Fix A.**]**

### Known gap: `Material`/`PhysicalShape` chrome isn't preserved in v1

**[Closed — and partly misdiagnosed — 2026-07-19; see
`2026-07-19-skeleton-mount-offsets-chrome-shimmer-design.md`.** The
description below blamed unpreserved `Material` chrome for the missing
`NibButton` backdrop, but `NibButton`'s (and `NibCard`'s) fill is a plain
`DecoratedBox` — their `Material` is `type: transparency` and paints
nothing — so step 4 already covered them; the backdrop was painted at a
wrong, off-card position by the step-6 offset bug (see the superseded note
above). `PhysicalShape`/`PhysicalModel` chrome *was* a real gap for **stock
Material** widgets (`ElevatedButton`/`Card` route their fill through
`Material → _MaterialInterior → PhysicalShape`), and the follow-up now
preserves it as `ShapeDecoration`/`BoxDecoration` paint (no synthesized
elevation shadows — bones are flat).**]**

Step 4's chrome-preserving list only covers `DecoratedBox`/`ColoredBox` — the
primitives a plain `Container` decomposes into. `NibButton`'s own pill-shaped
fill comes from `Material`/`_MaterialInterior`/`PhysicalShape`, not
`DecoratedBox`, so it isn't in this list. Concretely: a `NibButton`'s label
correctly bones into a text bar (step 3, via its real `RenderParagraph`
size), but the button's own colored background is not painted — just a
floating bar, no button-shaped backdrop under it. Extending step 4 to also
cover `Material`/`PhysicalShape` is a scoped, well-understood follow-up if
this turns out to matter in practice, not attempted in v1.

## Testing (the golden-image problem, and how this avoids it)

Verifying *paint substitution* can't be done by inspecting the widget tree
(`find.byType` still finds the real `Text`/`CircleAvatar` — they're genuinely
mounted, just not painted) or by pumping and asserting structure, which is
how every other Skeleton test works. Two options: real golden-image tests
(`matchesGoldenFile`), or decoupling "decide what to paint" from "draw it."

This spec takes the second path: `_paintElement`'s walker is a pure(-ish)
function of `(Element, Offset) -> List<_BonePaintCommand>` (a `_BonePaintCommand`
being a small data class: `{Rect rect, NibSkeletonShape shape, bool isRealPaintThrough}`),
called once by `RenderNibSkeletonMount.paint` to get the command list and
draw each one, and callable *directly* by tests to assert on the command
list without needing a `Canvas`/golden file at all — same testability
philosophy as `shadeWidget` itself, just operating on `Element`s instead of
`Widget`s. Tests pump a real tree (so `Element`/`RenderBox` really exist),
grab the mount's `Element` via `tester.element(find.byType(...))`, call the
walker directly, and assert on the returned rects/shapes — e.g. "a `NibCard`
containing a `CircleAvatar` and two `Text`s produces 3 bone commands at the
avatar's/texts' real measured sizes, plus the card's own `DecoratedBox`
chrome color painted for real."

## Interaction with the rest of `NibSkeleton`

Unaffected — `loading: false` passthrough, `animated` contract (shimmer,
crossfade via `NibPresence`/`NibMotion`), `boneSpacing`, theme-derived default
colors, and the `NibSkeletonBone`/`NibSkeletonIgnore` escape hatches all
continue to work exactly as already shipped. This engine is purely what
`shadeWidget` produces internally when it hits a `StatefulWidget` node —
`buildBoneBox`'s shimmer/`ClipOval`/`ClipRRect` wrapping still applies to
this engine's *output* the same way it wraps every other bone box, since
`NibSkeletonRenderMount` is just another `Widget` bucket 4 returns.

**[Corrected 2026-07-19:** the last sentence overstated it — bucket 4 never
wrapped the mount in `buildBoneBox`, so mounted bones were static
regardless of `animated` (this was "Gap 2"). Shimmer on mounted bones now
comes from `NibSkeletonMountShimmerDriver` + per-bone clipped shader draws
inside `RenderNibSkeletonMount.paint` — see
`2026-07-19-skeleton-mount-offsets-chrome-shimmer-design.md`, Fix C.**]**

## Known gaps (beyond the Material/PhysicalShape one above)

- `boneSpacing` (the extra-gap feature) doesn't apply *inside* a
  render-mounted subtree — it only intercepts paint, it doesn't touch layout,
  so there's no opportunity to inject extra gap widgets the way the
  Widget-level `shadeStructural` does for `Row`/`Column`. A `NibCard`'s
  internal spacing is whatever the real `NibCard`'s own layout already uses.
- If the real child's build throws (a genuine bug in the real widget, not
  something we're masking), that exception surfaces normally during the real
  build/layout pass — this engine doesn't add a new failure mode, but it also
  doesn't add new protection against one either, unlike bucket 3's
  try/catch-around-`build()`.
