import 'package:flutter/widgets.dart';

import 'examples/bottom_sheet_examples.dart';
import 'examples/combobox_examples.dart';
import 'examples/command_palette_examples.dart';
import 'examples/context_menu_examples.dart';
import 'examples/data_table_examples.dart';
import 'examples/date_picker_examples.dart';
import 'examples/dialog_examples.dart';
import 'examples/hover_card_examples.dart';
import 'examples/liquid_glass_examples.dart';
import 'examples/liquid_glass_lens_test.dart';
import 'examples/liquid_glass_showcase.dart';
import 'examples/music_player.dart';
import 'examples/navigation_menu_examples.dart';
import 'examples/popover_examples.dart';
import 'examples/resizable_panels_examples.dart';
import 'examples/select_examples.dart';

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
    name: '🎵 Music Player (Liquid Glass showcase)',
    builder: (context) => const MusicPlayerExample(),
  ),
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
  CatalogEntry(
    name: 'Data Table — wide (scrolls horizontally)',
    builder: (context) => const DataTableWideExample(),
  ),
  CatalogEntry(
    name: 'Navigation Menu — minimal',
    builder: (context) => const NavigationMenuMinimalExample(),
  ),
  CatalogEntry(
    name: 'Navigation Menu — cascading flyout',
    builder: (context) => const NavigationMenuFlyoutExample(),
  ),
  CatalogEntry(
    name: 'Navigation Menu — advanced (vertical, controller, animated)',
    builder: (context) => const NavigationMenuAdvancedExample(),
  ),
  CatalogEntry(
    name: 'Navigation Menu — overflow (narrow, "More" menu)',
    builder: (context) => const NavigationMenuOverflowExample(),
  ),
  CatalogEntry(
    name: 'Resizable Panels — minimal',
    builder: (context) => const ResizablePanelsMinimalExample(),
  ),
  CatalogEntry(
    name: 'Resizable Panels — IDE layout (3 panels, min sizes)',
    builder: (context) => const ResizablePanelsIdeLayoutExample(),
  ),
  CatalogEntry(
    name: 'Resizable Panels — advanced (nested, controller, animated)',
    builder: (context) => const ResizablePanelsAdvancedExample(),
  ),
  CatalogEntry(
    name: 'Resizable Panels — narrow (scrollable fallback)',
    builder: (context) => const ResizablePanelsNarrowExample(),
  ),
  CatalogEntry(
    name: 'Command Palette — minimal',
    builder: (context) => const CommandPaletteMinimalExample(),
  ),
  CatalogEntry(
    name: 'Command Palette — grouped, icons, trigger button',
    builder: (context) => const CommandPaletteGroupedExample(),
  ),
  CatalogEntry(
    name: 'Command Palette — advanced (nested, custom filter, animated)',
    builder: (context) => const CommandPaletteAdvancedExample(),
  ),
  CatalogEntry(
    name: 'Combobox — minimal (single-select)',
    builder: (context) => const ComboboxMinimalExample(),
  ),
  CatalogEntry(
    name: 'Combobox — multi-select + async loader',
    builder: (context) => const ComboboxMultiSelectAsyncExample(),
  ),
  CatalogEntry(
    name: 'Combobox — advanced (free text, animated, controller)',
    builder: (context) => const ComboboxAdvancedExample(),
  ),
  CatalogEntry(
    name: 'Date Picker — inline (single date)',
    builder: (context) => const DatePickerInlineExample(),
  ),
  CatalogEntry(
    name: 'Date Picker — range popover (min/max bounds)',
    builder: (context) => const DatePickerRangePopoverExample(),
  ),
  CatalogEntry(
    name: 'Date Picker — advanced (multi, dialog, weekends off, animated)',
    builder: (context) => const DatePickerAdvancedExample(),
  ),
  CatalogEntry(
    name: 'Date Picker — custom diamond cells + runtime range',
    builder: (context) => const DatePickerCustomCellExample(),
  ),
  CatalogEntry(
    name: 'Select — minimal (single-select)',
    builder: (context) => const SelectMinimalExample(),
  ),
  CatalogEntry(
    name: 'Select — grouped + searchable',
    builder: (context) => const SelectSearchableGroupedExample(),
  ),
  CatalogEntry(
    name: 'Select — advanced (multi, animated, staggered)',
    builder: (context) => const SelectMultiAdvancedExample(),
  ),
  CatalogEntry(
    name: 'Select — animation gallery (preset picker)',
    builder: (context) => const SelectAnimationGalleryExample(),
  ),
  CatalogEntry(
    name: 'Select — opens upward (bottom-pinned)',
    builder: (context) => const SelectOpensUpwardExample(),
  ),
  CatalogEntry(
    name: 'Dialog — minimal (imperative)',
    builder: (context) => const DialogMinimalExample(),
  ),
  CatalogEntry(
    name: 'Dialog — confirm (returns bool, animated)',
    builder: (context) => const DialogConfirmExample(),
  ),
  CatalogEntry(
    name: 'Dialog — declarative advanced (lg, scroll, custom header)',
    builder: (context) => const DialogDeclarativeAdvancedExample(),
  ),
  CatalogEntry(
    name: 'Dialog — stacked (dialog-from-dialog)',
    builder: (context) => const DialogStackedExample(),
  ),
  CatalogEntry(
    name: 'Dialog — fullscreen (slide-up)',
    builder: (context) => const DialogFullscreenExample(),
  ),
  CatalogEntry(
    name: 'Bottom Sheet — minimal (content-sized)',
    builder: (context) => const BottomSheetMinimalExample(),
  ),
  CatalogEntry(
    name: 'Bottom Sheet — snap points (peek/half/full, animated)',
    builder: (context) => const BottomSheetSnapPointsExample(),
  ),
  CatalogEntry(
    name: 'Bottom Sheet — declarative advanced (controller, spring, snapTo)',
    builder: (context) => const BottomSheetDeclarativeAdvancedExample(),
  ),
  CatalogEntry(
    name: 'Bottom Sheet — non-dismissible (must choose)',
    builder: (context) => const BottomSheetNonDismissibleExample(),
  ),
  CatalogEntry(
    name: 'Popover — minimal (icon + arrow)',
    builder: (context) => const PopoverMinimalExample(),
  ),
  CatalogEntry(
    name: 'Popover — placement end (animated spring)',
    builder: (context) => const PopoverPlacementExample(),
  ),
  CatalogEntry(
    name: 'Popover — advanced (controller, explicit-close, form)',
    builder: (context) => const PopoverAdvancedExample(),
  ),
  CatalogEntry(
    name: 'Popover — as a menu (top placement)',
    builder: (context) => const PopoverMenuExample(),
  ),
  CatalogEntry(
    name: 'Context Menu — minimal (right-click / long-press)',
    builder: (context) => const ContextMenuMinimalExample(),
  ),
  CatalogEntry(
    name: 'Context Menu — submenus, sections, animated',
    builder: (context) => const ContextMenuSubmenuExample(),
  ),
  CatalogEntry(
    name: 'Context Menu — imperative (at tap point)',
    builder: (context) => const ContextMenuImperativeExample(),
  ),
  CatalogEntry(
    name: 'Hover Card — minimal (hover / tap)',
    builder: (context) => const HoverCardMinimalExample(),
  ),
  CatalogEntry(
    name: 'Hover Card — profile preview (top, animated)',
    builder: (context) => const HoverCardProfileExample(),
  ),
  CatalogEntry(
    name: 'Hover Card — advanced (hover-only, spring, live state)',
    builder: (context) => const HoverCardAdvancedExample(),
  ),
  CatalogEntry(
    name: 'Hover Card — touch fallback (tap to toggle)',
    builder: (context) => const HoverCardTapFallbackExample(),
  ),
  CatalogEntry(
    name: 'Liquid Glass — LENS TEST (drag glass over a grid)',
    builder: (context) => const LiquidGlassLensTestExample(),
  ),
  CatalogEntry(
    name: 'Liquid Glass — minimal (over a backdrop)',
    builder: (context) => const LiquidGlassMinimalExample(),
  ),
  CatalogEntry(
    name: 'Liquid Glass — interactive (light follows pointer, press)',
    builder: (context) => const LiquidGlassInteractiveExample(),
  ),
  CatalogEntry(
    name: 'Liquid Glass — advanced (capsule clip, control inside)',
    builder: (context) => const LiquidGlassAdvancedExample(),
  ),
  CatalogEntry(
    name: 'Liquid Glass — FULL SCREEN showcase (+ glass bottom nav)',
    builder: (context) => const LiquidGlassShowcaseExample(),
  ),
];
