# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`nib_components` is a native, installable Flutter UI component library (a normal pub package — `NibDataTable`, etc. get imported directly, not copy-pasted by a CLI). It's built on top of `nib_motion` (a sibling animation package at `../../MotionNib/motion`, wired in as a path dependency). This is a fresh restart (started 2026-07-10) of an earlier, now-abandoned CLI/registry-based model described in `/home/occ/Projects/Nib/CLAUDE.md` — ignore that file and the old `ComponetsNib/preview`/`ComponetsNib/devtools` folders; they're stale and unrelated to this package.

> **Note (v0.1.0 release prep):** The build-phase docs this file used to point to —
> `NIB_COMPONENTS_MASTER_PROMPT.md` (the full component spec, build order, and
> per-component instructions) and `NIB_COMPONENTS_PROGRESS.md` (the build/status
> tracker with its "Known gaps" table) — were removed once the library reached its
> feature-complete v0.1.0 state. Any mention of them, or of their "§" section
> numbers, in the sections below is **historical**. The architecture rules that
> still apply are self-contained in the **Architecture** section further down; the
> session-workflow bullets that follow describe how components were built and remain
> useful as convention, minus the now-absent progress tracker.

## Session workflow rules (do not deviate without asking)

- **One component per session.** Finish (or explicitly pause) the current component before starting the next one. Don't jump ahead in the build order without a documented reason (see MASTER_PROMPT §8.5 on flagging reorders).
- **Write code directly — no implementer/reviewer subagent pattern by default.** Early sessions used a full subagent-driven-development flow (fresh implementer subagent + fresh reviewer subagent per task, plus a final whole-branch review) for the first component. It produced good results but burned a large fraction of a session's token budget on a single component. For a solo project without a compliance/audit requirement, that's not worth the cost — write the widget and its tests directly in the main session, using TDD (failing test → implementation → passing test) the same way the plan-writing conventions describe, without spawning subagents for routine implementation or review. Only reach for subagents if explicitly asked, or for something genuinely too large to hold in context at once.
- **Visual confirmation gate.** After a component's widget + tests + example wiring are done, update its row in `NIB_COMPONENTS_PROGRESS.md` to `built — awaiting visual confirm` and stop. The user runs `flutter run -d linux` themselves in `example/` (keeps it running across the whole build, hot-reloads as things land) and confirms it looks/works right before you move to the next component. Don't mark a component `verified` yourself — that status is reserved for the user's own check.
- **Evidence, not claims.** Per MASTER_PROMPT §1.6: run `flutter test` and `flutter analyze` yourself and report actual output before saying something works. Don't claim "tests added" without showing the pass.
- **Deferred scope gets written down, not dropped.** If something in a component's spec is genuinely out of scope for now (needs a component that doesn't exist yet, needs RenderObject-level work disproportionate to the rest of the task), add it to `NIB_COMPONENTS_PROGRESS.md`'s "Known gaps" table with a one-line reason, rather than silently skipping it.
- If a plan doc is useful for a particular component (it doesn't have to be — direct implementation is fine for most), it goes in `docs/superpowers/plans/YYYY-MM-DD-<component>.md`, following the existing `2026-07-10-nib-data-table.md` as a template.

## Commands

```bash
# Run the package's own test suite (from repo root)
flutter test
flutter test test/data_table/nib_data_table_test.dart          # one file
flutter test test/data_table/nib_data_table_test.dart -n "onRowTap"  # one test by name

# Analyze the package
flutter analyze

# Get dependencies after touching pubspec.yaml (package or example)
flutter pub get
(cd example && flutter pub get)

# Run the live example app (Linux desktop, hot-reloadable) — the user
# typically keeps this running across a whole session
(cd example && flutter run -d linux)

# Analyze / build-check the example app
(cd example && flutter analyze)
(cd example && flutter build linux --debug)
```

Two pre-existing, expected analyzer findings that are NOT bugs — don't try to fix them:
- `invalid_dependency` on `pubspec.yaml`'s `nib_motion: path: ...` — expected while both packages are developed side by side pre-publish.
- `prefer_initializing_formals` (info) on `NibDataTableController`'s constructor — cosmetic, matches the locked design in the plan.

## Architecture

- **`lib/src/<component>/`** — one directory per component. A component's files live together: the widget itself, any supporting types/enums, and an optional controller. See `lib/src/data_table/` (`nib_data_table.dart`, `nib_data_table_types.dart`, `nib_data_column.dart`, `nib_data_table_controller.dart`) as the reference shape. Everything gets re-exported from `lib/nib_components.dart` (the package's public barrel file).
- **`lib/src/theme/nib_theme.dart`** — `NibTheme`, a `ThemeExtension<NibTheme>` carrying the locked color/border-radius design tokens (see MASTER_PROMPT §2 and the root `/home/occ/Projects/Nib/CLAUDE.md`'s token tables — same values, transcribed once here). Every component reads colors/radii via `NibTheme.of(context)`, never hardcoded hex. `NibTheme.of` falls back to `NibTheme.light`/`.dark` by ambient `Brightness` if the host app hasn't registered the extension on its `ThemeData`.
- **Stateful-by-default pattern** (MASTER_PROMPT §1.3/§4): every component is a `StatefulWidget` whose public constructor takes plain, simple parameters; all internal bookkeeping (loading/selection/sort/etc. state) lives in the private `State` class. An optional external `<Component>Controller` (e.g. `NibDataTableController`, a `ChangeNotifier`) is available for programmatic control but never required for basic use — the widget creates and owns its own controller internally when none is passed, and disposes it correctly on unmount/controller-swap.
- **NibMotion integration** (MASTER_PROMPT §1.4): every component takes `animated: bool = false` and, when relevant, a `transition: NibTransition?`. Animation routes exclusively through `nib_motion`'s `NibMotion`/`NibShimmer`/etc. widgets (from the sibling `nib_motion` package) — never `AnimatedContainer` or other implicit-animation widgets. When `animated: false`, zero `NibMotion` widgets should be built at all (not just configured off) — this is usually verified with a `find.byType(NibMotion), findsNothing` test.
- **Responsive by default** (MASTER_PROMPT §1.7, added after Data Table): components must not silently clip/overflow/squish when the viewport is narrower than their natural content size. `NibDataTable` sets the pattern — a `LayoutBuilder` checks available width against intrinsic content width and falls back to a scrollable axis (`SingleChildScrollView`) instead of compressing content below a usable size.
- **`example/`** — a separate, standalone Flutter app (own `pubspec.yaml`, depends on `nib_components` via `path: ../` and on `nib_motion` directly) used for live visual confirmation. `example/lib/catalog.dart` holds a flat `List<CatalogEntry>` (name + builder) rendered as a sidebar list by `example/lib/main.dart`; `example/lib/examples/<component>_examples.dart` holds that component's demo widgets (by convention: minimal, a common variant, an advanced/fully-configured one, and any extra demo needed to reliably trigger a specific behavior — e.g. `DataTableWideExample` deterministically demonstrates horizontal scroll by using a fixed narrow container rather than relying on the host window being narrow). Register new demos in `catalog.dart` in build order.
- Both `nib_components` and `example/` are Flutter **package**-vs-**app** pubspec conventions respectively: the package's `pubspec.lock` is gitignored (consumers resolve their own), `example/`'s is not (apps commit their lockfile).

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
