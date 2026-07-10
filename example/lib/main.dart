import 'package:flutter/material.dart';

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
      theme: ThemeData(colorSchemeSeed: const Color(0xFF02569B)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF54C5F8),
        brightness: Brightness.dark,
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

  @override
  Widget build(BuildContext context) {
    if (nibCatalog.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No components built yet.')),
      );
    }

    final selected = nibCatalog[_selectedIndex];
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 220,
            child: ListView.builder(
              itemCount: nibCatalog.length,
              itemBuilder: (context, index) {
                final entry = nibCatalog[index];
                return ListTile(
                  title: Text(entry.name),
                  selected: index == _selectedIndex,
                  onTap: () => setState(() => _selectedIndex = index),
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Builder(builder: selected.builder),
            ),
          ),
        ],
      ),
    );
  }
}
