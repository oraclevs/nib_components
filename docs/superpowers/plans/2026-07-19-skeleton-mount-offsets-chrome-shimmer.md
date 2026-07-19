# Skeleton Render-Mount: Offsets, Chrome, Shimmer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> **This repo's override:** `CLAUDE.md` mandates direct in-session TDD (no
> implementer/reviewer subagents) — execute inline via executing-plans.

**Goal:** Close the three approved render-mount fixes from
`docs/superpowers/specs/2026-07-19-skeleton-mount-offsets-chrome-shimmer-design.md`:
(A) bone offsets derived from render-tree geometry instead of buggy
element-walk accumulation, (B) stock-Material chrome
(`PhysicalShape`/`PhysicalModel`) preserved, (C) shimmer sweep on
render-mounted bones.

**Architecture:** All three land in
`lib/src/skeleton/nib_skeleton_render_mount.dart` (walker + custom
Element/RenderObject), with one bucket-4 dispatch change in
`nib_skeleton_shade.dart` and a one-line export added to the sibling
`nib_motion` package. Command-list tests drive everything paintable-in-tests;
actual shimmer pixels land on the user's visual-confirm gate (shaders never
resolve under `flutter test`).

**Tech Stack:** Flutter (package `nib_components`), sibling path-dep
`nib_motion` (`MotionValue`, `NibShaderLoader`, bundled `shimmer.frag`).

## Global Constraints

- TDD: every behavior gets a failing test before its implementation
  (MASTER_PROMPT §1.6; show real `flutter test` output at each step).
- `flutter analyze` must stay clean except the two documented pre-existing
  findings (`invalid_dependency` on the nib_motion path dep,
  `prefer_initializing_formals` info on `NibDataTableController`).
- Animation machinery only via nib_motion primitives; `animated: false`
  must build **zero** drivers/tickers/`MotionValue`s.
- No hardcoded hex colors — all bone/shimmer colors flow from the existing
  `NibSkeletonPalette` (theme-derived upstream).
- Git: commit messages follow the repo's `fix(skeleton):`/`feat(skeleton):`/
  `docs(skeleton):` convention; **never** add Claude attribution/co-author
  lines (user's global CLAUDE.md).
- Do not mark the progress-doc row `verified` — that's the user's call after
  visual confirmation.
- nib_motion lives at `/home/occ/Projects/Nib/MotionNib/motion` (its own git
  repo) — its export change is committed there, not here.
- After code changes, run `graphify update .` (repo convention).

## File Structure

- `lib/src/skeleton/nib_skeleton_render_mount.dart` — walker rewrite
  (`_rectOf`, `_walk`), new `PhysicalModel`/`PhysicalShape` cases, new
  `NibSkeletonMountShimmerDriver`, `RenderNibSkeletonMount` gains
  `time`/`program`/`textDirection` + shader bone painting.
- `lib/src/skeleton/nib_skeleton_shade.dart` — bucket 4 builds the driver
  when `palette.shimmerEnabled`.
- `test/skeleton/nib_skeleton_render_mount_test.dart` — all new tests.
- `/home/occ/Projects/Nib/MotionNib/motion/lib/nib_motion.dart` — one export.
- `example/lib/examples/skeleton_examples.dart` + `example/lib/catalog.dart`
  — stale comment fix + one new stock-Material demo (exercises Fix B
  visually).
- `NIB_COMPONENTS_PROGRESS.md`,
  `docs/superpowers/specs/2026-07-18-skeleton-design.md`,
  `docs/superpowers/specs/2026-07-19-skeleton-render-mount.md` — gap-table
  and stale-claims updates.

---

### Task 1: Fix A — offsets from render-tree geometry

**Files:**
- Modify: `lib/src/skeleton/nib_skeleton_render_mount.dart:52-173`
  (`_childOffset`, `_recurseChildren`, `computeBonePaintCommands`)
- Test: `test/skeleton/nib_skeleton_render_mount_test.dart`

**Interfaces:**
- Consumes: existing `BonePaintCommand`/`BonePaintKind`/`NibSkeletonPalette`.
- Produces: `computeBonePaintCommands(Element, Offset, NibSkeletonPalette)`
  — signature unchanged; rects now correct absolute positions relative to
  the walked root's render box plus the given base offset. Internal helpers
  `Rect _rectOf(RenderBox box, RenderBox rootBox, Offset base)` and
  `List<BonePaintCommand> _walk(Element, RenderBox rootBox, Offset base,
  NibSkeletonPalette)` (Task 2 adds cases inside `_walk`).

- [ ] **Step 1: Write the two failing regression tests**

Append to `test/skeleton/nib_skeleton_render_mount_test.dart` (inside
`main()`; `_StatefulLeaf` and `_palette` already exist in the file):

```dart
  testWidgets(
      'a multi-hop component chain above a positioned child adds its offset '
      'exactly once (the CircleAvatar->AnimatedContainer->Container chain bug)',
      (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      const Padding(
        padding: EdgeInsets.all(20),
        child: _StatefulLeaf(child: _StatefulLeaf(child: Text('x'))),
      ),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(1));
    expect(commands.single.rect.topLeft, const Offset(20, 20));
  });

  testWidgets(
      'a NibButton at the end of a positioned Row keeps its chrome inside '
      'the walked bounds, with its label bone inside the chrome (the example '
      'card regression)', (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      SizedBox(
        width: 320,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            NibButton(
                label: 'Message',
                variant: NibButtonVariant.outline,
                onPressed: () {}),
            const SizedBox(width: 8),
            NibButton(label: 'Follow', onPressed: () {}),
          ],
        ),
      ),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    final rootSize = (element.renderObject! as RenderBox).size;
    final rootRect = Offset.zero & rootSize;
    final chromes =
        commands.where((c) => c.kind == BonePaintKind.decoration).toList();
    expect(chromes, hasLength(2), reason: 'one DecoratedBox chrome per button');
    for (final chrome in chromes) {
      expect(rootRect.contains(chrome.rect.topLeft), isTrue,
          reason: '${chrome.rect} escapes $rootRect');
      expect(rootRect.contains(chrome.rect.bottomRight - const Offset(0.1, 0.1)),
          isTrue,
          reason: '${chrome.rect} escapes $rootRect');
    }
    final filled = chromes.last;
    expect(
      commands.any((c) =>
          c.kind == BonePaintKind.bone && filled.rect.contains(c.rect.center)),
      isTrue,
      reason: 'the Follow label bone must sit inside its chrome',
    );
  });
```

Also add the missing import at the top of the file if not present:

```dart
import 'package:flutter/rendering.dart' show RenderBox;
```

(The file already imports `package:nib_components/nib_components.dart`, which
exports `NibButton`/`NibButtonVariant`.)

- [ ] **Step 2: Run the new tests, verify they fail on offsets**

Run: `flutter test test/skeleton/nib_skeleton_render_mount_test.dart`
Expected: the two new tests FAIL (offset `(60,60)`-style drift for the chain
test; chrome rect at x≈357 escaping the 320-wide root for the button test).
All pre-existing tests still pass.

- [ ] **Step 3: Rewrite the walker to derive rects from render geometry**

In `lib/src/skeleton/nib_skeleton_render_mount.dart`, replace everything from
`Offset _childOffset(` through the end of the old `computeBonePaintCommands`
function with:

```dart
Rect _rectOf(RenderBox box, RenderBox rootBox, Offset base) {
  final position =
      MatrixUtils.transformPoint(box.getTransformTo(rootBox), Offset.zero);
  return (base + position) & box.size;
}

List<BonePaintCommand> _recurseChildren(
  Element element,
  RenderBox rootBox,
  Offset base,
  NibSkeletonPalette palette,
) {
  final commands = <BonePaintCommand>[];
  element.visitChildren((child) {
    commands.addAll(_walk(child, rootBox, base, palette));
  });
  return commands;
}

/// Walks the real, already-mounted [element] tree (built and laid out
/// normally by Flutter — including any `StatefulWidget`, with its real
/// lifecycle) and decides what to paint: a bone box, a real decoration,
/// real paint-through, or recursion into children. Every command's rect is
/// derived from the render tree's own geometry ([RenderBox.getTransformTo]
/// against the walked root's render box) rather than accumulated while
/// walking — Element hops don't map 1:1 to render hops, so accumulating
/// `parentData.offset` per hop re-adds the same offset once per
/// `ComponentElement` in a chain. See
/// `docs/superpowers/specs/2026-07-19-skeleton-mount-offsets-chrome-shimmer-design.md`.
List<BonePaintCommand> computeBonePaintCommands(
  Element element,
  Offset offset,
  NibSkeletonPalette palette,
) {
  final rootBox = element.renderObject;
  if (rootBox is! RenderBox) return const [];
  return _walk(element, rootBox, offset, palette);
}

List<BonePaintCommand> _walk(
  Element element,
  RenderBox rootBox,
  Offset base,
  NibSkeletonPalette palette,
) {
  final widget = element.widget;
  final renderObject = element.renderObject;
  final box = renderObject is RenderBox ? renderObject : null;

  if (widget is NibSkeletonIgnore) {
    if (box != null) {
      return [
        BonePaintCommand.realPaintThrough(
            rect: _rectOf(box, rootBox, base), renderBox: box),
      ];
    }
    return const [];
  }

  if (widget is NibSkeletonBone) {
    final realSize = box?.size;
    final size = Size(
      widget.width ?? realSize?.width ?? palette.fallbackWidth,
      widget.height ?? realSize?.height ?? palette.fallbackHeight,
    );
    final origin = box != null ? _rectOf(box, rootBox, base).topLeft : base;
    return [BonePaintCommand.bone(rect: origin & size, shape: widget.shape)];
  }

  if (widget is Text || widget is RichText || widget is SelectableText) {
    if (box != null) {
      final rect = _rectOf(box, rootBox, base);
      return [
        BonePaintCommand.bone(
          rect: rect,
          shape: NibSkeletonShape.rectangle,
          radius: BorderRadius.circular(rect.height / 2),
        ),
      ];
    }
  }

  if (widget is Icon) {
    if (box != null) {
      return [
        BonePaintCommand.bone(
          rect: _rectOf(box, rootBox, base),
          shape: NibSkeletonShape.rectangle,
          radius: BorderRadius.circular(palette.radiusSm),
        ),
      ];
    }
  }

  if (widget is CircleAvatar) {
    if (box != null) {
      return [
        BonePaintCommand.bone(
            rect: _rectOf(box, rootBox, base), shape: NibSkeletonShape.circle),
      ];
    }
  }

  if (widget is DecoratedBox) {
    if (box != null) {
      final chrome = BonePaintCommand.decoration(
        rect: _rectOf(box, rootBox, base),
        decoration: widget.decoration,
      );
      return [chrome, ..._recurseChildren(element, rootBox, base, palette)];
    }
  }

  if (widget is ColoredBox) {
    if (box != null) {
      final chrome = BonePaintCommand.decoration(
        rect: _rectOf(box, rootBox, base),
        decoration: BoxDecoration(color: widget.color),
      );
      return [chrome, ..._recurseChildren(element, rootBox, base, palette)];
    }
  }

  final recursed = _recurseChildren(element, rootBox, base, palette);
  if (recursed.isNotEmpty) return recursed;

  if (box != null) {
    return [
      BonePaintCommand.bone(
        rect: _rectOf(box, rootBox, base),
        shape: NibSkeletonShape.rectangle,
        radius: palette.boxRadius,
      ),
    ];
  }
  return const [];
}
```

(`MatrixUtils` comes from the already-imported
`package:flutter/rendering.dart`.)

- [ ] **Step 4: Run the full render-mount test file, verify all pass**

Run: `flutter test test/skeleton/nib_skeleton_render_mount_test.dart`
Expected: PASS (both new tests + all pre-existing ones).

- [ ] **Step 5: Run the whole suite + analyze**

Run: `flutter test` then `flutter analyze`
Expected: all tests pass; analyzer clean except the two documented findings.

- [ ] **Step 6: Commit**

```bash
git add lib/src/skeleton/nib_skeleton_render_mount.dart test/skeleton/nib_skeleton_render_mount_test.dart
git commit -m "fix(skeleton): derive render-mount bone offsets from render-tree geometry"
```

---

### Task 2: Fix B — stock-Material chrome + decoration textDirection

**Files:**
- Modify: `lib/src/skeleton/nib_skeleton_render_mount.dart` (`_walk` gains
  two cases; `_NibSkeletonMountElement._pushRoot`;
  `RenderNibSkeletonMount` gains `textDirection`; `paint` decoration case)
- Test: `test/skeleton/nib_skeleton_render_mount_test.dart`

**Interfaces:**
- Consumes: Task 1's `_walk`/`_rectOf` shape.
- Produces: decoration commands for `PhysicalModel` (as `BoxDecoration`) and
  `PhysicalShape` (as `ShapeDecoration` when its clipper is a
  `ShapeBorderClipper`, else plain `BoxDecoration`);
  `RenderNibSkeletonMount.textDirection` (public `TextDirection?`
  getter/setter, marks needing paint on change).

- [ ] **Step 1: Write the failing tests**

Append to `test/skeleton/nib_skeleton_render_mount_test.dart`:

```dart
  testWidgets(
      'a shaped Material (the stock ElevatedButton/Card chrome primitive) '
      'preserves color+shape as a ShapeDecoration command before its content',
      (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      Material(
        color: Colors.deepOrange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const SizedBox(
            width: 80, height: 40, child: Center(child: Text('Go'))),
      ),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands.first.kind, BonePaintKind.decoration,
        reason: 'chrome paints before content bones');
    final decoration = commands.first.decoration;
    expect(decoration, isA<ShapeDecoration>());
    final shapeDecoration = decoration! as ShapeDecoration;
    expect(shapeDecoration.color, Colors.deepOrange);
    expect((shapeDecoration.shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(12));
    expect(commands.where((c) => c.kind == BonePaintKind.bone), isNotEmpty,
        reason: 'the label still bones');
  });

  testWidgets('Material(type: transparency) produces no decoration command',
      (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      const Material(
        type: MaterialType.transparency,
        child: SizedBox(width: 80, height: 40, child: Center(child: Text('Go'))),
      ),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands.where((c) => c.kind == BonePaintKind.decoration), isEmpty);
  });

  testWidgets('a stock ElevatedButton gets chrome under its boned label',
      (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      ElevatedButton(onPressed: () {}, child: const Text('Go')),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    final chromes =
        commands.where((c) => c.kind == BonePaintKind.decoration).toList();
    expect(chromes, isNotEmpty);
    expect(chromes.first.decoration, isA<ShapeDecoration>());
  });

  testWidgets('PhysicalModel rounded-rect preserves color and borderRadius',
      (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      PhysicalModel(
        color: Colors.teal,
        borderRadius: BorderRadius.circular(6),
        child: const SizedBox(width: 60, height: 30),
      ),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands.first.kind, BonePaintKind.decoration);
    final deco = commands.first.decoration! as BoxDecoration;
    expect(deco.color, Colors.teal);
    expect(deco.borderRadius, BorderRadius.circular(6));
  });

  testWidgets(
      'PhysicalModel circle drops borderRadius (BoxDecoration asserts '
      'borderRadius == null for circles)', (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      PhysicalModel(
        color: Colors.teal,
        shape: BoxShape.circle,
        child: const SizedBox(width: 40, height: 40),
      ),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    final deco = commands.first.decoration! as BoxDecoration;
    expect(deco.shape, BoxShape.circle);
    expect(deco.borderRadius, isNull);
  });

  testWidgets(
      'the mount captures the ambient Directionality for decoration painting',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: NibSkeleton(
            loading: true, child: _StatefulLeaf(child: Text('x'))),
      ),
    ));
    final mount = tester.renderObject<RenderNibSkeletonMount>(
        find.byType(NibSkeletonRenderMount));
    expect(mount.textDirection, TextDirection.rtl);
  });
```

- [ ] **Step 2: Run, verify the new tests fail**

Run: `flutter test test/skeleton/nib_skeleton_render_mount_test.dart`
Expected: shaped-Material/ElevatedButton/PhysicalModel tests FAIL (first
command is a bone or missing decoration); the Directionality test FAILS to
compile or errors (no `textDirection` getter yet). Pre-existing tests pass.
(The transparency test may already pass — that's fine, it pins existing
behavior.)

- [ ] **Step 3: Add the two chrome cases to `_walk`**

In `_walk`, directly after the `ColoredBox` case and before
`final recursed = ...`, insert:

```dart
  if (widget is PhysicalModel) {
    if (box != null) {
      final chrome = BonePaintCommand.decoration(
        rect: _rectOf(box, rootBox, base),
        decoration: BoxDecoration(
          color: widget.color,
          shape: widget.shape,
          borderRadius:
              widget.shape == BoxShape.rectangle ? widget.borderRadius : null,
        ),
      );
      return [chrome, ..._recurseChildren(element, rootBox, base, palette)];
    }
  }

  if (widget is PhysicalShape) {
    if (box != null) {
      final clipper = widget.clipper;
      final chrome = BonePaintCommand.decoration(
        rect: _rectOf(box, rootBox, base),
        decoration: clipper is ShapeBorderClipper
            ? ShapeDecoration(color: widget.color, shape: clipper.shape)
            : BoxDecoration(color: widget.color),
      );
      return [chrome, ..._recurseChildren(element, rootBox, base, palette)];
    }
  }
```

Elevation shadows are deliberately not synthesized (flat skeleton — spec
"Fix B"). `PhysicalModel`/`PhysicalShape`/`ShapeBorderClipper` all come from
the existing `package:flutter/widgets.dart` + `package:flutter/rendering.dart`
imports.

- [ ] **Step 4: Add `textDirection` to the render object and use it**

In `RenderNibSkeletonMount`, after the `palette` setter, add:

```dart
  TextDirection? _textDirection;

  /// The ambient [Directionality] captured by the mount's Element — used to
  /// resolve directional [Decoration]s when painting preserved chrome.
  TextDirection? get textDirection => _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsPaint();
  }
```

In `_NibSkeletonMountElement._pushRoot`, replace the body with:

```dart
  void _pushRoot() {
    (renderObject as RenderNibSkeletonMount)
      ..rootElement = _child
      ..palette = (widget as NibSkeletonRenderMount).palette
      ..textDirection = Directionality.maybeOf(this);
  }
```

In `RenderNibSkeletonMount.paint`'s decoration case, pass the direction and
dispose the painter:

```dart
        case BonePaintKind.decoration:
          final painter = command.decoration!.createBoxPainter();
          painter.paint(
            context.canvas,
            command.rect.topLeft,
            ImageConfiguration(
                size: command.rect.size, textDirection: _textDirection),
          );
          painter.dispose();
```

- [ ] **Step 5: Run the file, then suite + analyze**

Run: `flutter test test/skeleton/nib_skeleton_render_mount_test.dart`
Expected: PASS.
Run: `flutter test` then `flutter analyze`
Expected: all pass; analyzer clean except the two documented findings.

- [ ] **Step 6: Commit**

```bash
git add lib/src/skeleton/nib_skeleton_render_mount.dart test/skeleton/nib_skeleton_render_mount_test.dart
git commit -m "feat(skeleton): preserve stock-Material chrome (PhysicalShape/PhysicalModel) in the render mount"
```

---

### Task 3: nib_motion — export NibShaderLoader (sibling repo)

**Files:**
- Modify: `/home/occ/Projects/Nib/MotionNib/motion/lib/nib_motion.dart:54`

**Interfaces:**
- Produces: `package:nib_motion/nib_motion.dart` exports `NibShaderLoader`
  (+ `NibShaderAssets`) — Task 4 imports `NibShaderLoader.shimmer()`.

- [ ] **Step 1: Check the sibling repo is clean**

Run: `git -C /home/occ/Projects/Nib/MotionNib/motion status --short`
Expected: no unrelated staged changes (untracked files are fine — leave them
alone).

- [ ] **Step 2: Add the export**

In `/home/occ/Projects/Nib/MotionNib/motion/lib/nib_motion.dart`, the shaders
block currently reads:

```dart
export 'src/shaders/nib_dissolve.dart';
export 'src/shaders/nib_glass.dart';
export 'src/shaders/nib_shimmer.dart';
```

Change it to:

```dart
export 'src/shaders/nib_dissolve.dart';
export 'src/shaders/nib_glass.dart';
export 'src/shaders/nib_shimmer.dart';
export 'src/shaders/shader_loader.dart';
```

- [ ] **Step 3: Analyze nib_motion**

Run: `cd /home/occ/Projects/Nib/MotionNib/motion && flutter analyze`
Expected: no new findings versus before the change.

- [ ] **Step 4: Commit (in the nib_motion repo)**

```bash
git -C /home/occ/Projects/Nib/MotionNib/motion add lib/nib_motion.dart
git -C /home/occ/Projects/Nib/MotionNib/motion commit -m "feat(shaders): export NibShaderLoader/NibShaderAssets from the package barrel"
```

(Match the repo's existing commit-message style if it differs — check
`git -C /home/occ/Projects/Nib/MotionNib/motion log --oneline -5` first.)

---

### Task 4: Fix C — shimmer on render-mounted bones

**Files:**
- Modify: `lib/src/skeleton/nib_skeleton_render_mount.dart`
  (`NibSkeletonRenderMount` widget params, `RenderNibSkeletonMount`
  time/program/shader painting, new `NibSkeletonMountShimmerDriver`)
- Modify: `lib/src/skeleton/nib_skeleton_shade.dart` (bucket 4)
- Test: `test/skeleton/nib_skeleton_render_mount_test.dart`

**Interfaces:**
- Consumes: Task 3's `NibShaderLoader` export; nib_motion's
  `MotionValue<double>`.
- Produces: `NibSkeletonMountShimmerDriver({required NibSkeletonPalette
  palette, required Widget child})` (public-in-file, not in the package
  barrel); `NibSkeletonRenderMount` gains optional `MotionValue<double>?
  time` and `FragmentProgram? program` constructor params;
  `RenderNibSkeletonMount` gains matching public `time` getter/setter and
  `program` setter.

- [ ] **Step 1: Write the failing tests**

Append to `test/skeleton/nib_skeleton_render_mount_test.dart`:

```dart
  testWidgets(
      'animated: true wraps the mount in a shimmer driver with a live ticker, '
      'and unmounting leaks nothing', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: NibSkeleton(
          loading: true, animated: true, child: _StatefulLeaf(child: Text('x'))),
    ));
    // Let the NibPresence/NibMotion entrance dissolve (220ms) finish so the
    // only remaining transient callback is the shimmer ticker.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NibSkeletonMountShimmerDriver), findsOneWidget);
    expect(tester.binding.transientCallbackCount, greaterThan(0),
        reason: 'the shimmer ticker must keep running while loading');
    final mount = tester.renderObject<RenderNibSkeletonMount>(
        find.byType(NibSkeletonRenderMount));
    expect(mount.time, isNotNull);

    await tester.pumpWidget(
        const MaterialApp(debugShowCheckedModeBanner: false, home: SizedBox()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    // flutter_test itself fails the test at teardown if a Ticker leaked.
  });

  testWidgets(
      'animated: false builds no shimmer driver and no ticking animation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: NibSkeleton(loading: true, child: _StatefulLeaf(child: Text('x'))),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(NibSkeletonMountShimmerDriver), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    final mount = tester.renderObject<RenderNibSkeletonMount>(
        find.byType(NibSkeletonRenderMount));
    expect(mount.time, isNull);
  });

  testWidgets('a time tick marks the mount as needing paint with no rebuild',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: NibSkeleton(
          loading: true, animated: true, child: _StatefulLeaf(child: Text('x'))),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    final mount = tester.renderObject<RenderNibSkeletonMount>(
        find.byType(NibSkeletonRenderMount));
    expect(mount.debugNeedsPaint, isFalse);
    mount.time!.value = 123.456;
    expect(mount.debugNeedsPaint, isTrue);
  });
```

- [ ] **Step 2: Run, verify they fail to compile (no driver/time yet)**

Run: `flutter test test/skeleton/nib_skeleton_render_mount_test.dart`
Expected: COMPILE ERROR — `NibSkeletonMountShimmerDriver` and `mount.time`
undefined.

- [ ] **Step 3: Implement driver + render-object shimmer painting**

In `lib/src/skeleton/nib_skeleton_render_mount.dart`, update the imports:

```dart
import 'dart:ui' show FragmentProgram, FragmentShader;

import 'package:flutter/material.dart' show CircleAvatar, SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';
import 'package:nib_motion/nib_motion.dart' show MotionValue, NibShaderLoader;

import 'nib_skeleton_shade.dart';
import 'nib_skeleton_types.dart';
```

Extend `NibSkeletonRenderMount` (constructor + fields + create/update):

```dart
class NibSkeletonRenderMount extends RenderObjectWidget {
  const NibSkeletonRenderMount({
    super.key,
    required this.child,
    required this.palette,
    this.time,
    this.program,
  });

  final Widget child;
  final NibSkeletonPalette palette;

  /// Elapsed-seconds driver for the shimmer sweep — `null` when shimmer is
  /// off ([NibSkeletonPalette.shimmerEnabled] false), in which case bones
  /// paint static.
  final MotionValue<double>? time;

  /// The compiled shimmer shader — `null` until [NibShaderLoader] resolves
  /// it (or forever, in environments without shader support).
  final FragmentProgram? program;

  @override
  RenderObjectElement createElement() => _NibSkeletonMountElement(this);

  @override
  RenderNibSkeletonMount createRenderObject(BuildContext context) {
    return RenderNibSkeletonMount(palette: palette, time: time, program: program);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderNibSkeletonMount renderObject) {
    renderObject
      ..palette = palette
      ..time = time
      ..program = program;
  }
}
```

Extend `RenderNibSkeletonMount` — constructor, time/program plumbing
(mirroring `RenderNibShimmer.time`'s listener swap), shimmer constants, and
the bone-painting split:

```dart
class RenderNibSkeletonMount extends RenderProxyBox {
  // ignore: prefer_initializing_formals
  RenderNibSkeletonMount({
    required NibSkeletonPalette palette,
    MotionValue<double>? time,
    FragmentProgram? program,
  })  : _palette = palette,
        _time = time,
        _program = program {
    _time?.addListener(_onTimeChanged);
    _shader = _program?.fragmentShader();
  }

  // NibShimmer's constructor defaults, mirrored so a render-mounted bone
  // sweeps identically to a widget-path bone wrapped in its own NibShimmer.
  static const double _shimmerSpeed = 1.5;
  static const double _shimmerAngle = -0.3;

  NibSkeletonPalette _palette;
  set palette(NibSkeletonPalette value) {
    if (_palette == value) return;
    _palette = value;
    markNeedsPaint();
  }

  TextDirection? _textDirection;

  /// The ambient [Directionality] captured by the mount's Element — used to
  /// resolve directional [Decoration]s when painting preserved chrome.
  TextDirection? get textDirection => _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsPaint();
  }

  MotionValue<double>? _time;

  /// The shimmer sweep's elapsed-time driver; `null` paints static bones.
  MotionValue<double>? get time => _time;
  set time(MotionValue<double>? value) {
    if (_time == value) return;
    _time?.removeListener(_onTimeChanged);
    _time = value;
    _time?.addListener(_onTimeChanged);
    markNeedsPaint();
  }

  FragmentProgram? _program;
  FragmentShader? _shader;
  set program(FragmentProgram? value) {
    if (_program == value) return;
    _program = value;
    _shader?.dispose();
    _shader = value?.fragmentShader();
    markNeedsPaint();
  }

  Element? rootElement;

  void _onTimeChanged() => markNeedsPaint();

  @override
  void dispose() {
    _time?.removeListener(_onTimeChanged);
    _shader?.dispose();
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final root = rootElement;
    if (root == null) return;
    for (final command in computeBonePaintCommands(root, offset, _palette)) {
      switch (command.kind) {
        case BonePaintKind.realPaintThrough:
          if (command.renderBox != null) {
            context.paintChild(command.renderBox!, command.rect.topLeft);
          }
        case BonePaintKind.decoration:
          final painter = command.decoration!.createBoxPainter();
          painter.paint(
            context.canvas,
            command.rect.topLeft,
            ImageConfiguration(
                size: command.rect.size, textDirection: _textDirection),
          );
          painter.dispose();
        case BonePaintKind.bone:
          _paintBone(context.canvas, command);
      }
    }
  }

  void _paintBone(Canvas canvas, BonePaintCommand command) {
    final rect = command.rect;
    final shader = _shader;
    final time = _time;
    if (shader == null || time == null) {
      final paint = Paint()..color = _palette.baseColor;
      if (command.shape == NibSkeletonShape.circle) {
        canvas.drawOval(rect, paint);
      } else if (command.radius != null) {
        canvas.drawRRect(command.radius!.toRRect(rect), paint);
      } else {
        canvas.drawRect(rect, paint);
      }
      return;
    }

    shader
      ..setFloat(0, time.value)
      ..setFloat(1, _shimmerSpeed)
      ..setFloat(2, _palette.baseColor.r)
      ..setFloat(3, _palette.baseColor.g)
      ..setFloat(4, _palette.baseColor.b)
      ..setFloat(5, _palette.baseColor.a)
      ..setFloat(6, _palette.shimmerColor.r)
      ..setFloat(7, _palette.shimmerColor.g)
      ..setFloat(8, _palette.shimmerColor.b)
      ..setFloat(9, _palette.shimmerColor.a)
      ..setFloat(10, rect.width)
      ..setFloat(11, rect.height)
      ..setFloat(12, _shimmerAngle);

    // Origin-normalized: translate so the draw's coordinates are bone-local
    // (shimmer.frag computes its band from FlutterFragCoord against uWidth,
    // with no origin uniform — drawing at a large canvas offset would shift
    // or park the band outside the bone). The shader paints base fill +
    // sweep band, so no separate solid fill is needed under it.
    final local = Offset.zero & rect.size;
    canvas.save();
    canvas.translate(rect.left, rect.top);
    if (command.shape == NibSkeletonShape.circle) {
      canvas.clipPath(Path()..addOval(local));
    } else if (command.radius != null) {
      canvas.clipRRect(command.radius!.toRRect(local));
    }
    canvas.drawRect(local, Paint()..shader = shader);
    canvas.restore();
  }
}
```

Append the driver at the end of the file:

```dart
/// Drives the shimmer sweep for one [NibSkeletonRenderMount]: a ticker
/// writes elapsed seconds into a [MotionValue] (no widget rebuild per frame
/// — [RenderNibSkeletonMount] listens and repaints), and the shared shimmer
/// [FragmentProgram] resolves async via [NibShaderLoader] (staying `null` —
/// static bones — where shaders can't compile, e.g. `flutter test`).
/// Replicates `_NibShimmerState`'s proven pattern. Internal plumbing — not
/// exported from the package barrel (same convention as
/// [NibSkeletonPalette]); `shadeWidget` builds it only when
/// [NibSkeletonPalette.shimmerEnabled].
class NibSkeletonMountShimmerDriver extends StatefulWidget {
  const NibSkeletonMountShimmerDriver({
    super.key,
    required this.palette,
    required this.child,
  });

  final NibSkeletonPalette palette;
  final Widget child;

  @override
  State<NibSkeletonMountShimmerDriver> createState() =>
      _NibSkeletonMountShimmerDriverState();
}

class _NibSkeletonMountShimmerDriverState
    extends State<NibSkeletonMountShimmerDriver>
    with SingleTickerProviderStateMixin {
  final MotionValue<double> _time = MotionValue<double>(0);
  Ticker? _ticker;
  FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _loadProgram();
    (_ticker = createTicker(_onTick))!.start();
  }

  Future<void> _loadProgram() async {
    try {
      final program = await NibShaderLoader.shimmer();
      if (!mounted) return;
      setState(() => _program = program);
    } catch (_) {
      // Shader unavailable (not bundled, or no compilation support in this
      // environment) — the mount keeps painting static bones.
    }
  }

  void _onTick(Duration elapsed) {
    _time.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NibSkeletonRenderMount(
      palette: widget.palette,
      time: _time,
      program: _program,
      child: widget.child,
    );
  }
}
```

(If the analyzer objects to `(_ticker = createTicker(_onTick))!.start()`,
write it as two statements: `_ticker = createTicker(_onTick);
_ticker!.start();`.)

In `lib/src/skeleton/nib_skeleton_shade.dart`, replace bucket 4:

```dart
  if (node is StatefulWidget) {
    return palette.shimmerEnabled
        ? NibSkeletonMountShimmerDriver(palette: palette, child: node)
        : NibSkeletonRenderMount(palette: palette, child: node);
  }
```

- [ ] **Step 4: Run the file, then suite + analyze**

Run: `flutter test test/skeleton/nib_skeleton_render_mount_test.dart`
Expected: PASS (all, including the three new shimmer tests).
Run: `flutter test` then `flutter analyze`
Expected: all pass; analyzer clean except the two documented findings.

- [ ] **Step 5: Commit**

```bash
git add lib/src/skeleton/nib_skeleton_render_mount.dart lib/src/skeleton/nib_skeleton_shade.dart test/skeleton/nib_skeleton_render_mount_test.dart
git commit -m "feat(skeleton): shimmer sweep on render-mounted bones"
```

---

### Task 5: Example app — stale comment + stock-Material demo (exercises Fix B)

**Files:**
- Modify: `example/lib/examples/skeleton_examples.dart` (fix the outdated
  `_ProfileCard` doc comment; add `SkeletonMaterialExample`)
- Modify: `example/lib/catalog.dart` (register the new demo)

**Interfaces:**
- Consumes: `NibSkeleton` public API only.
- Produces: a `SkeletonMaterialExample` widget registered as
  `'Skeleton — stock Material'` in the catalog.

- [ ] **Step 1: Fix the outdated `_ProfileCard` doc comment**

In `example/lib/examples/skeleton_examples.dart`, replace the comment block
above `class _ProfileCard` (the paragraph starting "`NibCard`/`NibButton` are
themselves `StatefulWidget`s…") with:

```dart
/// A real-world composite — a Nib `NibCard` with a header (avatar + name +
/// title), a body paragraph, and a footer with two `NibButton`s.
///
/// `NibCard`/`NibButton` are themselves `StatefulWidget`s (this library's
/// own stateful-by-default convention), so they route through the
/// render-mount engine: the real subtree is mounted normally and bone boxes
/// are substituted only at paint time, preserving the card's and buttons'
/// own `DecoratedBox` chrome under the boned content (see
/// docs/superpowers/specs/2026-07-19-skeleton-render-mount.md and the
/// offsets/chrome/shimmer follow-up spec).
class _ProfileCard extends StatelessWidget {
```

- [ ] **Step 2: Add the stock-Material demo**

Append to `example/lib/examples/skeleton_examples.dart`:

```dart
/// 5. Stock Material — a subtree of plain Material widgets (`Card`,
/// `ElevatedButton`), whose chrome comes from `PhysicalShape` rather than
/// `DecoratedBox`. Exercises the render mount's stock-Material chrome
/// preservation.
class SkeletonMaterialExample extends StatefulWidget {
  const SkeletonMaterialExample({super.key});

  @override
  State<SkeletonMaterialExample> createState() =>
      _SkeletonMaterialExampleState();
}

class _SkeletonMaterialExampleState extends State<SkeletonMaterialExample> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 320,
          child: NibSkeleton(
            loading: _loading,
            animated: true,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Stock Material card',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                        'Card and ElevatedButton chrome comes from '
                        'PhysicalShape, not DecoratedBox.'),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: () {}, child: const Text('Act')),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => setState(() => _loading = !_loading),
          child: Text(_loading ? 'Finish loading' : 'Start loading'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Register it in the catalog**

In `example/lib/catalog.dart`, directly after the existing
`'Skeleton — card'` entry, add (matching the file's existing `CatalogEntry`
shape exactly — check the neighboring skeleton entries' syntax first):

```dart
  CatalogEntry(
    name: 'Skeleton — stock Material',
    builder: (context) => const SkeletonMaterialExample(),
  ),
```

- [ ] **Step 4: Analyze the example app**

Run: `cd example && flutter analyze`
Expected: clean (or unchanged pre-existing findings only).

- [ ] **Step 5: Commit**

```bash
git add example/lib/examples/skeleton_examples.dart example/lib/catalog.dart
git commit -m "feat(skeleton): example demo for stock-Material chrome under the render mount"
```

---

### Task 6: Docs — progress Known Gaps + both spec docs

**Files:**
- Modify: `NIB_COMPONENTS_PROGRESS.md` (Known Gaps rows for Skeleton, row
  ~138; keep row 191's status `built — awaiting visual confirm`)
- Modify: `docs/superpowers/specs/2026-07-19-skeleton-render-mount.md`
  (step-6 `parentData.offset` claim; the two "Known gap" sections)
- Modify: `docs/superpowers/specs/2026-07-18-skeleton-design.md` (Known gaps
  first bullet — the StatefulWidget-flattening description)

**Interfaces:** none (docs only).

- [ ] **Step 1: Rewrite the progress-doc Known Gaps entry**

Replace the Skeleton render-mount row (the 2026-07-19 row describing the two
gaps) with a row stating: offsets bug found and fixed (element-hop
`parentData.offset` re-adding, discovered to be the actual cause of the
"missing button backdrop" — the Material/PhysicalShape diagnosis was wrong
for Nib widgets, whose chrome is plain `DecoratedBox`); stock-Material
chrome (`PhysicalShape`/`PhysicalModel`) now preserved; shimmer now applies
to render-mounted bones via a `MotionValue`-driven per-bone shader. Add
remaining known gaps as new rows: `Ink(decoration:)` lost inside mounted
subtrees; no synthesized elevation shadows; rotated/scaled children bone at
transformed origin with untransformed size; `shimmer.frag` origin uniform as
a possible nib_motion follow-up if far bones don't visibly sweep at visual
confirm. Reference the new spec doc path.

- [ ] **Step 2: Correct the render-mount spec**

In `docs/superpowers/specs/2026-07-19-skeleton-render-mount.md`:
- Step 6 of the walker description (the `parentData.offset` accumulation
  claim "valid regardless of how many ComponentElement hops…"): annotate it
  as superseded — e.g. append "**[Superseded 2026-07-19:** this claim was
  wrong — `Element.renderObject` resolves to the nearest *descendant* render
  object, so per-hop accumulation re-adds the same offset once per
  ComponentElement in a chain; offsets now come from
  `RenderBox.getTransformTo` against the walked root — see the
  offsets/chrome/shimmer follow-up spec.**]**"
- The "Known gap: `Material`/`PhysicalShape` chrome" section: annotate as
  closed by the follow-up spec, noting the misdiagnosis (Nib chrome is
  `DecoratedBox`; `PhysicalShape`/`PhysicalModel` mattered only for stock
  Material widgets and is now handled).
- The final "Known gaps" bullet list: leave `boneSpacing` and the
  build-throws bullets; they're still true.

- [ ] **Step 3: Correct the original skeleton spec**

In `docs/superpowers/specs/2026-07-18-skeleton-design.md`'s Known gaps, the
first bullet still says a `NibCard`/`NibButton` composition "currently bones
the *entire* `NibCard` as one flat fallback box". Annotate it as resolved by
the render-mount engine + follow-ups (pointer to both later specs), keeping
the historical text intact (strikethrough or a bracketed "[Resolved …]"
note, matching how the doc handles supersession in its header).

- [ ] **Step 4: Commit**

```bash
git add NIB_COMPONENTS_PROGRESS.md docs/superpowers/specs/2026-07-19-skeleton-render-mount.md docs/superpowers/specs/2026-07-18-skeleton-design.md
git commit -m "docs(skeleton): record offsets/chrome/shimmer gap closures and correct superseded claims"
```

---

### Task 7: Final verification sweep

**Files:** none new.

- [ ] **Step 1: Full suite + analyzers, shown output**

Run: `flutter test` — expected: all tests pass (count > 779).
Run: `flutter analyze` — expected: only the two documented findings.
Run: `cd example && flutter analyze` — expected: clean/unchanged.

- [ ] **Step 2: Update the knowledge graph**

Run: `graphify update .`
Expected: completes without error.

- [ ] **Step 3: Confirm progress-doc status line**

`NIB_COMPONENTS_PROGRESS.md` row 31 (Skeleton) stays
`built — awaiting visual confirm` — the user verifies the example app
(`cd example && flutter run -d linux`): card demo backdrops now under the
boned labels, shimmer sweeping mounted bones, new stock-Material demo
chrome present.

## Self-Review Notes

- Spec coverage: Fix A → Task 1; Fix B (incl. textDirection) → Task 2;
  Fix C (incl. nib_motion export, bucket 4, driver, render object) → Tasks
  3–4; spec's testing list → Tasks 1/2/4 test code; docs/known-gaps → Task 6;
  visual-confirm surface → Task 5 + Task 7.
- Type consistency: `NibSkeletonMountShimmerDriver(palette:, child:)`,
  `RenderNibSkeletonMount.time/program/textDirection`, `_walk(element,
  rootBox, base, palette)` used identically across tasks.
- No placeholders: every step carries complete code or exact commands.
