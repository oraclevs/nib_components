# nib_components — build setup design

Date: 2026-07-10

## Context

`nib_components` is a fresh restart (package scaffolded 2026-07-10) of the Nib
component effort, replacing the old CLI-copies-files-into-project registry
model documented in `/home/occ/Projects/Nib/CLAUDE.md`. That old model's
`componets/` package and its `ComponetsNib/preview/` demo app are stale — the
demo app's dependency (`path: ../componets`) points at a folder that no
longer exists.

`nib_components` is now a normal, installable Flutter package (component
source lives directly in `lib/`, no per-component `meta.json`/CDN registry).
Component specs, architecture rules, and build order (37 components, Tier A
hardest → Tier C simplest) are locked in
`NIB_COMPONENTS_MASTER_PROMPT.md` in this repo — not re-litigated here. This
doc only covers the infrastructure/workflow needed to start building.

## Decisions

1. **Repo**: `nib_components/` is its own standalone git repo (this repo),
   independent of `nib_motion`'s repo at `/home/occ/Projects/Nib/MotionNib/motion`.
2. **nib_motion dependency**: `nib_components/pubspec.yaml` depends on
   `nib_motion` via `path: ../../MotionNib/motion`, per the master prompt's
   §1.4 NibMotion integration contract (every component takes an
   `animated: bool` param and routes through NibMotion, never
   implicit-animation widgets).
3. **Demo app**: `nib_components/example/` (standard Flutter package
   convention), scaffolded with `flutter create --platforms=linux,web .`.
   Depends on `nib_components` via `path: ../` and `nib_motion` via
   `path: ../../../MotionNib/motion`. The old `ComponetsNib/preview/` app is
   left alone (stale, out of scope — not fixed, not deleted).
   `example/lib/main.dart` provides a simple nav (list/sidebar of component
   names) so every built component's preview is reachable in one running
   app — no relaunch needed as components are added.
4. **Progress tracking**: `nib_components/NIB_COMPONENTS_PROGRESS.md`, one
   row per component: name, status (not started / in progress / built /
   tested / verified), date. Updated as each component lands, per master
   prompt §8.4.
5. **Visual-confirm workflow**: the user runs `flutter run -d linux` once in
   `example/` and keeps it open for the whole build. After each component
   lands (widget + its example nav entry), the user hot-reloads (`r`) and
   visually confirms before the next component starts. Automated evidence
   (widget tests per master prompt §1.6) is run and reported by Claude
   separately — the visual check is the user's half, not a substitute for
   it.
6. **Build order**: strict top-to-bottom per master prompt §3 — **Data
   Table** first (Tier A #1). No shared-primitive reorder triggered yet
   (Data Table doesn't depend on Popover's anchoring logic, unlike
   Select/Date Picker/Nav Menu/Context Menu/Hover Card later in Tier A).

## Out of scope

- Fixing or reviving `ComponetsNib/preview/` or `ComponetsNib/devtools/`
  (old CLI/registry tooling) — not used by this effort.
- Publishing to pub.dev — not until the master prompt's build list is
  substantially complete.
- Android/iOS/macos/Windows platform support for `example/` — Linux +
  web only, per user request.
