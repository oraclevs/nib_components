# Skeleton Render-Mount Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **This repo overrides the sub-skill default** (`CLAUDE.md`): write code directly in the main session using TDD, no implementer/reviewer subagents for routine work.

**Goal:** Replace bucket 4's flat fallback box (for `StatefulWidget` nodes) with a mount-and-paint-intercept engine — mount the real child normally (real lifecycle), substitute bone boxes only at paint time by walking the real, fully-resolved Element tree.

**Architecture:** A pure function `computeBonePaintCommands(Element, Offset, NibSkeletonPalette) -> List<BonePaintCommand>` decides what to paint (bone box / real decoration / real paint-through / recurse) by walking Elements and reading real `RenderBox.size` — independently unit-testable with no `Canvas`. A custom `Element` (`_NibSkeletonMountElement`, re-implementing the ~30-line `SingleChildRenderObjectElement` pattern since its private `_child` field isn't reachable from outside `framework.dart`) mounts the real child and exposes its Element reference to `RenderNibSkeletonMount`, whose `paint()` calls the pure function and draws each command.

**Tech Stack:** Flutter/Dart, `RenderObjectElement`/`RenderProxyBox` (custom, no new pub dependency).

## Global Constraints

- This is a **targeted fallback**, not a replacement — bucket 1–3 (`shadeLeaf`, `shadeStructural`, `StatelessWidget` auto-expand) are unchanged; only bucket 4's `StatefulWidget` branch changes.
- Known, documented, out-of-scope-for-v1 gaps (do not attempt): `Material`/`PhysicalShape` chrome (a `NibButton`'s own background) isn't preserved — only `DecoratedBox`/`ColoredBox` are. Shimmer animation does **not** apply to render-mounted bones in v1 — they're static-colored even when `animated: true` (a separate, scoped follow-up; flag it, don't silently attempt it here).
- Run `flutter test` and `flutter analyze` and report actual output before claiming anything works.
- Spec: `docs/superpowers/specs/2026-07-19-skeleton-render-mount.md` — read it before Task 1 if picking this up cold.

---

## File Structure

```
lib/src/skeleton/
  nib_skeleton_render_mount.dart   (BonePaintKind, BonePaintCommand,
                                    computeBonePaintCommands — pure, Task 1-2;
                                    NibSkeletonRenderMount widget +
                                    _NibSkeletonMountElement + RenderNibSkeletonMount
                                    — Task 3)
  nib_skeleton_shade.dart          (Modify: bucket 4 in shadeWidget)

test/skeleton/
  nib_skeleton_render_mount_test.dart
```

Not exported from the package barrel — internal, consumed only by
`nib_skeleton_shade.dart`, same convention as `nib_skeleton_shade.dart` itself.

---

### Task 1: `computeBonePaintCommands` — Ignore/Bone precedence, recognized leaves, generic recursion, real-size fallback

**Files:**
- Create: `lib/src/skeleton/nib_skeleton_render_mount.dart`
- Test: `test/skeleton/nib_skeleton_render_mount_test.dart`

**Interfaces:**
- Consumes: `NibSkeletonPalette`, `NibSkeletonShape`, `NibSkeletonBone`, `NibSkeletonIgnore` (existing skeleton files).
- Produces: `enum BonePaintKind { bone, decoration, realPaintThrough }`; `class BonePaintCommand` (named constructors `.bone`, `.decoration`, `.realPaintThrough`, each with a `Rect rect`); `List<BonePaintCommand> computeBonePaintCommands(Element element, Offset offset, NibSkeletonPalette palette)`. Task 2 adds the `DecoratedBox`/`ColoredBox` branch to this same function.

- [ ] **Step 1: Write the failing tests**

Create `test/skeleton/nib_skeleton_render_mount_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_components/src/skeleton/nib_skeleton_render_mount.dart';

const _palette = NibSkeletonPalette(
  baseColor: Color(0xFFE0E0E0),
  shimmerColor: Color(0xFFF0F0F0),
  radiusSm: 4,
  radiusDefault: 8,
  fallbackWidth: 80,
  fallbackHeight: 16,
  boxRadius: null,
);

class _StatefulLeaf extends StatefulWidget {
  const _StatefulLeaf({required this.child});
  final Widget child;

  @override
  State<_StatefulLeaf> createState() => _StatefulLeafState();
}

class _StatefulLeafState extends State<_StatefulLeaf> {
  @override
  Widget build(BuildContext context) => widget.child;
}

Future<Element> _pumpAndFindElement(WidgetTester tester, Widget child, {Key? key}) async {
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Center(child: KeyedSubtree(key: key ?? const Key('root'), child: child)),
  ));
  return tester.element(find.byKey(key ?? const Key('root')));
}

void main() {
  testWidgets('NibSkeletonBone produces one explicit bone command, ignoring what it wraps',
      (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      const NibSkeletonBone(width: 40, height: 40, shape: NibSkeletonShape.circle, child: Text('x')),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(1));
    expect(commands.single.kind, BonePaintKind.bone);
    expect(commands.single.shape, NibSkeletonShape.circle);
    expect(commands.single.rect.size, const Size(40, 40));
  });

  testWidgets('NibSkeletonIgnore produces one realPaintThrough command', (tester) async {
    final element = await _pumpAndFindElement(tester, const NibSkeletonIgnore(child: Icon(Icons.star)));
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(1));
    expect(commands.single.kind, BonePaintKind.realPaintThrough);
  });

  testWidgets('a Text leaf produces one bone command sized to its real measured size',
      (tester) async {
    final element = await _pumpAndFindElement(tester, const Text('Hello there'));
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(1));
    expect(commands.single.kind, BonePaintKind.bone);
    final realSize = (element.renderObject! as RenderBox).size;
    expect(commands.single.rect.size, realSize);
    expect(commands.single.radius, BorderRadius.circular(realSize.height / 2));
  });

  testWidgets('an Icon leaf produces one bone command sized to its real measured size',
      (tester) async {
    final element = await _pumpAndFindElement(tester, const Icon(Icons.star, size: 32));
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(1));
    final realSize = (element.renderObject! as RenderBox).size;
    expect(commands.single.rect.size, realSize);
    expect(commands.single.radius, BorderRadius.circular(_palette.radiusSm));
  });

  testWidgets('a CircleAvatar leaf produces one circle bone command sized to its real size',
      (tester) async {
    final element = await _pumpAndFindElement(tester, const CircleAvatar(radius: 20));
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(1));
    expect(commands.single.shape, NibSkeletonShape.circle);
  });

  testWidgets(
      'a StatefulWidget wrapping a Text is walked through transparently — one bone command '
      'for the real Text, not a flat fallback box (the whole point of this engine)',
      (tester) async {
    final element = await _pumpAndFindElement(tester, const _StatefulLeaf(child: Text('inside')));
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(1));
    expect(commands.single.kind, BonePaintKind.bone);
    // Sized to the real Text, not the generic fallbackWidth/Height default.
    expect(commands.single.rect.size.width, isNot(_palette.fallbackWidth));
  });

  testWidgets('a Row of two Texts produces two independent bone commands at their own offsets',
      (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [Text('A'), Text('BB')],
      ),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(2));
    expect(commands[0].rect.left, lessThan(commands[1].rect.left));
  });

  testWidgets('a childless leaf render object with no recognized type falls back to a bone '
      'sized to its real size (e.g. a bare SizedBox)', (tester) async {
    final element = await _pumpAndFindElement(tester, const SizedBox(width: 50, height: 20));
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(1));
    expect(commands.single.kind, BonePaintKind.bone);
    expect(commands.single.rect.size, const Size(50, 20));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/skeleton/nib_skeleton_render_mount_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:nib_components/src/skeleton/nib_skeleton_render_mount.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/src/skeleton/nib_skeleton_render_mount.dart`:

```dart
import 'package:flutter/material.dart' show CircleAvatar, SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'nib_skeleton_shade.dart';
import 'nib_skeleton_types.dart';

/// What one [BonePaintCommand] does when drawn.
enum BonePaintKind {
  /// Paint a solid bone-coloured shape.
  bone,

  /// Paint a real [Decoration] (a `DecoratedBox`/`ColoredBox`'s own chrome —
  /// preserved so a card's background/border survives even while its content
  /// bones).
  decoration,

  /// Paint the real, already-mounted content normally (`NibSkeletonIgnore`).
  realPaintThrough,
}

/// One instruction produced by [computeBonePaintCommands]. Deliberately a
/// plain data class, not a direct `Canvas` draw call — this is what makes the
/// walker unit-testable without a real `Canvas`/golden image: tests call
/// [computeBonePaintCommands] directly and assert on the returned commands.
class BonePaintCommand {
  const BonePaintCommand.bone({required this.rect, required this.shape, this.radius})
      : kind = BonePaintKind.bone,
        decoration = null,
        renderBox = null;

  const BonePaintCommand.decoration({required this.rect, required this.decoration})
      : kind = BonePaintKind.decoration,
        shape = NibSkeletonShape.rectangle,
        radius = null,
        renderBox = null;

  const BonePaintCommand.realPaintThrough({required this.rect, required this.renderBox})
      : kind = BonePaintKind.realPaintThrough,
        shape = NibSkeletonShape.rectangle,
        radius = null,
        decoration = null;

  final BonePaintKind kind;
  final Rect rect;
  final NibSkeletonShape shape;
  final BorderRadius? radius;
  final Decoration? decoration;
  final RenderBox? renderBox;
}

Offset _childOffset(Element child, Offset parentOffset) {
  final renderObject = child.renderObject;
  if (renderObject is RenderBox) {
    final parentData = renderObject.parentData;
    if (parentData is BoxParentData) {
      return parentOffset + parentData.offset;
    }
  }
  return parentOffset;
}

List<BonePaintCommand> _recurseChildren(
  Element element,
  Offset offset,
  NibSkeletonPalette palette,
) {
  final commands = <BonePaintCommand>[];
  element.visitChildren((child) {
    commands.addAll(
      computeBonePaintCommands(child, _childOffset(child, offset), palette),
    );
  });
  return commands;
}

/// Walks the real, already-mounted [element] tree (built and laid out
/// normally by Flutter — including any `StatefulWidget`, with its real
/// lifecycle) and decides what to paint at [offset]: a bone box, a real
/// decoration, real paint-through, or recursion into children. See
/// `docs/superpowers/specs/2026-07-19-skeleton-render-mount.md`.
List<BonePaintCommand> computeBonePaintCommands(
  Element element,
  Offset offset,
  NibSkeletonPalette palette,
) {
  final widget = element.widget;
  final renderObject = element.renderObject;

  if (widget is NibSkeletonIgnore) {
    if (renderObject is RenderBox) {
      return [
        BonePaintCommand.realPaintThrough(rect: offset & renderObject.size, renderBox: renderObject),
      ];
    }
    return const [];
  }

  if (widget is NibSkeletonBone) {
    final realSize = renderObject is RenderBox ? renderObject.size : null;
    final size = Size(
      widget.width ?? realSize?.width ?? palette.fallbackWidth,
      widget.height ?? realSize?.height ?? palette.fallbackHeight,
    );
    return [BonePaintCommand.bone(rect: offset & size, shape: widget.shape)];
  }

  if (widget is Text || widget is RichText || widget is SelectableText) {
    if (renderObject is RenderBox) {
      return [
        BonePaintCommand.bone(
          rect: offset & renderObject.size,
          shape: NibSkeletonShape.rectangle,
          radius: BorderRadius.circular(renderObject.size.height / 2),
        ),
      ];
    }
  }

  if (widget is Icon) {
    if (renderObject is RenderBox) {
      return [
        BonePaintCommand.bone(
          rect: offset & renderObject.size,
          shape: NibSkeletonShape.rectangle,
          radius: BorderRadius.circular(palette.radiusSm),
        ),
      ];
    }
  }

  if (widget is CircleAvatar) {
    if (renderObject is RenderBox) {
      return [
        BonePaintCommand.bone(rect: offset & renderObject.size, shape: NibSkeletonShape.circle),
      ];
    }
  }

  final recursed = _recurseChildren(element, offset, palette);
  if (recursed.isNotEmpty) return recursed;

  if (renderObject is RenderBox) {
    return [
      BonePaintCommand.bone(
        rect: offset & renderObject.size,
        shape: NibSkeletonShape.rectangle,
        radius: palette.boxRadius,
      ),
    ];
  }
  return const [];
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/skeleton/nib_skeleton_render_mount_test.dart`
Expected: `00:01 +7: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/src/skeleton/nib_skeleton_render_mount.dart test/skeleton/nib_skeleton_render_mount_test.dart
git commit -m "feat(skeleton): add computeBonePaintCommands — leaf/generic-recurse render-mount walker"
```

---

### Task 2: `DecoratedBox`/`ColoredBox` chrome preservation

**Files:**
- Modify: `lib/src/skeleton/nib_skeleton_render_mount.dart` (extend `computeBonePaintCommands`)
- Modify: `test/skeleton/nib_skeleton_render_mount_test.dart` (append tests)

**Interfaces:**
- Same function signature; adds a `decoration`-kind command before recursing into the node's own children whenever `widget is DecoratedBox` or `widget is ColoredBox`.

- [ ] **Step 1: Write the failing tests**

Append to `test/skeleton/nib_skeleton_render_mount_test.dart`:

```dart
  testWidgets(
      'a DecoratedBox with a child preserves its own real decoration and still bones its child',
      (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      DecoratedBox(
        decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
        child: const Text('inside'),
      ),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(2));
    expect(commands[0].kind, BonePaintKind.decoration);
    final decoration = commands[0].decoration as BoxDecoration;
    expect(decoration.color, Colors.blue);
    expect(commands[1].kind, BonePaintKind.bone);
  });

  testWidgets('a ColoredBox with a child preserves its own real colour and still bones its child',
      (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      const ColoredBox(color: Colors.yellow, child: Text('inside')),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    expect(commands, hasLength(2));
    expect(commands[0].kind, BonePaintKind.decoration);
    final decoration = commands[0].decoration as BoxDecoration;
    expect(decoration.color, Colors.yellow);
  });

  testWidgets(
      'a StatefulWidget composing a DecoratedBox chrome around a CircleAvatar+Text preserves '
      'the chrome and shades the content (the NibCard shape)', (tester) async {
    final element = await _pumpAndFindElement(
      tester,
      _StatefulLeaf(
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Colors.black12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [CircleAvatar(radius: 16), Text('Name')],
          ),
        ),
      ),
    );
    final commands = computeBonePaintCommands(element, Offset.zero, _palette);
    // 1 decoration (the chrome) + 2 bones (avatar circle, text bar).
    expect(commands.where((c) => c.kind == BonePaintKind.decoration), hasLength(1));
    expect(commands.where((c) => c.kind == BonePaintKind.bone), hasLength(2));
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/skeleton/nib_skeleton_render_mount_test.dart`
Expected: FAIL — `DecoratedBox`/`ColoredBox` currently fall through to generic recursion (no chrome command), so command counts/kinds don't match.

- [ ] **Step 3: Write the implementation**

In `lib/src/skeleton/nib_skeleton_render_mount.dart`, insert this block in
`computeBonePaintCommands`, after the `CircleAvatar` block and before the
`_recurseChildren` fallthrough:

```dart
  if (widget is DecoratedBox) {
    if (renderObject is RenderBox) {
      final chrome = BonePaintCommand.decoration(
        rect: offset & renderObject.size,
        decoration: widget.decoration,
      );
      return [chrome, ..._recurseChildren(element, offset, palette)];
    }
  }

  if (widget is ColoredBox) {
    if (renderObject is RenderBox) {
      final chrome = BonePaintCommand.decoration(
        rect: offset & renderObject.size,
        decoration: BoxDecoration(color: widget.color),
      );
      return [chrome, ..._recurseChildren(element, offset, palette)];
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/skeleton/nib_skeleton_render_mount_test.dart`
Expected: `00:01 +10: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/src/skeleton/nib_skeleton_render_mount.dart test/skeleton/nib_skeleton_render_mount_test.dart
git commit -m "feat(skeleton): preserve DecoratedBox/ColoredBox chrome in the render-mount walker"
```

---

### Task 3: `NibSkeletonRenderMount` — the custom Element + RenderObject that actually paints

**Files:**
- Modify: `lib/src/skeleton/nib_skeleton_render_mount.dart` (add the widget/Element/RenderObject)
- Modify: `test/skeleton/nib_skeleton_render_mount_test.dart` (append tests)

**Interfaces:**
- Consumes: `computeBonePaintCommands` (this file, Tasks 1–2).
- Produces: `class NibSkeletonRenderMount extends SingleChildRenderObjectWidget` with `required NibSkeletonPalette palette` (plus the inherited `child`).

- [ ] **Step 1: Write the failing tests**

Append to `test/skeleton/nib_skeleton_render_mount_test.dart`:

```dart
  testWidgets('NibSkeletonRenderMount lays out to exactly its real child\'s size, no crash',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Center(
        child: NibSkeletonRenderMount(
          palette: _palette,
          child: const _StatefulLeaf(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [CircleAvatar(radius: 20), Text('Name')],
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    final mountSize = tester.getSize(find.byType(NibSkeletonRenderMount));
    final realSize = tester.getSize(find.byType(Row));
    expect(mountSize, realSize);
  });

  testWidgets('NibSkeletonRenderMount survives a rebuild with a different child (update, not just mount)',
      (tester) async {
    Widget host(String label) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Center(
            child: NibSkeletonRenderMount(
              palette: _palette,
              child: _StatefulLeaf(child: Text(label)),
            ),
          ),
        );
    await tester.pumpWidget(host('first'));
    await tester.pumpWidget(host('second'));
    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/skeleton/nib_skeleton_render_mount_test.dart`
Expected: FAIL — `NibSkeletonRenderMount` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Append to `lib/src/skeleton/nib_skeleton_render_mount.dart`:

```dart
/// Mounts [child] completely normally (real `initState`, real tickers — any
/// `StatefulWidget` resolves exactly as it would anywhere else), but paints
/// [computeBonePaintCommands]'s decision instead of the child's real pixels.
class NibSkeletonRenderMount extends SingleChildRenderObjectWidget {
  const NibSkeletonRenderMount({super.key, required Widget child, required this.palette})
      : super(child: child);

  final NibSkeletonPalette palette;

  @override
  RenderObjectElement createElement() => _NibSkeletonMountElement(this);

  @override
  RenderNibSkeletonMount createRenderObject(BuildContext context) {
    return RenderNibSkeletonMount(palette: palette);
  }

  @override
  void updateRenderObject(BuildContext context, RenderNibSkeletonMount renderObject) {
    renderObject.palette = palette;
  }
}

/// Re-implements `SingleChildRenderObjectElement`'s mount/update/child-slot
/// wiring (its `_child` field isn't reachable from outside `framework.dart`)
/// so the tracked child [Element] can be pushed to [RenderNibSkeletonMount]
/// for [computeBonePaintCommands] to walk during paint.
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
    (renderObject as RenderNibSkeletonMount).child = child as RenderBox;
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    assert(false, 'NibSkeletonRenderMount has a single child slot.');
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    (renderObject as RenderNibSkeletonMount).child = null;
  }
}

/// Paints [computeBonePaintCommands]'s decision instead of delegating to the
/// real child's own `paint()`. Layout/size are inherited from
/// [RenderProxyBox] unchanged — this render object's size is always exactly
/// its child's real, normally-computed size.
class RenderNibSkeletonMount extends RenderProxyBox {
  RenderNibSkeletonMount({required NibSkeletonPalette palette}) : _palette = palette;

  NibSkeletonPalette _palette;
  set palette(NibSkeletonPalette value) {
    if (_palette == value) return;
    _palette = value;
    markNeedsPaint();
  }

  Element? rootElement;

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
            ImageConfiguration(size: command.rect.size),
          );
        case BonePaintKind.bone:
          final paint = Paint()..color = _palette.baseColor;
          if (command.shape == NibSkeletonShape.circle) {
            context.canvas.drawOval(command.rect, paint);
          } else if (command.radius != null) {
            context.canvas.drawRRect(command.radius!.toRRect(command.rect), paint);
          } else {
            context.canvas.drawRect(command.rect, paint);
          }
      }
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/skeleton/nib_skeleton_render_mount_test.dart`
Expected: `00:01 +12: All tests passed!`

- [ ] **Step 5: Run the full test suite and analyzer**

Run: `flutter test`
Expected: all tests pass.

Run: `flutter analyze`
Expected: only the pre-existing findings unrelated to `skeleton/`.

- [ ] **Step 6: Commit**

```bash
git add lib/src/skeleton/nib_skeleton_render_mount.dart test/skeleton/nib_skeleton_render_mount_test.dart
git commit -m "feat(skeleton): add NibSkeletonRenderMount — the Element/RenderObject that paints bone commands"
```

---

### Task 4: Wire bucket 4 to the render-mount engine, update the affected existing test, verify with the real Card/Button example

**Files:**
- Modify: `lib/src/skeleton/nib_skeleton_shade.dart` (bucket 4)
- Modify: `test/skeleton/nib_skeleton_shade_test.dart` (update the one test whose expected behavior changes)

**Interfaces:**
- Consumes: `NibSkeletonRenderMount` (this file's sibling, Task 3).
- Produces: `shadeWidget`'s final fallback (`StatefulWidget`, currently `buildBoneBox(palette: palette)`) becomes `NibSkeletonRenderMount(palette: palette, child: node)`.

- [ ] **Step 1: Update the test whose expectations change**

In `test/skeleton/nib_skeleton_shade_test.dart`, replace the existing test
(from Task 2 of the original plan):

```dart
  testWidgets('unrecognized StatefulWidget becomes a fallback bone box', (tester) async {
    await _pumpShaded(tester, const _CustomStateful());
    final box = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(box.width, 80);
    expect(box.height, 16);
    expect(find.text('stateful content'), findsNothing);
  });
```

with:

```dart
  testWidgets(
      'a StatefulWidget is walked through by the render-mount engine, not flattened '
      'into a generic fallback box', (tester) async {
    await _pumpShaded(tester, const _CustomStateful());
    expect(find.byType(NibSkeletonRenderMount), findsOneWidget);
    // The real Text is genuinely mounted (real lifecycle) — just not painted.
    expect(find.text('stateful content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
```

Add the import: `import 'package:nib_components/src/skeleton/nib_skeleton_render_mount.dart';`

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/skeleton/nib_skeleton_shade_test.dart`
Expected: FAIL — bucket 4 still returns a plain `buildBoneBox`, so no `NibSkeletonRenderMount` exists in the tree yet.

- [ ] **Step 3: Wire bucket 4**

In `lib/src/skeleton/nib_skeleton_shade.dart`:

Add the import:

```dart
import 'nib_skeleton_render_mount.dart';
```

Replace the final fallback in `shadeWidget`:

```dart
  if (node is StatelessWidget) {
    try {
      // ignore: invalid_use_of_protected_member
      final built = node.build(context);
      return shadeWidget(context, built, palette);
    } catch (_) {
      return buildBoneBox(palette: palette);
    }
  }

  return buildBoneBox(palette: palette);
}
```

with:

```dart
  if (node is StatelessWidget) {
    try {
      // ignore: invalid_use_of_protected_member
      final built = node.build(context);
      return shadeWidget(context, built, palette);
    } catch (_) {
      return buildBoneBox(palette: palette);
    }
  }

  if (node is StatefulWidget) {
    return NibSkeletonRenderMount(palette: palette, child: node);
  }

  return buildBoneBox(palette: palette);
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/skeleton/nib_skeleton_shade_test.dart`
Expected: all tests pass, including the updated one.

- [ ] **Step 5: Run the full suite, analyzer, and the real Card example**

Run: `flutter test`
Expected: all tests pass.

Run: `flutter analyze`
Expected: only pre-existing findings.

Run: `(cd example && flutter build web)`
Expected: builds clean — confirms `SkeletonCardExample` (real `NibCard`/`NibButton`) compiles through the new path.

- [ ] **Step 6: Commit**

```bash
git add lib/src/skeleton/nib_skeleton_shade.dart test/skeleton/nib_skeleton_shade_test.dart
git commit -m "feat(skeleton): route StatefulWidget nodes through the render-mount engine instead of a flat box"
```

---

## Self-Review Notes

- **Spec coverage:** every mechanism in `2026-07-19-skeleton-render-mount.md` (Element re-implementation, paint-command walker, chrome preservation, generic recursion via `Element.visitChildren`, real-size fallback, the documented `Material`/shimmer gaps) maps to a task above.
- **Type consistency:** `computeBonePaintCommands(Element, Offset, NibSkeletonPalette) -> List<BonePaintCommand>` is defined once in Task 1 and extended (same signature) in Task 2; `NibSkeletonRenderMount`/`RenderNibSkeletonMount`/`_NibSkeletonMountElement` names are used identically across Tasks 3–4.
- **No placeholders:** every step has complete, compilable code. The two known gaps (`Material`/`PhysicalShape` chrome, no shimmer on render-mounted bones) are explicitly out-of-scope-and-documented, not silently dropped — add both to `NIB_COMPONENTS_PROGRESS.md`'s Known Gaps table as part of Task 4's commit if not already covered by the spec doc reference.
