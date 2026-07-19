import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

import 'catalog.dart';

void main() {
  runApp(const NibComponentsExampleApp());
}

class NibComponentsExampleApp extends StatelessWidget {
  const NibComponentsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nib_components',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF02569B),
        extensions: const [NibTheme.light],
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF54C5F8),
        brightness: Brightness.dark,
        extensions: const [NibTheme.dark],
      ),
      // Enables context-free showNibToast(...) anywhere in the app.
      builder: (context, child) => NibToaster(child: child!),
      home: const CatalogHomePage(),
    );
  }
}

class CatalogHomePage extends StatefulWidget {
  const CatalogHomePage({super.key});

  @override
  State<CatalogHomePage> createState() => _CatalogHomePageState();
}

class _CatalogHomePageState extends State<CatalogHomePage> {
  int _selectedIndex = 0;

  // Matches Material's standard compact/medium window-size-class boundary.
  static const _compactBreakpoint = 600.0;

  // Fixed row height so we can jump straight to any index without the item
  // needing to already be built (a plain builder list can't `ensureVisible` an
  // off-screen row). Titles are single-line + ellipsis to honour it.
  static const _tileExtent = 56.0;

  final _listController = ScrollController();

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  /// Scrolls the catalog list so the currently-selected entry sits centred in
  /// the viewport — used when the drawer (re)opens, so the last thing you tapped
  /// is right there instead of scrolled off the bottom of a growing list.
  void _scrollToSelected() {
    if (!_listController.hasClients) return;
    final position = _listController.position;
    final centred =
        (_selectedIndex * _tileExtent) -
        (position.viewportDimension - _tileExtent) / 2;
    _listController.jumpTo(
      centred.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  Widget _buildCatalogList({required bool closeDrawerOnTap}) {
    // The drawer is rebuilt each time it opens; centre on the selected row as
    // soon as it's laid out so it's already in view when the drawer appears.
    if (closeDrawerOnTap) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
    return ListView.builder(
      controller: _listController,
      itemExtent: _tileExtent,
      itemCount: nibCatalog.length,
      itemBuilder: (itemContext, index) {
        final entry = nibCatalog[index];
        return ListTile(
          title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          selected: index == _selectedIndex,
          onTap: () {
            setState(() => _selectedIndex = index);
            if (closeDrawerOnTap) Navigator.of(itemContext).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (nibCatalog.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No components built yet.')),
      );
    }

    final selected = nibCatalog[_selectedIndex];
    final content = Padding(
      padding: const EdgeInsets.all(24),
      child: Builder(builder: selected.builder),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;

        if (!compact) {
          return Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: _buildCatalogList(closeDrawerOnTap: false),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(selected.name)),
          drawer: Drawer(
            child: SafeArea(child: _buildCatalogList(closeDrawerOnTap: true)),
          ),
          body: content,
        );
      },
    );
  }
}
