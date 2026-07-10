import 'package:flutter/widgets.dart';

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
final List<CatalogEntry> nibCatalog = <CatalogEntry>[];
