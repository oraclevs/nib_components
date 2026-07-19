import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

const _fruits = [
  NibComboboxOption(
    value: 'apple',
    label: 'Apple',
    subtitle: 'Crisp and sweet',
  ),
  NibComboboxOption(value: 'banana', label: 'Banana'),
  NibComboboxOption(
    value: 'cherry',
    label: 'Cherry',
    subtitle: 'Small and red',
  ),
  NibComboboxOption(value: 'date', label: 'Date'),
  NibComboboxOption(value: 'elderberry', label: 'Elderberry'),
  NibComboboxOption(value: 'fig', label: 'Fig'),
  NibComboboxOption(value: 'grape', label: 'Grape'),
];

/// A big list the async demo pretends to fetch from a server.
const _countries = [
  'Argentina',
  'Australia',
  'Austria',
  'Belgium',
  'Brazil',
  'Canada',
  'Chile',
  'China',
  'Denmark',
  'Egypt',
  'Finland',
  'France',
  'Germany',
  'Greece',
  'India',
  'Indonesia',
  'Ireland',
  'Italy',
  'Japan',
  'Kenya',
  'Mexico',
  'Netherlands',
  'Norway',
  'Peru',
  'Poland',
  'Portugal',
  'Spain',
  'Sweden',
  'Switzerland',
  'Thailand',
  'Turkey',
  'Ukraine',
  'United Kingdom',
  'United States',
  'Vietnam',
];

/// 1. Minimal/default — single-select over a static option list, showing a
/// selected value in a snackbar.
class ComboboxMinimalExample extends StatelessWidget {
  const ComboboxMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Pick a fruit'),
        const SizedBox(height: 8),
        SizedBox(
          width: 320,
          child: NibCombobox<String>(
            options: _fruits,
            placeholder: 'Search fruit…',
            onChanged: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Selected: $value'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 2. Common variant — multi-select with chips, backed by a debounced async
/// loader that simulates a network round-trip (loading spinner shown inside
/// the dropdown).
class ComboboxMultiSelectAsyncExample extends StatelessWidget {
  const ComboboxMultiSelectAsyncExample({super.key});

  Future<List<NibComboboxOption<String>>> _load(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final q = query.toLowerCase();
    return [
      for (final c in _countries)
        if (q.isEmpty || c.toLowerCase().contains(q))
          NibComboboxOption(value: c, label: c),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Countries you have visited (async, multi-select)'),
        const SizedBox(height: 8),
        SizedBox(
          width: 360,
          child: NibCombobox<String>(
            multiSelect: true,
            placeholder: 'Type to search countries…',
            asyncOptionsLoader: _load,
            onSelectionChanged: (values) => debugPrint('visited: $values'),
          ),
        ),
      ],
    );
  }
}

/// 3. Advanced — free-text entry, opt-in animation, a custom "no results"
/// slot, and an external controller driving a "Clear" button.
class ComboboxAdvancedExample extends StatefulWidget {
  const ComboboxAdvancedExample({super.key});

  @override
  State<ComboboxAdvancedExample> createState() =>
      _ComboboxAdvancedExampleState();
}

class _ComboboxAdvancedExampleState extends State<ComboboxAdvancedExample> {
  final _controller = NibComboboxController<String>();
  String? _committed;

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
        const Text('Tag (pick one or type your own — free text, animated)'),
        const SizedBox(height: 8),
        SizedBox(
          width: 340,
          child: NibCombobox<String>(
            controller: _controller,
            options: _fruits,
            allowFreeText: true,
            animated: true,
            placeholder: 'Choose or type a tag…',
            onChanged: (v) => setState(() => _committed = v),
            onFreeTextSubmitted: (text) =>
                setState(() => _committed = '"$text" (custom)'),
            noResultsBuilder: (context) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No preset match — press Enter to use what you typed.',
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              onPressed: _controller.clear,
              child: const Text('Clear'),
            ),
            const SizedBox(width: 12),
            Text(
              _committed == null
                  ? 'Nothing committed yet'
                  : 'Committed: $_committed',
            ),
          ],
        ),
      ],
    );
  }
}
