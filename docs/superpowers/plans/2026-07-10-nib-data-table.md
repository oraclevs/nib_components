# NibDataTable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `NibDataTable<T>`, the first component in `nib_components` (Tier A #1, hardest-first build order), as a native, virtualized, sortable, selectable data table — plus the `NibTheme` design-token extension every future component will reuse.

**Architecture:** `NibTheme` is a `ThemeExtension<NibTheme>` carrying the locked color/radius token table, resolved via `NibTheme.of(context)` with a light/dark fallback when the host app hasn't registered it. `NibDataTable` is a `StatefulWidget` composing `CustomScrollView` + `SliverPersistentHeader` (pinned = sticky) + `SliverFixedExtentList.builder` (virtualization, uniform row height) — never an eagerly-built `Column`/`ListView(children: ...)`. Sort and selection state live in an internally-owned `NibDataTableController<T>` (external controller optional). Animation is fully opt-in via `animated: bool`, routed through `nib_motion`'s `NibMotion`/`NibShimmer` widgets — zero `NibMotion` allocations when `animated: false`.

**Tech Stack:** Flutter 3.44.1 / Dart 3.12.1 (stable channel), `nib_motion` 0.2.1 (path dependency, already wired), `flutter_lints` ^6.0.0. No new pub dependencies.

## Global Constraints

- Widget class name: `NibDataTable<T>` (public widgets prefixed `Nib`, PascalCase) — per root `CLAUDE.md` Component Naming Convention and master prompt section 1.
- No hardcoded hex colors anywhere in component code — every color comes from `NibTheme.of(context)`. Border radius only from `NibTheme`'s `radiusSm`(4)/`radiusDefault`(8)/`radiusLg`(12)/`radiusPill`(9999).
- Must render correctly in both light and dark mode with zero extra consumer config (master prompt section 2).
- Build native, not wrapped: use `CustomScrollView`/`SliverPersistentHeader`/`SliverFixedExtentList`, `InkWell`/`Material`, `Checkbox` — Flutter's own low-level primitives — never `AnimatedContainer`/implicit-animation widgets for anything `nib_motion` should own (master prompt section 1.1, 1.4).
- Simple by default: `NibDataTable(columns: ..., rows: ...)` alone must render a finished-looking table. Every other parameter is optional with a sensible default (master prompt section 1.2).
- Stateful by default: sort state, selection state, and loading-driven skeleton swap are all managed internally; consumer never needs `StatefulBuilder` for basic use. Optional `NibDataTableController<T>` for external control (master prompt section 1.3, 5.1).
- `animated: bool = false` default; when `true` and no explicit transition given, fall back to a built-in default `NibTransition`. Zero `NibMotion`/`MotionValue` allocation when `false` (master prompt section 1.4).
- Must virtualize rows — never build all rows eagerly, even for large `rows` lists (master prompt section 5.1).
- Output contract for this component (master prompt section 1.5, minus the retired meta.json/CDN registry piece — this package has no per-component registry): widget file(s), 3 usage examples (minimal, common variant, advanced), example-app preview wiring, widget tests.
- Zero required pub dependencies beyond `flutter` and `nib_motion` (already wired).

---

### Task 1: NibTheme design tokens

**Files:**
- Create: `lib/src/theme/nib_theme.dart`
- Create: `test/theme/nib_theme_test.dart`
- Modify: `lib/nib_components.dart`
- Modify: `example/lib/main.dart:1-24` (register `NibTheme` on both light/dark `ThemeData`)

**Interfaces:**
- Produces: `class NibTheme extends ThemeExtension<NibTheme>` with fields `background, foreground, card, cardForeground, primary, primaryForeground, secondary, secondaryForeground, muted, mutedForeground, accent, accentForeground, border, input, ring, destructive` (all `Color`) and `radiusSm, radiusDefault, radiusLg, radiusPill` (all `double`). Static consts `NibTheme.light`, `NibTheme.dark`. Static method `NibTheme.of(BuildContext context) -> NibTheme`.

- [ ] **Step 1: Write the failing test**

```dart
// test/theme/nib_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

void main() {
  test('light token values match the locked design system table', () {
    expect(NibTheme.light.background, const Color(0xFFFFFFFF));
    expect(NibTheme.light.foreground, const Color(0xFF0A0A0A));
    expect(NibTheme.light.primary, const Color(0xFF02569B));
    expect(NibTheme.light.primaryForeground, const Color(0xFFFFFFFF));
    expect(NibTheme.light.border, const Color(0xFFE2E8F0));
    expect(NibTheme.light.destructive, const Color(0xFFEF4444));
    expect(NibTheme.light.radiusSm, 4);
    expect(NibTheme.light.radiusDefault, 8);
    expect(NibTheme.light.radiusLg, 12);
    expect(NibTheme.light.radiusPill, 9999);
  });

  test('dark token values match the locked design system table', () {
    expect(NibTheme.dark.background, const Color(0xFF0A0A0A));
    expect(NibTheme.dark.foreground, const Color(0xFFFAFAFA));
    expect(NibTheme.dark.primary, const Color(0xFF54C5F8));
    expect(NibTheme.dark.primaryForeground, const Color(0xFF0A0A0A));
    expect(NibTheme.dark.border, const Color(0xFF1E2433));
    expect(NibTheme.dark.destructive, const Color(0xFFEF4444));
  });

  testWidgets('NibTheme.of falls back to brightness when not registered', (
    tester,
  ) async {
    // Nests an explicit Theme override directly, rather than relying on
    // MaterialApp's theme/darkTheme/themeMode picking logic (which does not
    // reliably propagate a bare ThemeData(brightness: ...) passed to
    // `theme:` through to Theme.of(context).brightness). This isolates the
    // test to exactly what NibTheme.of needs to guarantee.
    late NibTheme resolvedLight;
    late NibTheme resolvedDark;
    await tester.pumpWidget(
      MaterialApp(
        home: Theme(
          data: ThemeData(brightness: Brightness.light),
          child: Builder(
            builder: (context) {
              resolvedLight = NibTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(resolvedLight, NibTheme.light);

    await tester.pumpWidget(
      MaterialApp(
        home: Theme(
          data: ThemeData(brightness: Brightness.dark),
          child: Builder(
            builder: (context) {
              resolvedDark = NibTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(resolvedDark, NibTheme.dark);
  });

  testWidgets('NibTheme.of prefers a registered extension', (tester) async {
    const custom = NibTheme(
      background: Color(0xFF123456),
      foreground: Color(0xFFFFFFFF),
      card: Color(0xFF123456),
      cardForeground: Color(0xFFFFFFFF),
      primary: Color(0xFFFFFFFF),
      primaryForeground: Color(0xFF000000),
      secondary: Color(0xFF000000),
      secondaryForeground: Color(0xFFFFFFFF),
      muted: Color(0xFF000000),
      mutedForeground: Color(0xFFFFFFFF),
      accent: Color(0xFF000000),
      accentForeground: Color(0xFFFFFFFF),
      border: Color(0xFF000000),
      input: Color(0xFF000000),
      ring: Color(0xFF000000),
      destructive: Color(0xFFEF4444),
      radiusSm: 4,
      radiusDefault: 8,
      radiusLg: 12,
      radiusPill: 9999,
    );
    late NibTheme resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [custom]),
        home: Builder(
          builder: (context) {
            resolved = NibTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(resolved, custom);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme/nib_theme_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:nib_components/nib_components.dart'` has no `NibTheme` (or compile error, since `NibTheme` doesn't exist yet).

- [ ] **Step 3: Write the implementation**

```dart
// lib/src/theme/nib_theme.dart
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The locked Nib design-token palette, exposed as a [ThemeExtension] so
/// every component reads colors/radii from [NibTheme.of] instead of
/// hardcoding hex values.
@immutable
class NibTheme extends ThemeExtension<NibTheme> {
  const NibTheme({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.border,
    required this.input,
    required this.ring,
    required this.destructive,
    required this.radiusSm,
    required this.radiusDefault,
    required this.radiusLg,
    required this.radiusPill,
  });

  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color border;
  final Color input;
  final Color ring;
  final Color destructive;

  final double radiusSm;
  final double radiusDefault;
  final double radiusLg;
  final double radiusPill;

  /// The light-mode token set.
  static const NibTheme light = NibTheme(
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF0A0A0A),
    card: Color(0xFFFFFFFF),
    cardForeground: Color(0xFF0A0A0A),
    primary: Color(0xFF02569B),
    primaryForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFFF4F8FF),
    secondaryForeground: Color(0xFF02569B),
    muted: Color(0xFFF1F5F9),
    mutedForeground: Color(0xFF64748B),
    accent: Color(0xFF54C5F8),
    accentForeground: Color(0xFF02569B),
    border: Color(0xFFE2E8F0),
    input: Color(0xFFE2E8F0),
    ring: Color(0xFF0175C2),
    destructive: Color(0xFFEF4444),
    radiusSm: 4,
    radiusDefault: 8,
    radiusLg: 12,
    radiusPill: 9999,
  );

  /// The dark-mode token set.
  static const NibTheme dark = NibTheme(
    background: Color(0xFF0A0A0A),
    foreground: Color(0xFFFAFAFA),
    card: Color(0xFF111111),
    cardForeground: Color(0xFFFAFAFA),
    primary: Color(0xFF54C5F8),
    primaryForeground: Color(0xFF0A0A0A),
    secondary: Color(0xFF1A1F2E),
    secondaryForeground: Color(0xFF54C5F8),
    muted: Color(0xFF1A1A1A),
    mutedForeground: Color(0xFF94A3B8),
    accent: Color(0xFF0175C2),
    accentForeground: Color(0xFFFFFFFF),
    border: Color(0xFF1E2433),
    input: Color(0xFF1E2433),
    ring: Color(0xFF54C5F8),
    destructive: Color(0xFFEF4444),
    radiusSm: 4,
    radiusDefault: 8,
    radiusLg: 12,
    radiusPill: 9999,
  );

  /// Resolves the ambient [NibTheme]: the host app's registered
  /// `ThemeData.extensions` entry if present, otherwise [light]/[dark]
  /// picked from the ambient [Brightness].
  static NibTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<NibTheme>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  NibTheme copyWith({
    Color? background,
    Color? foreground,
    Color? card,
    Color? cardForeground,
    Color? primary,
    Color? primaryForeground,
    Color? secondary,
    Color? secondaryForeground,
    Color? muted,
    Color? mutedForeground,
    Color? accent,
    Color? accentForeground,
    Color? border,
    Color? input,
    Color? ring,
    Color? destructive,
    double? radiusSm,
    double? radiusDefault,
    double? radiusLg,
    double? radiusPill,
  }) {
    return NibTheme(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      card: card ?? this.card,
      cardForeground: cardForeground ?? this.cardForeground,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      border: border ?? this.border,
      input: input ?? this.input,
      ring: ring ?? this.ring,
      destructive: destructive ?? this.destructive,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusDefault: radiusDefault ?? this.radiusDefault,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusPill: radiusPill ?? this.radiusPill,
    );
  }

  @override
  NibTheme lerp(ThemeExtension<NibTheme>? other, double t) {
    if (other is! NibTheme) return this;
    return NibTheme(
      background: Color.lerp(background, other.background, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardForeground: Color.lerp(cardForeground, other.cardForeground, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryForeground: Color.lerp(
        primaryForeground,
        other.primaryForeground,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryForeground: Color.lerp(
        secondaryForeground,
        other.secondaryForeground,
        t,
      )!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentForeground: Color.lerp(
        accentForeground,
        other.accentForeground,
        t,
      )!,
      border: Color.lerp(border, other.border, t)!,
      input: Color.lerp(input, other.input, t)!,
      ring: Color.lerp(ring, other.ring, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusDefault: lerpDouble(radiusDefault, other.radiusDefault, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
      radiusPill: lerpDouble(radiusPill, other.radiusPill, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NibTheme &&
        other.background == background &&
        other.foreground == foreground &&
        other.card == card &&
        other.cardForeground == cardForeground &&
        other.primary == primary &&
        other.primaryForeground == primaryForeground &&
        other.secondary == secondary &&
        other.secondaryForeground == secondaryForeground &&
        other.muted == muted &&
        other.mutedForeground == mutedForeground &&
        other.accent == accent &&
        other.accentForeground == accentForeground &&
        other.border == border &&
        other.input == input &&
        other.ring == ring &&
        other.destructive == destructive &&
        other.radiusSm == radiusSm &&
        other.radiusDefault == radiusDefault &&
        other.radiusLg == radiusLg &&
        other.radiusPill == radiusPill;
  }

  @override
  int get hashCode => Object.hash(
    background,
    foreground,
    card,
    cardForeground,
    primary,
    primaryForeground,
    secondary,
    secondaryForeground,
    muted,
    mutedForeground,
    Object.hash(accent, accentForeground, border, input, ring, destructive),
    Object.hash(radiusSm, radiusDefault, radiusLg, radiusPill),
  );
}
```

```dart
// lib/nib_components.dart
export 'src/theme/nib_theme.dart';
```

(Remove the placeholder `Calculator` class and its export from this file — it was the `flutter create --template=package` stub, never used.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/theme/nib_theme_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Wire NibTheme into the example app**

Replace `example/lib/main.dart`'s `theme`/`darkTheme` with:

```dart
theme: ThemeData(
  colorSchemeSeed: const Color(0xFF02569B),
  extensions: const [NibTheme.light],
),
darkTheme: ThemeData(
  colorSchemeSeed: const Color(0xFF54C5F8),
  brightness: Brightness.dark,
  extensions: const [NibTheme.dark],
),
```

Add `import 'package:nib_components/nib_components.dart';` at the top of `example/lib/main.dart`.

- [ ] **Step 6: Run the full test suite and the example app's analyzer**

Run: `flutter test && (cd example && flutter analyze)`
Expected: all tests PASS, `No issues found!` from analyze.

- [ ] **Step 7: Commit**

```bash
git add lib/src/theme lib/nib_components.dart test/theme example/lib/main.dart
git rm test/nib_components_test.dart
git commit -m "feat(theme): add NibTheme design-token extension"
```

(`test/nib_components_test.dart` is the `flutter create` stub testing the removed `Calculator` class — delete it, it no longer compiles.)

---

### Task 2: Data table models — columns, sort, selection mode, controller

**Files:**
- Create: `lib/src/data_table/nib_data_table_types.dart`
- Create: `lib/src/data_table/nib_data_column.dart`
- Create: `lib/src/data_table/nib_data_table_controller.dart`
- Create: `test/data_table/nib_data_table_controller_test.dart`
- Modify: `lib/nib_components.dart`

**Interfaces:**
- Consumes: nothing new (pure Dart + `Listenable`/`ChangeNotifier` from `flutter/foundation.dart`).
- Produces:
  - `typedef NibCellBuilder<T> = Widget Function(BuildContext context, T row)`
  - `typedef NibSortValueGetter<T> = Comparable<Object?> Function(T row)`
  - `enum NibSortDirection { none, ascending, descending }`
  - `class NibDataTableSort { const NibDataTableSort({int? columnIndex, NibSortDirection direction = NibSortDirection.none}); final int? columnIndex; final NibSortDirection direction; }`
  - `enum NibDataTableSelectionMode { none, single, multi }`
  - `class NibDataColumn<T> { const NibDataColumn({required String label, required NibCellBuilder<T> cellBuilder, NibSortValueGetter<T>? sortValue, double? width, double minWidth = 96}); bool get sortable; }`
  - `class NibDataTableController<T> extends ChangeNotifier { NibDataTableController({NibDataTableSort sort = const NibDataTableSort(), Set<T>? selected}); NibDataTableSort get sort; Set<T> get selected; void setSort(NibDataTableSort sort); void setSelected(Set<T> rows); void toggleSelected(T row); void clearSelection(); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/data_table/nib_data_table_controller_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

void main() {
  group('NibDataTableController', () {
    test('starts with the given sort and selection', () {
      final controller = NibDataTableController<int>(
        sort: const NibDataTableSort(
          columnIndex: 1,
          direction: NibSortDirection.ascending,
        ),
        selected: {1, 2},
      );
      expect(controller.sort.columnIndex, 1);
      expect(controller.sort.direction, NibSortDirection.ascending);
      expect(controller.selected, {1, 2});
    });

    test('setSort notifies listeners', () {
      final controller = NibDataTableController<int>();
      var notified = 0;
      controller.addListener(() => notified++);
      controller.setSort(
        const NibDataTableSort(
          columnIndex: 0,
          direction: NibSortDirection.descending,
        ),
      );
      expect(controller.sort.columnIndex, 0);
      expect(notified, 1);
    });

    test('toggleSelected adds then removes, notifying each time', () {
      final controller = NibDataTableController<String>();
      var notified = 0;
      controller.addListener(() => notified++);
      controller.toggleSelected('a');
      expect(controller.selected, {'a'});
      controller.toggleSelected('a');
      expect(controller.selected, isEmpty);
      expect(notified, 2);
    });

    test('setSelected replaces the whole set', () {
      final controller = NibDataTableController<int>(selected: {1});
      controller.setSelected({2, 3});
      expect(controller.selected, {2, 3});
    });

    test('clearSelection empties the set and only notifies if non-empty', () {
      final controller = NibDataTableController<int>(selected: {1});
      var notified = 0;
      controller.addListener(() => notified++);
      controller.clearSelection();
      expect(controller.selected, isEmpty);
      expect(notified, 1);
      controller.clearSelection();
      expect(notified, 1, reason: 'no-op clear should not notify again');
    });

    test('selected is unmodifiable', () {
      final controller = NibDataTableController<int>(selected: {1});
      expect(() => controller.selected.add(2), throwsUnsupportedError);
    });
  });

  test('NibDataColumn.sortable reflects whether sortValue is set', () {
    final withSort = NibDataColumn<int>(
      label: 'A',
      cellBuilder: (context, row) => Text('$row'),
      sortValue: (row) => row,
    );
    final withoutSort = NibDataColumn<int>(
      label: 'B',
      cellBuilder: (context, row) => Text('$row'),
    );
    expect(withSort.sortable, isTrue);
    expect(withoutSort.sortable, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data_table/nib_data_table_controller_test.dart`
Expected: FAIL — `NibDataTableController`/`NibDataColumn`/`NibDataTableSort`/`NibSortDirection` undefined.

- [ ] **Step 3: Write the implementation**

```dart
// lib/src/data_table/nib_data_table_types.dart

/// Which direction (if any) a `NibDataTable` column is currently sorted by.
enum NibSortDirection { none, ascending, descending }

/// The current sort state of a `NibDataTable`: which column index, and
/// which direction. `columnIndex: null` means unsorted.
class NibDataTableSort {
  const NibDataTableSort({
    this.columnIndex,
    this.direction = NibSortDirection.none,
  });

  final int? columnIndex;
  final NibSortDirection direction;

  NibDataTableSort copyWith({int? columnIndex, NibSortDirection? direction}) {
    return NibDataTableSort(
      columnIndex: columnIndex ?? this.columnIndex,
      direction: direction ?? this.direction,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NibDataTableSort &&
        other.columnIndex == columnIndex &&
        other.direction == direction;
  }

  @override
  int get hashCode => Object.hash(columnIndex, direction);
}

/// How a `NibDataTable` handles row selection.
enum NibDataTableSelectionMode {
  /// No selection UI or state.
  none,

  /// Tapping a row selects it, replacing any prior selection. No checkbox
  /// column.
  single,

  /// A leading checkbox column, plus a select-all checkbox in the header.
  multi,
}
```

```dart
// lib/src/data_table/nib_data_column.dart
import 'package:flutter/widgets.dart';

/// Builds the cell widget for [row] in this column.
typedef NibCellBuilder<T> = Widget Function(BuildContext context, T row);

/// Returns the value used to sort rows by this column. Must be
/// [Comparable] with itself (e.g. `String`, `num`, `DateTime`).
typedef NibSortValueGetter<T> = Comparable<Object?> Function(T row);

/// One column definition for a `NibDataTable<T>`.
class NibDataColumn<T> {
  const NibDataColumn({
    required this.label,
    required this.cellBuilder,
    this.sortValue,
    this.width,
    this.minWidth = 96,
  }) : assert(width == null || width > 0, 'width must be positive'),
       assert(minWidth > 0, 'minWidth must be positive');

  /// The header label.
  final String label;

  /// Builds each row's cell content for this column.
  final NibCellBuilder<T> cellBuilder;

  /// If set, this column's header can be tapped to sort by it, using this
  /// as the comparison key. If `null`, this column is not sortable.
  final NibSortValueGetter<T>? sortValue;

  /// Fixed column width. If `null`, the column flexes to fill remaining
  /// space (subject to [minWidth]).
  final double? width;

  /// Minimum width when this column is flexible (i.e. [width] is `null`).
  final double minWidth;

  /// Whether tapping this column's header cycles its sort direction.
  bool get sortable => sortValue != null;
}
```

```dart
// lib/src/data_table/nib_data_table_controller.dart
import 'package:flutter/foundation.dart';

import 'nib_data_table_types.dart';

/// Optional external controller for a `NibDataTable<T>`'s sort and
/// selection state. Never required for basic use — `NibDataTable` owns its
/// own controller internally when none is supplied.
class NibDataTableController<T> extends ChangeNotifier {
  NibDataTableController({
    NibDataTableSort sort = const NibDataTableSort(),
    Set<T>? selected,
  }) : _sort = sort,
       _selected = Set<T>.of(selected ?? const {});

  NibDataTableSort _sort;

  /// The current sort state.
  NibDataTableSort get sort => _sort;

  final Set<T> _selected;

  /// The currently-selected rows. Unmodifiable — use [setSelected],
  /// [toggleSelected], or [clearSelection] to change it.
  Set<T> get selected => Set<T>.unmodifiable(_selected);

  /// Replaces the sort state and notifies listeners.
  void setSort(NibDataTableSort sort) {
    _sort = sort;
    notifyListeners();
  }

  /// Replaces the whole selection set and notifies listeners.
  void setSelected(Set<T> rows) {
    _selected
      ..clear()
      ..addAll(rows);
    notifyListeners();
  }

  /// Adds [row] if not selected, removes it if it is. Notifies listeners.
  void toggleSelected(T row) {
    if (!_selected.remove(row)) {
      _selected.add(row);
    }
    notifyListeners();
  }

  /// Empties the selection. No-op (does not notify) if already empty.
  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }
}
```

```dart
// lib/nib_components.dart
export 'src/data_table/nib_data_column.dart';
export 'src/data_table/nib_data_table_controller.dart';
export 'src/data_table/nib_data_table_types.dart';
export 'src/theme/nib_theme.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data_table/nib_data_table_controller_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/src/data_table lib/nib_components.dart test/data_table
git commit -m "feat(data-table): add column/sort/selection/controller models"
```

---

### Task 3: NibDataTable core widget — layout, empty state, default render

**Files:**
- Create: `lib/src/data_table/nib_data_table.dart`
- Create: `test/data_table/nib_data_table_test.dart`
- Modify: `lib/nib_components.dart`

**Interfaces:**
- Consumes: `NibTheme.of` (Task 1); `NibDataColumn<T>`, `NibDataTableSort`, `NibSortDirection`, `NibDataTableSelectionMode`, `NibDataTableController<T>` (Task 2).
- Produces: `class NibDataTable<T> extends StatefulWidget` with constructor `NibDataTable({Key? key, required List<NibDataColumn<T>> columns, required List<T> rows, Key Function(T row)? rowKey, NibDataTableSelectionMode selectionMode = NibDataTableSelectionMode.none, ValueChanged<Set<T>>? onSelectionChanged, void Function(int columnIndex, NibSortDirection direction)? onSort, ValueChanged<T>? onRowTap, bool loading = false, Widget? emptyState, double rowHeight = 48, double headerHeight = 44, bool stickyHeader = true, NibDataTableController<T>? controller, bool animated = false, NibTransition? transition, String? semanticLabel})`. This task implements everything except sorting/selection *behavior* (header taps and checkboxes are inert placeholders wired fully in Tasks 4–5) and the loading skeleton (Task 6).

- [ ] **Step 1: Write the failing test**

```dart
// test/data_table/nib_data_table_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

class _Person {
  const _Person(this.name, this.email);
  final String name;
  final String email;
}

List<NibDataColumn<_Person>> _columns() => [
  NibDataColumn<_Person>(
    label: 'Name',
    cellBuilder: (context, row) => Text(row.name),
    sortValue: (row) => row.name,
  ),
  NibDataColumn<_Person>(
    label: 'Email',
    cellBuilder: (context, row) => Text(row.email),
  ),
];

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: const [NibTheme.light]),
    home: Scaffold(body: SizedBox(height: 400, child: child)),
  );
}

void main() {
  testWidgets('renders column headers and every row cell', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NibDataTable<_Person>(
          columns: _columns(),
          rows: const [
            _Person('Ada Lovelace', 'ada@example.com'),
            _Person('Alan Turing', 'alan@example.com'),
          ],
        ),
      ),
    );

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text('Alan Turing'), findsOneWidget);
    expect(find.text('alan@example.com'), findsOneWidget);
  });

  testWidgets('shows the default empty state when rows is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(NibDataTable<_Person>(columns: _columns(), rows: const [])),
    );
    expect(find.text('No data'), findsOneWidget);
  });

  testWidgets('shows a custom empty state when provided', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NibDataTable<_Person>(
          columns: _columns(),
          rows: const [],
          emptyState: const Text('Nothing here yet'),
        ),
      ),
    );
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('No data'), findsNothing);
  });

  testWidgets('onRowTap fires with the tapped row', (tester) async {
    _Person? tapped;
    const people = [
      _Person('Ada Lovelace', 'ada@example.com'),
      _Person('Alan Turing', 'alan@example.com'),
    ];
    await tester.pumpWidget(
      _wrap(
        NibDataTable<_Person>(
          columns: _columns(),
          rows: people,
          onRowTap: (row) => tapped = row,
        ),
      ),
    );

    await tester.tap(find.text('Alan Turing'));
    await tester.pumpAndSettle();
    expect(tapped, people[1]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data_table/nib_data_table_test.dart`
Expected: FAIL — `NibDataTable` undefined.

- [ ] **Step 3: Write the implementation**

```dart
// lib/src/data_table/nib_data_table.dart
import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import '../theme/nib_theme.dart';
import 'nib_data_column.dart';
import 'nib_data_table_controller.dart';
import 'nib_data_table_types.dart';

/// A native, virtualized, sortable, selectable data table.
///
/// Simplest usage needs only [columns] and [rows]:
///
/// ```dart
/// NibDataTable<Person>(
///   columns: [
///     NibDataColumn(label: 'Name', cellBuilder: (context, p) => Text(p.name)),
///   ],
///   rows: people,
/// )
/// ```
class NibDataTable<T> extends StatefulWidget {
  const NibDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.rowKey,
    this.selectionMode = NibDataTableSelectionMode.none,
    this.onSelectionChanged,
    this.onSort,
    this.onRowTap,
    this.loading = false,
    this.emptyState,
    this.rowHeight = 48,
    this.headerHeight = 44,
    this.stickyHeader = true,
    this.controller,
    this.animated = false,
    this.transition,
    this.semanticLabel,
  });

  /// The column definitions, in display order.
  final List<NibDataColumn<T>> columns;

  /// The rows to display. Sorted internally unless [onSort] is provided
  /// (in which case the caller is expected to already provide `rows` in
  /// the requested order — e.g. for server-side sorting).
  final List<T> rows;

  /// Produces a stable [Key] for a row, used to key its rendered widget
  /// (important when [animated] is `true`). Defaults to `ValueKey(row)`,
  /// which requires `T` to have stable `==`/`hashCode` (or stable
  /// identity) across rebuilds.
  final Key Function(T row)? rowKey;

  /// Whether/how rows can be selected.
  final NibDataTableSelectionMode selectionMode;

  /// Called whenever the selection changes (any [selectionMode]).
  final ValueChanged<Set<T>>? onSelectionChanged;

  /// Called when the user changes sort by tapping a sortable column
  /// header. If `null`, `NibDataTable` sorts [rows] itself using that
  /// column's `NibDataColumn.sortValue`. If set, the caller owns
  /// re-ordering `rows` (e.g. server-side); `NibDataTable` still tracks
  /// and displays the sort indicator.
  final void Function(int columnIndex, NibSortDirection direction)? onSort;

  /// Called when a row is tapped, regardless of [selectionMode].
  final ValueChanged<T>? onRowTap;

  /// Shows skeleton rows instead of [rows] while `true`.
  final bool loading;

  /// Shown instead of the row list when [rows] is empty and not
  /// [loading]. Defaults to a centered "No data" message.
  final Widget? emptyState;

  /// The height of every row, in logical pixels.
  final double rowHeight;

  /// The height of the header row, in logical pixels.
  final double headerHeight;

  /// Whether the header stays pinned while the body scrolls.
  final bool stickyHeader;

  /// Drives sort/selection state externally. Never required for basic
  /// use — `NibDataTable` creates and owns its own controller when this
  /// is `null`.
  final NibDataTableController<T>? controller;

  /// Opt-in row-entrance animation, via `nib_motion`. `false` allocates
  /// zero `NibMotion`/`MotionValue` overhead.
  final bool animated;

  /// The transition used for [animated] row entrances. Defaults to a
  /// 220ms ease-in-out fade/slide when `animated` is `true` and this is
  /// `null`.
  final NibTransition? transition;

  /// Accessibility label for the table as a whole.
  final String? semanticLabel;

  @override
  State<NibDataTable<T>> createState() => _NibDataTableState<T>();
}

class _NibDataTableState<T> extends State<NibDataTable<T>> {
  late NibDataTableController<T> _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant NibDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _unbindController();
      _bindController(widget.controller);
    }
  }

  @override
  void dispose() {
    _unbindController();
    super.dispose();
  }

  void _bindController(NibDataTableController<T>? external) {
    _controller = external ?? NibDataTableController<T>();
    _ownsController = external == null;
    _controller.addListener(_handleControllerChanged);
  }

  void _unbindController() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
  }

  void _handleControllerChanged() => setState(() {});

  Key _keyFor(T row) => widget.rowKey?.call(row) ?? ValueKey<T>(row);

  List<T> get _displayedRows {
    final sort = _controller.sort;
    if (widget.onSort != null || sort.columnIndex == null) {
      return widget.rows;
    }
    final column = widget.columns[sort.columnIndex!];
    final getter = column.sortValue;
    if (getter == null) return widget.rows;
    final sorted = List<T>.of(widget.rows)
      ..sort((a, b) => getter(a).compareTo(getter(b)));
    if (sort.direction == NibSortDirection.descending) {
      return sorted.reversed.toList(growable: false);
    }
    return sorted;
  }

  Widget _sizedCell(NibDataColumn<T> column, Widget child) {
    if (column.width != null) {
      return SizedBox(width: column.width, child: child);
    }
    return Expanded(
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: column.minWidth),
        child: child,
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, NibTheme theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.card,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: SizedBox(
        height: widget.headerHeight,
        child: Row(
          children: [
            for (var i = 0; i < widget.columns.length; i++)
              _sizedCell(
                widget.columns[i],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.columns[i].label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, NibTheme theme, T row, int index) {
    final content = SizedBox(
      height: widget.rowHeight,
      child: Row(
        children: [
          for (var i = 0; i < widget.columns.length; i++)
            _sizedCell(
              widget.columns[i],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: theme.foreground),
                    child: widget.columns[i].cellBuilder(context, row),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => widget.onRowTap?.call(row),
        child: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final rows = _displayedRows;

    return Semantics(
      label: widget.semanticLabel,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.border),
          borderRadius: BorderRadius.circular(theme.radiusDefault),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.radiusDefault),
          child: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: widget.stickyHeader,
                delegate: _NibDataTableHeaderDelegate(
                  height: widget.headerHeight,
                  child: _buildHeaderRow(context, theme),
                ),
              ),
              if (rows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child:
                      widget.emptyState ??
                      Center(
                        child: Text(
                          'No data',
                          style: TextStyle(color: theme.mutedForeground),
                        ),
                      ),
                )
              else
                SliverFixedExtentList.builder(
                  itemExtent: widget.rowHeight,
                  itemCount: rows.length,
                  itemBuilder: (context, index) =>
                      _buildRow(context, theme, rows[index], index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NibDataTableHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _NibDataTableHeaderDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _NibDataTableHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}
```

Note: `loading` is accepted in the constructor already but not yet branched on in `build()` — Task 6 adds the skeleton branch. Leaving it unused would be a dead parameter; add a one-line TODO-free guard now so analyzer doesn't warn: nothing needed, an unused constructor parameter that's stored on the widget doesn't trigger `unused_field`/`unused_element` (it's a public API field), so this is safe to leave until Task 6 without any lint suppression.

```dart
// lib/nib_components.dart
export 'src/data_table/nib_data_column.dart';
export 'src/data_table/nib_data_table.dart';
export 'src/data_table/nib_data_table_controller.dart';
export 'src/data_table/nib_data_table_types.dart';
export 'src/theme/nib_theme.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data_table/nib_data_table_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/data_table/nib_data_table.dart lib/nib_components.dart test/data_table/nib_data_table_test.dart
git commit -m "feat(data-table): add NibDataTable core layout, empty state, row tap"
```

---

### Task 4: Sorting — tap header to cycle asc/desc/none

**Files:**
- Modify: `lib/src/data_table/nib_data_table.dart` (`_buildHeaderRow`, add `_cycleSort`)
- Modify: `test/data_table/nib_data_table_test.dart` (append tests)

**Interfaces:**
- Consumes: `NibDataTableSort`, `NibSortDirection` (Task 2); `_controller` (Task 3).
- Produces: tapping a sortable header cell calls `_cycleSort(int columnIndex)`, which advances `NibSortDirection` `none -> ascending -> descending -> none` for that column (switching column resets to `ascending`), updates `_controller.sort`, and calls `widget.onSort?.call(columnIndex, direction)` if provided.

- [ ] **Step 1: Write the failing tests**

Append to `test/data_table/nib_data_table_test.dart`:

```dart
testWidgets('tapping a sortable header sorts rows ascending, then descending, then unsorted', (
  tester,
) async {
  const people = [
    _Person('Charlie', 'c@example.com'),
    _Person('Ada', 'a@example.com'),
    _Person('Bob', 'b@example.com'),
  ];
  await tester.pumpWidget(
    _wrap(NibDataTable<_Person>(columns: _columns(), rows: people)),
  );

  Text firstRowName() {
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .toList();
    return Text(texts.firstWhere((t) => people.any((p) => p.name == t))!);
  }

  // Unsorted: input order.
  expect(firstRowName().data, 'Charlie');

  await tester.tap(find.text('Name')); // -> ascending
  await tester.pumpAndSettle();
  expect(firstRowName().data, 'Ada');

  await tester.tap(find.text('Name')); // -> descending
  await tester.pumpAndSettle();
  expect(firstRowName().data, 'Charlie');

  await tester.tap(find.text('Name')); // -> none
  await tester.pumpAndSettle();
  expect(firstRowName().data, 'Charlie');
});

testWidgets('a non-sortable column header does nothing when tapped', (
  tester,
) async {
  const people = [
    _Person('Charlie', 'c@example.com'),
    _Person('Ada', 'a@example.com'),
  ];
  await tester.pumpWidget(
    _wrap(NibDataTable<_Person>(columns: _columns(), rows: people)),
  );
  await tester.tap(find.text('Email'));
  await tester.pumpAndSettle();
  // Order unchanged (Email column has no sortValue).
  expect(find.text('Charlie'), findsOneWidget);
});

testWidgets('onSort is called with the new column/direction instead of self-sorting', (
  tester,
) async {
  const people = [
    _Person('Charlie', 'c@example.com'),
    _Person('Ada', 'a@example.com'),
  ];
  int? sortedColumn;
  NibSortDirection? sortedDirection;
  await tester.pumpWidget(
    _wrap(
      NibDataTable<_Person>(
        columns: _columns(),
        rows: people,
        onSort: (columnIndex, direction) {
          sortedColumn = columnIndex;
          sortedDirection = direction;
        },
      ),
    ),
  );
  await tester.tap(find.text('Name'));
  await tester.pumpAndSettle();
  expect(sortedColumn, 0);
  expect(sortedDirection, NibSortDirection.ascending);
  // NibDataTable does not reorder rows itself in onSort mode.
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .toList();
  expect(texts.indexOf('Charlie') < texts.indexOf('Ada'), isTrue);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data_table/nib_data_table_test.dart`
Expected: FAIL — headers aren't tappable/sortable yet, so row order never changes and `onSort` is never called.

- [ ] **Step 3: Implement sorting**

In `lib/src/data_table/nib_data_table.dart`, add this method to `_NibDataTableState<T>`:

```dart
void _cycleSort(int columnIndex) {
  final current = _controller.sort;
  final NibSortDirection nextDirection;
  if (current.columnIndex != columnIndex) {
    nextDirection = NibSortDirection.ascending;
  } else {
    nextDirection = switch (current.direction) {
      NibSortDirection.none => NibSortDirection.ascending,
      NibSortDirection.ascending => NibSortDirection.descending,
      NibSortDirection.descending => NibSortDirection.none,
    };
  }
  _controller.setSort(
    NibDataTableSort(
      columnIndex: nextDirection == NibSortDirection.none ? null : columnIndex,
      direction: nextDirection,
    ),
  );
  widget.onSort?.call(columnIndex, nextDirection);
}
```

Replace the header cell's `Text` in `_buildHeaderRow` with a tappable version that also shows the sort icon:

```dart
Widget _buildHeaderRow(BuildContext context, NibTheme theme) {
  final sort = _controller.sort;
  return DecoratedBox(
    decoration: BoxDecoration(
      color: theme.card,
      border: Border(bottom: BorderSide(color: theme.border)),
    ),
    child: SizedBox(
      height: widget.headerHeight,
      child: Row(
        children: [
          for (var i = 0; i < widget.columns.length; i++)
            _sizedCell(widget.columns[i], _buildHeaderCell(theme, i, sort)),
        ],
      ),
    ),
  );
}

Widget _buildHeaderCell(NibTheme theme, int columnIndex, NibDataTableSort sort) {
  final column = widget.columns[columnIndex];
  final isSorted = sort.columnIndex == columnIndex && sort.direction != NibSortDirection.none;
  final label = Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            column.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (isSorted) ...[
          const SizedBox(width: 4),
          Icon(
            sort.direction == NibSortDirection.ascending
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            size: 14,
            color: theme.mutedForeground,
          ),
        ],
      ],
    ),
  );

  if (!column.sortable) {
    return Align(alignment: Alignment.centerLeft, child: label);
  }

  return Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: () => _cycleSort(columnIndex),
      child: Align(alignment: Alignment.centerLeft, child: label),
    ),
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data_table/nib_data_table_test.dart`
Expected: PASS (7 tests total)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/data_table/nib_data_table.dart test/data_table/nib_data_table_test.dart
git commit -m "feat(data-table): tap header to cycle sort asc/desc/none"
```

---

### Task 5: Selection — multi checkbox column + select-all, single row-tap select

**Files:**
- Modify: `lib/src/data_table/nib_data_table.dart`
- Modify: `test/data_table/nib_data_table_test.dart`

**Interfaces:**
- Consumes: `NibDataTableSelectionMode` (Task 2), `_controller.toggleSelected`/`setSelected`/`selected` (Task 2/3).
- Produces: when `selectionMode == multi`, a leading checkbox column (per-row + header select-all, tri-state). When `selectionMode == single`, tapping a row selects it (replacing prior selection) in addition to calling `onRowTap`. Both modes call `widget.onSelectionChanged` after any selection change.

- [ ] **Step 1: Write the failing tests**

Append to `test/data_table/nib_data_table_test.dart`:

```dart
testWidgets('multi selection: per-row checkbox toggles selection and calls onSelectionChanged', (
  tester,
) async {
  const people = [
    _Person('Ada Lovelace', 'ada@example.com'),
    _Person('Alan Turing', 'alan@example.com'),
  ];
  Set<_Person>? lastSelection;
  await tester.pumpWidget(
    _wrap(
      NibDataTable<_Person>(
        columns: _columns(),
        rows: people,
        selectionMode: NibDataTableSelectionMode.multi,
        onSelectionChanged: (selection) => lastSelection = selection,
      ),
    ),
  );

  final rowCheckboxes = find.byType(Checkbox);
  // First checkbox is the header select-all; row checkboxes follow.
  await tester.tap(rowCheckboxes.at(1));
  await tester.pumpAndSettle();
  expect(lastSelection, {people[0]});

  await tester.tap(rowCheckboxes.at(1));
  await tester.pumpAndSettle();
  expect(lastSelection, isEmpty);
});

testWidgets('multi selection: header checkbox selects/deselects all', (
  tester,
) async {
  const people = [
    _Person('Ada Lovelace', 'ada@example.com'),
    _Person('Alan Turing', 'alan@example.com'),
  ];
  Set<_Person>? lastSelection;
  await tester.pumpWidget(
    _wrap(
      NibDataTable<_Person>(
        columns: _columns(),
        rows: people,
        selectionMode: NibDataTableSelectionMode.multi,
        onSelectionChanged: (selection) => lastSelection = selection,
      ),
    ),
  );

  await tester.tap(find.byType(Checkbox).first);
  await tester.pumpAndSettle();
  expect(lastSelection, people.toSet());

  await tester.tap(find.byType(Checkbox).first);
  await tester.pumpAndSettle();
  expect(lastSelection, isEmpty);
});

testWidgets('single selection: tapping a row selects it and replaces prior selection', (
  tester,
) async {
  const people = [
    _Person('Ada Lovelace', 'ada@example.com'),
    _Person('Alan Turing', 'alan@example.com'),
  ];
  Set<_Person>? lastSelection;
  await tester.pumpWidget(
    _wrap(
      NibDataTable<_Person>(
        columns: _columns(),
        rows: people,
        selectionMode: NibDataTableSelectionMode.single,
        onSelectionChanged: (selection) => lastSelection = selection,
      ),
    ),
  );

  expect(find.byType(Checkbox), findsNothing);

  await tester.tap(find.text('Ada Lovelace'));
  await tester.pumpAndSettle();
  expect(lastSelection, {people[0]});

  await tester.tap(find.text('Alan Turing'));
  await tester.pumpAndSettle();
  expect(lastSelection, {people[1]});
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data_table/nib_data_table_test.dart`
Expected: FAIL — no `Checkbox` widgets exist yet, single-selection row taps don't affect selection.

- [ ] **Step 3: Implement selection**

Add to `_NibDataTableState<T>` in `lib/src/data_table/nib_data_table.dart`:

```dart
void _toggleRow(T row) {
  switch (widget.selectionMode) {
    case NibDataTableSelectionMode.none:
      return;
    case NibDataTableSelectionMode.single:
      final already = _controller.selected.contains(row);
      _controller.setSelected(already ? <T>{} : {row});
    case NibDataTableSelectionMode.multi:
      _controller.toggleSelected(row);
  }
  widget.onSelectionChanged?.call(_controller.selected);
}

void _toggleSelectAll(List<T> visibleRows, bool selectAll) {
  _controller.setSelected(selectAll ? visibleRows.toSet() : <T>{});
  widget.onSelectionChanged?.call(_controller.selected);
}
```

Update `_buildHeaderRow` to prepend a select-all checkbox cell when `selectionMode == multi`:

```dart
Widget _buildHeaderRow(BuildContext context, NibTheme theme, List<T> rows) {
  final sort = _controller.sort;
  final selected = _controller.selected;
  final allSelected = rows.isNotEmpty && rows.every(selected.contains);
  final someSelected = rows.any(selected.contains);

  return DecoratedBox(
    decoration: BoxDecoration(
      color: theme.card,
      border: Border(bottom: BorderSide(color: theme.border)),
    ),
    child: SizedBox(
      height: widget.headerHeight,
      child: Row(
        children: [
          if (widget.selectionMode == NibDataTableSelectionMode.multi)
            SizedBox(
              width: 48,
              child: Checkbox(
                value: allSelected ? true : (someSelected ? null : false),
                tristate: true,
                onChanged: (_) => _toggleSelectAll(rows, !allSelected),
              ),
            ),
          for (var i = 0; i < widget.columns.length; i++)
            _sizedCell(widget.columns[i], _buildHeaderCell(theme, i, sort)),
        ],
      ),
    ),
  );
}
```

Update `_buildRow` to prepend a per-row checkbox when `multi`, and to select-on-tap when `single`:

```dart
Widget _buildRow(BuildContext context, NibTheme theme, T row, int index) {
  final selected = _controller.selected.contains(row);
  final cells = Row(
    children: [
      if (widget.selectionMode == NibDataTableSelectionMode.multi)
        SizedBox(
          width: 48,
          child: Checkbox(
            value: selected,
            onChanged: (_) => _toggleRow(row),
          ),
        ),
      for (var i = 0; i < widget.columns.length; i++)
        _sizedCell(
          widget.columns[i],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: DefaultTextStyle.merge(
                style: TextStyle(color: theme.foreground),
                child: widget.columns[i].cellBuilder(context, row),
              ),
            ),
          ),
        ),
    ],
  );

  final content = Container(
    height: widget.rowHeight,
    color: selected ? theme.secondary : null,
    child: cells,
  );

  return Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: () {
        widget.onRowTap?.call(row);
        if (widget.selectionMode == NibDataTableSelectionMode.single) {
          _toggleRow(row);
        }
      },
      child: content,
    ),
  );
}
```

Update the two call sites in `build()`:
- `_buildHeaderRow(context, theme)` -> `_buildHeaderRow(context, theme, rows)`

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data_table/nib_data_table_test.dart`
Expected: PASS (10 tests total)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/data_table/nib_data_table.dart test/data_table/nib_data_table_test.dart
git commit -m "feat(data-table): multi checkbox selection with select-all, single row-tap selection"
```

---

### Task 6: Virtualization proof + loading skeleton rows

**Files:**
- Modify: `lib/src/data_table/nib_data_table.dart`
- Modify: `test/data_table/nib_data_table_test.dart`

**Interfaces:**
- Consumes: `widget.loading`, `widget.rowHeight` (Task 3).
- Produces: `loading: true` renders 8 skeleton rows (muted rounded blocks matching the column count, no row data). Adds proof that off-screen rows are never built.

- [ ] **Step 1: Write the failing tests**

Append to `test/data_table/nib_data_table_test.dart`:

```dart
testWidgets('loading shows skeleton rows instead of data, hides empty state', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      NibDataTable<_Person>(
        columns: _columns(),
        rows: const [_Person('Ada Lovelace', 'ada@example.com')],
        loading: true,
      ),
    ),
  );
  expect(find.text('Ada Lovelace'), findsNothing);
  expect(find.text('No data'), findsNothing);
  expect(find.byKey(const ValueKey('nib-data-table-skeleton-row')), findsWidgets);
});

testWidgets('virtualizes: a row far outside the viewport is never built', (
  tester,
) async {
  final people = List.generate(
    500,
    (i) => _Person('Person $i', 'p$i@example.com'),
  );
  await tester.pumpWidget(
    _wrap(NibDataTable<_Person>(columns: _columns(), rows: people)),
  );
  // The viewport is 400px tall / 48px rows -> ~8 rows visible. Row 400 is
  // nowhere near the viewport and must not have been built.
  expect(find.text('Person 400'), findsNothing);
  expect(find.text('Person 0'), findsOneWidget);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data_table/nib_data_table_test.dart`
Expected: the loading test FAILS (no skeleton key exists, `Ada Lovelace` is still shown since `loading` isn't branched on). The virtualization test likely already PASSES (SliverFixedExtentList from Task 3 already virtualizes) — if so, that's expected; it's included here as the recorded evidence for the master prompt's virtualization requirement, not a new behavior.

- [ ] **Step 3: Implement the loading skeleton**

Add to `_NibDataTableState<T>` in `lib/src/data_table/nib_data_table.dart`:

```dart
Widget _buildSkeletonRow(NibTheme theme) {
  final blockCount =
      widget.columns.length + (widget.selectionMode == NibDataTableSelectionMode.multi ? 1 : 0);
  return SizedBox(
    key: const ValueKey('nib-data-table-skeleton-row'),
    height: widget.rowHeight,
    child: Row(
      children: [
        for (var i = 0; i < blockCount; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.muted,
                  borderRadius: BorderRadius.circular(theme.radiusSm),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
```

In `build()`, replace the `if (rows.isEmpty) ... else ...` sliver branch with a three-way branch:

```dart
if (widget.loading)
  SliverFixedExtentList.builder(
    itemExtent: widget.rowHeight,
    itemCount: 8,
    itemBuilder: (context, index) => _buildSkeletonRow(theme),
  )
else if (rows.isEmpty)
  SliverFillRemaining(
    hasScrollBody: false,
    child:
        widget.emptyState ??
        Center(
          child: Text(
            'No data',
            style: TextStyle(color: theme.mutedForeground),
          ),
        ),
  )
else
  SliverFixedExtentList.builder(
    itemExtent: widget.rowHeight,
    itemCount: rows.length,
    itemBuilder: (context, index) =>
        _buildRow(context, theme, rows[index], index),
  ),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data_table/nib_data_table_test.dart`
Expected: PASS (12 tests total)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/data_table/nib_data_table.dart test/data_table/nib_data_table_test.dart
git commit -m "feat(data-table): loading skeleton rows, record virtualization evidence"
```

---

### Task 7: animated:bool — NibMotion row entrance + NibShimmer skeleton

**Files:**
- Modify: `lib/src/data_table/nib_data_table.dart`
- Modify: `test/data_table/nib_data_table_test.dart`

**Interfaces:**
- Consumes: `NibMotion`, `NibAnim`, `NibTransition`, `NibShimmer` from `package:nib_motion/nib_motion.dart` (already imported in Task 3).
- Produces: when `animated: true`, each row is wrapped in `NibMotion` (fade + slight upward slide on entrance, keyed by `_keyFor(row)`) and skeleton rows are wrapped in `NibShimmer(enabled: true, ...)`. When `animated: false` (default), no `NibMotion`/`NibShimmer` widgets are built at all.

- [ ] **Step 1: Write the failing tests**

Append to `test/data_table/nib_data_table_test.dart` (add `import 'package:nib_motion/nib_motion.dart';` at the top):

```dart
testWidgets('animated: false builds zero NibMotion widgets', (tester) async {
  await tester.pumpWidget(
    _wrap(
      NibDataTable<_Person>(
        columns: _columns(),
        rows: const [
          _Person('Ada Lovelace', 'ada@example.com'),
          _Person('Alan Turing', 'alan@example.com'),
        ],
      ),
    ),
  );
  expect(find.byType(NibMotion), findsNothing);
});

testWidgets('animated: true wraps each visible row in NibMotion', (
  tester,
) async {
  await tester.pumpWidget(
    _wrap(
      NibDataTable<_Person>(
        columns: _columns(),
        rows: const [
          _Person('Ada Lovelace', 'ada@example.com'),
          _Person('Alan Turing', 'alan@example.com'),
        ],
        animated: true,
      ),
    ),
  );
  expect(find.byType(NibMotion), findsNWidgets(2));
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data_table/nib_data_table_test.dart`
Expected: the `animated: false` test already PASSES (no `NibMotion` used anywhere yet). The `animated: true` test FAILS — `findsNWidgets(2)` finds 0.

- [ ] **Step 3: Implement the animation**

In `lib/src/data_table/nib_data_table.dart`, replace the whole `_buildRow` method (from Task 5) with:

```dart
Widget _buildRow(BuildContext context, NibTheme theme, T row, int index) {
  final selected = _controller.selected.contains(row);
  final cells = Row(
    children: [
      if (widget.selectionMode == NibDataTableSelectionMode.multi)
        SizedBox(
          width: 48,
          child: Checkbox(
            value: selected,
            onChanged: (_) => _toggleRow(row),
          ),
        ),
      for (var i = 0; i < widget.columns.length; i++)
        _sizedCell(
          widget.columns[i],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: DefaultTextStyle.merge(
                style: TextStyle(color: theme.foreground),
                child: widget.columns[i].cellBuilder(context, row),
              ),
            ),
          ),
        ),
    ],
  );

  final content = Container(
    height: widget.rowHeight,
    color: selected ? theme.secondary : null,
    child: cells,
  );

  final tappable = Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: () {
        widget.onRowTap?.call(row);
        if (widget.selectionMode == NibDataTableSelectionMode.single) {
          _toggleRow(row);
        }
      },
      child: content,
    ),
  );

  if (!widget.animated) return tappable;

  return NibMotion(
    key: _keyFor(row),
    initial: const NibAnim(opacity: 0, y: 6),
    animate: const NibAnim(opacity: 1, y: 0),
    transition:
        widget.transition ?? const NibTransition(duration: Duration(milliseconds: 220)),
    child: tappable,
  );
}
```

And wrap the skeleton row content in `NibShimmer` only when animated, in `_buildSkeletonRow`:

```dart
Widget _buildSkeletonRow(NibTheme theme) {
  final blockCount =
      widget.columns.length + (widget.selectionMode == NibDataTableSelectionMode.multi ? 1 : 0);
  final row = SizedBox(
    key: const ValueKey('nib-data-table-skeleton-row'),
    height: widget.rowHeight,
    child: Row(
      children: [
        for (var i = 0; i < blockCount; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.muted,
                  borderRadius: BorderRadius.circular(theme.radiusSm),
                ),
              ),
            ),
          ),
      ],
    ),
  );
  if (!widget.animated) return row;
  return NibShimmer(enabled: true, child: row);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data_table/nib_data_table_test.dart`
Expected: PASS (14 tests total)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/data_table/nib_data_table.dart test/data_table/nib_data_table_test.dart
git commit -m "feat(data-table): route animated:true through NibMotion row entrance + NibShimmer skeleton"
```

---

### Task 8: 3 usage examples + example-app wiring + progress tracker

**Files:**
- Create: `example/lib/examples/data_table_examples.dart`
- Modify: `example/lib/catalog.dart`
- Modify: `NIB_COMPONENTS_PROGRESS.md`

**Interfaces:**
- Consumes: `NibDataTable`, `NibDataColumn`, `NibDataTableSelectionMode`, `NibDataTableController`, `NibSortDirection` (Tasks 1–7); `CatalogEntry` (existing, `example/lib/catalog.dart`).
- Produces: `nibCatalog` gains one `CatalogEntry(name: 'Data Table', builder: ...)`. No new public library API.

- [ ] **Step 1: Write the three usage examples**

```dart
// example/lib/examples/data_table_examples.dart
import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

class _Employee {
  const _Employee(this.name, this.role, this.email);
  final String name;
  final String role;
  final String email;
}

const _employees = [
  _Employee('Ada Lovelace', 'Engineer', 'ada@nib.dev'),
  _Employee('Alan Turing', 'Engineer', 'alan@nib.dev'),
  _Employee('Grace Hopper', 'Manager', 'grace@nib.dev'),
  _Employee('Margaret Hamilton', 'Manager', 'margaret@nib.dev'),
  _Employee('Katherine Johnson', 'Analyst', 'katherine@nib.dev'),
];

/// 1. Minimal/default usage — just columns + rows.
class DataTableMinimalExample extends StatelessWidget {
  const DataTableMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: NibDataTable<_Employee>(
        columns: [
          NibDataColumn(
            label: 'Name',
            cellBuilder: (context, row) => Text(row.name),
          ),
          NibDataColumn(
            label: 'Role',
            cellBuilder: (context, row) => Text(row.role),
          ),
        ],
        rows: _employees,
      ),
    );
  }
}

/// 2. Common variant — sortable columns + single-row selection.
class DataTableSortableSelectableExample extends StatelessWidget {
  const DataTableSortableSelectableExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: NibDataTable<_Employee>(
        columns: [
          NibDataColumn(
            label: 'Name',
            cellBuilder: (context, row) => Text(row.name),
            sortValue: (row) => row.name,
          ),
          NibDataColumn(
            label: 'Role',
            cellBuilder: (context, row) => Text(row.role),
            sortValue: (row) => row.role,
          ),
        ],
        rows: _employees,
        selectionMode: NibDataTableSelectionMode.single,
      ),
    );
  }
}

/// 3. Advanced — multi-select with an external controller, animated row
/// entrance, and a loading toggle.
class DataTableAdvancedExample extends StatefulWidget {
  const DataTableAdvancedExample({super.key});

  @override
  State<DataTableAdvancedExample> createState() => _DataTableAdvancedExampleState();
}

class _DataTableAdvancedExampleState extends State<DataTableAdvancedExample> {
  final _controller = NibDataTableController<_Employee>();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          title: const Text('Loading'),
          value: _loading,
          onChanged: (value) => setState(() => _loading = value),
        ),
        SizedBox(
          height: 320,
          child: NibDataTable<_Employee>(
            columns: [
              NibDataColumn(
                label: 'Name',
                cellBuilder: (context, row) => Text(row.name),
                sortValue: (row) => row.name,
              ),
              NibDataColumn(
                label: 'Role',
                cellBuilder: (context, row) => Text(row.role),
                sortValue: (row) => row.role,
              ),
              NibDataColumn(
                label: 'Email',
                cellBuilder: (context, row) => Text(row.email),
              ),
            ],
            rows: _employees,
            selectionMode: NibDataTableSelectionMode.multi,
            controller: _controller,
            loading: _loading,
            animated: true,
            onSelectionChanged: (selection) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${selection.length} selected'),
                  duration: const Duration(milliseconds: 600),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Register the examples in the catalog**

Read `example/lib/catalog.dart` first (it currently has an empty `nibCatalog` list), then replace it with:

```dart
// example/lib/catalog.dart
import 'package:flutter/widgets.dart';

import 'examples/data_table_examples.dart';

/// One entry in the component catalog shown by the example app.
class CatalogEntry {
  const CatalogEntry({required this.name, required this.builder});

  final String name;
  final WidgetBuilder builder;
}

/// Every built component's demo page, in build order (Tier A -> Tier C).
///
/// Add one entry here as each component in NIB_COMPONENTS_MASTER_PROMPT.md
/// section 3 lands.
final List<CatalogEntry> nibCatalog = <CatalogEntry>[
  CatalogEntry(
    name: 'Data Table — minimal',
    builder: (context) => const DataTableMinimalExample(),
  ),
  CatalogEntry(
    name: 'Data Table — sortable + selectable',
    builder: (context) => const DataTableSortableSelectableExample(),
  ),
  CatalogEntry(
    name: 'Data Table — advanced',
    builder: (context) => const DataTableAdvancedExample(),
  ),
];
```

- [ ] **Step 3: Verify the example app builds and analyzes clean**

Run: `cd example && flutter analyze && flutter build linux --debug`
Expected: `No issues found!`, `✓ Built build/linux/x64/debug/bundle/nib_components_example`

- [ ] **Step 4: Update the progress tracker**

In `NIB_COMPONENTS_PROGRESS.md`, change the Data Table row from:

```
| 1 | Data Table | not started | |
```

to:

```
| 1 | Data Table | built — awaiting visual confirm | 2026-07-10 |
```

- [ ] **Step 5: Run the full test suite one last time**

Run: `flutter test`
Expected: PASS (14 tests)

- [ ] **Step 6: Commit**

```bash
git add example/lib/examples example/lib/catalog.dart NIB_COMPONENTS_PROGRESS.md
git commit -m "feat(data-table): add 3 usage examples, wire into example app catalog"
```

- [ ] **Step 7: Hand off for visual confirmation**

Do not proceed to the next component (Navigation Menu, Tier A #2) until the user has run/reloaded `example/` (`flutter run -d linux`, already running per the earlier session setup — hit `r` to hot reload) and confirmed all three Data Table examples look and behave correctly. On confirmation, update `NIB_COMPONENTS_PROGRESS.md`'s Data Table row status to `verified` with today's date and commit that alone before starting Navigation Menu.

---

## Known gaps vs. master prompt section 5.1 (deliberate deviations, not silent drops)

- **Pagination hook** ("works with the Nib Pagination component but not required") — Pagination is Tier B #20 and doesn't exist yet in this build order, so there is nothing to hook up to. Deferred until Pagination lands; `NibDataTable`'s `rows: List<T>` is already page-slice-friendly (caller can pass just the current page) so no rework is expected then.
- **Sticky first column while horizontally scrolled** — Task 9 adds plain horizontal scrolling (the actual user-facing need: columns that don't fit a narrow/mobile viewport are reachable by scrolling instead of being crushed below `minWidth`), but does not pin a first column in place during that scroll. True column-pinning during horizontal scroll needs a synchronized second scroll region — comparable in complexity to Resizable Panels (Tier A #3) — and stays deferred to a follow-up task. Raise before starting Navigation Menu if this turns out to be load-bearing sooner than expected.

---

### Task 9: Responsive horizontal scroll for narrow viewports

**Added 2026-07-10** after user feedback during Task 8 review: the table had no fallback when a viewport (e.g. a phone-width screen) is narrower than the sum of the columns' widths — columns were only ever flexed/compressed via `Expanded`+`ConstrainedBox(minWidth:...)`, which on a narrow enough viewport produces a contradictory `BoxConstraints` (the Flex-allotted width is tighter than the column's own `minWidth`) and either overflows or throws. This also promotes master prompt section 1.7 (new standing rule: every component must be responsive — mobile/tablet/desktop/web — added to `NIB_COMPONENTS_MASTER_PROMPT.md` in the same sitting) from a future-looking rule into something Data Table itself must satisfy before being considered done.

**Files:**
- Modify: `lib/src/data_table/nib_data_table.dart`
- Modify: `test/data_table/nib_data_table_test.dart`

**Interfaces:**
- No public API changes — `NibDataTable<T>`'s constructor is unchanged. This task changes only internal layout: a `LayoutBuilder` now wraps `build()`'s output, and `_sizedCell`/`_buildHeaderRow`/`_buildRow`/`_buildSkeletonRow` each gain a `fixedWidth`/`needsHorizontalScroll` bool parameter threaded from that `LayoutBuilder`.

- [ ] **Step 1: Write the failing tests**

Append to `test/data_table/nib_data_table_test.dart`:

```dart
testWidgets('wide viewport: renders without horizontal scroll, no overflow', (
  tester,
) async {
  final columns = [
    for (final label in ['A', 'B', 'C', 'D'])
      NibDataColumn<_Person>(
        label: label,
        cellBuilder: (context, row) => Text(row.name),
        minWidth: 100,
      ),
  ];
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: const [NibTheme.light]),
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 400,
          child: NibDataTable<_Person>(
            columns: columns,
            rows: const [_Person('Ada Lovelace', 'ada@example.com')],
          ),
        ),
      ),
    ),
  );
  expect(find.byType(SingleChildScrollView), findsNothing);
  expect(tester.takeException(), isNull);
});

testWidgets(
  'narrow viewport: wraps in horizontal scroll, all columns still present, no overflow',
  (tester) async {
    final columns = [
      for (final label in ['A', 'B', 'C', 'D'])
        NibDataColumn<_Person>(
          label: label,
          cellBuilder: (context, row) => Text(row.name),
          minWidth: 100,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [NibTheme.light]),
        home: Scaffold(
          body: SizedBox(
            width: 150,
            height: 400,
            child: NibDataTable<_Person>(
              columns: columns,
              rows: const [_Person('Ada Lovelace', 'ada@example.com')],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(tester.takeException(), isNull);
  },
);
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data_table/nib_data_table_test.dart`
Expected: the wide-viewport test PASSES already (nothing changed yet, no `SingleChildScrollView` exists anywhere, so `findsNothing` trivially holds). The narrow-viewport test FAILS — `find.byType(SingleChildScrollView)` finds nothing (`findsOneWidget` fails), and depending on Flutter's exact constraint-violation behavior at this viewport size, `tester.takeException()` may also be non-null (a `BoxConstraints` assertion from the `Expanded`+`ConstrainedBox(minWidth: 100)` combination being squeezed into ~37px each across 4 columns in a 150px-wide `Row`). Either failure mode confirms the pre-fix bug.

- [ ] **Step 3: Implement responsive horizontal scroll**

In `lib/src/data_table/nib_data_table.dart`, add this getter to `_NibDataTableState<T>` (near `_displayedRows`):

```dart
double get _intrinsicColumnsWidth {
  var total = widget.selectionMode == NibDataTableSelectionMode.multi ? 48.0 : 0.0;
  for (final column in widget.columns) {
    total += column.width ?? column.minWidth;
  }
  return total;
}
```

Replace `_sizedCell` with:

```dart
Widget _sizedCell(NibDataColumn<T> column, Widget child, {required bool fixedWidth}) {
  if (column.width != null) {
    return SizedBox(width: column.width, child: child);
  }
  if (fixedWidth) {
    return SizedBox(width: column.minWidth, child: child);
  }
  return Expanded(
    child: ConstrainedBox(
      constraints: BoxConstraints(minWidth: column.minWidth),
      child: child,
    ),
  );
}
```

Replace `_buildHeaderRow`'s signature and its `_sizedCell` call:

```dart
Widget _buildHeaderRow(
  BuildContext context,
  NibTheme theme,
  List<T> rows,
  bool fixedWidth,
) {
  final sort = _controller.sort;
  final selected = _controller.selected;
  final allSelected = rows.isNotEmpty && rows.every(selected.contains);
  final someSelected = rows.any(selected.contains);

  return DecoratedBox(
    decoration: BoxDecoration(
      color: theme.card,
      border: Border(bottom: BorderSide(color: theme.border)),
    ),
    child: SizedBox(
      height: widget.headerHeight,
      child: Row(
        children: [
          if (widget.selectionMode == NibDataTableSelectionMode.multi)
            SizedBox(
              width: 48,
              child: Checkbox(
                value: allSelected ? true : (someSelected ? null : false),
                tristate: true,
                onChanged: (_) => _toggleSelectAll(rows, !allSelected),
              ),
            ),
          for (var i = 0; i < widget.columns.length; i++)
            _sizedCell(
              widget.columns[i],
              _buildHeaderCell(theme, i, sort),
              fixedWidth: fixedWidth,
            ),
        ],
      ),
    ),
  );
}
```

Replace `_buildRow`'s signature and its `_sizedCell` call (the rest of the method — `content`/`tappable`/`NibMotion` wrap — is unchanged from Task 7, keep it exactly as-is below the shown part):

```dart
Widget _buildRow(
  BuildContext context,
  NibTheme theme,
  T row,
  int index,
  bool fixedWidth,
) {
  final selected = _controller.selected.contains(row);
  final cells = Row(
    children: [
      if (widget.selectionMode == NibDataTableSelectionMode.multi)
        SizedBox(
          width: 48,
          child: Checkbox(
            value: selected,
            onChanged: (_) => _toggleRow(row),
          ),
        ),
      for (var i = 0; i < widget.columns.length; i++)
        _sizedCell(
          widget.columns[i],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: DefaultTextStyle.merge(
                style: TextStyle(color: theme.foreground),
                child: widget.columns[i].cellBuilder(context, row),
              ),
            ),
          ),
          fixedWidth: fixedWidth,
        ),
    ],
  );

  final content = Container(
    height: widget.rowHeight,
    color: selected ? theme.secondary : null,
    child: cells,
  );

  final tappable = Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: () {
        widget.onRowTap?.call(row);
        if (widget.selectionMode == NibDataTableSelectionMode.single) {
          _toggleRow(row);
        }
      },
      child: content,
    ),
  );

  if (!widget.animated) return tappable;

  return NibMotion(
    key: _keyFor(row),
    initial: const NibAnim(opacity: 0, y: 6),
    animate: const NibAnim(opacity: 1, y: 0),
    transition:
        widget.transition ?? const NibTransition(duration: Duration(milliseconds: 220)),
    child: tappable,
  );
}
```

Replace `_buildSkeletonRow`:

```dart
Widget _buildSkeletonRow(NibTheme theme, bool fixedWidth) {
  final blockCount =
      widget.columns.length + (widget.selectionMode == NibDataTableSelectionMode.multi ? 1 : 0);
  final block = Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: theme.muted,
        borderRadius: BorderRadius.circular(theme.radiusSm),
      ),
    ),
  );
  final blockWidth = fixedWidth ? _intrinsicColumnsWidth / blockCount : null;
  final row = SizedBox(
    key: const ValueKey('nib-data-table-skeleton-row'),
    height: widget.rowHeight,
    child: Row(
      children: [
        for (var i = 0; i < blockCount; i++)
          blockWidth != null
              ? SizedBox(width: blockWidth, child: block)
              : Expanded(child: block),
      ],
    ),
  );
  if (!widget.animated) return row;
  return NibShimmer(enabled: true, child: row);
}
```

Replace `build()`:

```dart
@override
Widget build(BuildContext context) {
  final theme = NibTheme.of(context);
  final rows = _displayedRows;

  return LayoutBuilder(
    builder: (context, constraints) {
      final needsHorizontalScroll = constraints.maxWidth < _intrinsicColumnsWidth;

      final table = Semantics(
        label: widget.semanticLabel,
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.border),
            borderRadius: BorderRadius.circular(theme.radiusDefault),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(theme.radiusDefault),
            child: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: widget.stickyHeader,
                  delegate: _NibDataTableHeaderDelegate(
                    height: widget.headerHeight,
                    child: _buildHeaderRow(context, theme, rows, needsHorizontalScroll),
                  ),
                ),
                if (widget.loading)
                  SliverFixedExtentList.builder(
                    itemExtent: widget.rowHeight,
                    itemCount: 8,
                    itemBuilder: (context, index) =>
                        _buildSkeletonRow(theme, needsHorizontalScroll),
                  )
                else if (rows.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child:
                        widget.emptyState ??
                        Center(
                          child: Text(
                            'No data',
                            style: TextStyle(color: theme.mutedForeground),
                          ),
                        ),
                  )
                else
                  SliverFixedExtentList.builder(
                    itemExtent: widget.rowHeight,
                    itemCount: rows.length,
                    itemBuilder: (context, index) =>
                        _buildRow(context, theme, rows[index], index, needsHorizontalScroll),
                  ),
              ],
            ),
          ),
        ),
      );

      if (!needsHorizontalScroll) return table;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: _intrinsicColumnsWidth, child: table),
      );
    },
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data_table/nib_data_table_test.dart`
Expected: PASS (16 tests total). Also re-run the full suite to confirm zero regressions in the 12 pre-existing data-table tests, which all use narrow (1-2 column) tables well under any default test-viewport width and so should still hit the `needsHorizontalScroll == false` path unchanged.

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, analyzer clean of anything new (the `invalid_dependency`/`prefer_initializing_formals` pre-existing items are still fine).

- [ ] **Step 6: Update NIB_COMPONENTS_PROGRESS.md and commit**

Leave the Data Table row as `built — awaiting visual confirm` (unchanged — still gated on the user's own check in `example/`, per Task 8 Step 7; this task doesn't close that gate, it fixes a defect found before that check completed).

```bash
git add lib/src/data_table/nib_data_table.dart test/data_table/nib_data_table_test.dart
git commit -m "feat(data-table): scroll horizontally on viewports narrower than total column width"
```

- [ ] **Step 7: Hand off for visual confirmation (unchanged from Task 8 Step 7)**

Still waiting on the user's own check in the running `example/` app — this task doesn't change that gate, it fixes a defect found before that check completed. Suggest the user specifically try narrowing the OS window (or resizing if the Linux desktop window supports it) to confirm the horizontal scroll behaves as expected on the Advanced example (3 columns) and doesn't look broken.

## Evidence checklist (master prompt section 1.6)

- [ ] Widget tests covering: default render (Task 3), each selection mode (Task 5), `loading` state (Task 6), sort behavior (Task 4), `animated: true` vs `animated: false` (Task 7). Keyboard interaction is intentionally **not yet covered** — `NibDataTable` doesn't yet have arrow-key row navigation or `Enter`/`Space` row activation; flag this as a known gap if not added in a follow-up task before calling the component fully done against section 1.1's accessibility bar.
- [ ] Manual verification note (this component touches virtualization/scrolling, which section 1.6 calls out): after the user visually confirms in `example/`, record one sentence here on what was checked (e.g., "scrolled 500-row example, header stayed pinned, no jank").
- [ ] Test run output pasted into the handoff message when reporting completion — not just "tests added."
