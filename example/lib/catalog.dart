import 'package:flutter/widgets.dart';

import 'examples/combobox_examples.dart';
import 'examples/command_palette_examples.dart';
import 'examples/data_table_examples.dart';
import 'examples/date_picker_examples.dart';
import 'examples/navigation_menu_examples.dart';
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
];
