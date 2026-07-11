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

  Widget _buildCatalogList({required bool closeDrawerOnTap}) {
    return ListView.builder(
      itemCount: nibCatalog.length,
      itemBuilder: (itemContext, index) {
        final entry = nibCatalog[index];
        return ListTile(
          title: Text(entry.name),
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
                SizedBox(width: 220, child: _buildCatalogList(closeDrawerOnTap: false)),
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
