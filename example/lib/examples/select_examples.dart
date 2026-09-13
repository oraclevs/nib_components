import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

const _fruits = [
  NibSelectOption(value: 'apple', label: 'Apple'),
  NibSelectOption(value: 'banana', label: 'Banana'),
  NibSelectOption(value: 'cherry', label: 'Cherry'),
  NibSelectOption(value: 'date', label: 'Date', disabled: true),
  NibSelectOption(value: 'elderberry', label: 'Elderberry'),
  NibSelectOption(value: 'fig', label: 'Fig'),
  NibSelectOption(value: 'grape', label: 'Grape'),
];

const _countryGroups = [
  NibSelectGroup(
    label: 'Europe',
    options: [
      NibSelectOption(value: 'fr', label: 'France'),
      NibSelectOption(value: 'de', label: 'Germany'),
      NibSelectOption(value: 'es', label: 'Spain'),
      NibSelectOption(value: 'it', label: 'Italy'),
    ],
  ),
  NibSelectGroup(
    label: 'Asia',
    options: [
      NibSelectOption(value: 'jp', label: 'Japan'),
      NibSelectOption(value: 'kr', label: 'South Korea'),
      NibSelectOption(value: 'in', label: 'India'),
    ],
  ),
  NibSelectGroup(
    label: 'Americas',
    options: [
      NibSelectOption(value: 'us', label: 'United States'),
      NibSelectOption(value: 'ca', label: 'Canada'),
      NibSelectOption(value: 'br', label: 'Brazil'),
    ],
  ),
];

const _permissions = [
  NibSelectOption(value: 'read', label: 'Read', subtitle: 'View content'),
  NibSelectOption(value: 'write', label: 'Write', subtitle: 'Create and edit'),
  NibSelectOption(value: 'delete', label: 'Delete', subtitle: 'Remove content'),
  NibSelectOption(value: 'admin', label: 'Admin', subtitle: 'Full control'),
];

/// 1. Minimal/default — single-select over a flat option list (one option
/// disabled), reporting the pick in a snackbar.
class SelectMinimalExample extends StatelessWidget {
  const SelectMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Favourite fruit'),
        const SizedBox(height: 8),
        SizedBox(
          width: 300,
          child: NibSelect<String>(
            options: _fruits,
            placeholder: 'Choose a fruit…',
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

/// 2. Common variant — grouped options with an in-list search field and a
/// clearable trigger.
class SelectSearchableGroupedExample extends StatelessWidget {
  const SelectSearchableGroupedExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Country (grouped, searchable)'),
        const SizedBox(height: 8),
        SizedBox(
          width: 320,
          child: NibSelect<String>(
            groups: _countryGroups,
            searchable: true,
            clearable: true,
            placeholder: 'Select a country…',
            searchPlaceholder: 'Search countries…',
            onChanged: (value) => debugPrint('country: $value'),
          ),
        ),
      ],
    );
  }
}

/// 3. Advanced — multi-select (joined labels in the trigger), opt-in
/// animation, and an external controller driving a "Select all" / "Clear"
/// pair plus a live read-out of the current selection.
class SelectMultiAdvancedExample extends StatefulWidget {
  const SelectMultiAdvancedExample({super.key});

  @override
  State<SelectMultiAdvancedExample> createState() =>
      _SelectMultiAdvancedExampleState();
}

class _SelectMultiAdvancedExampleState
    extends State<SelectMultiAdvancedExample> {
  final _controller = NibSelectController<String>();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

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
        const Text('Permissions (multi-select, animated, controller)'),
        const SizedBox(height: 8),
        SizedBox(
          width: 360,
          child: NibSelect<String>(
            controller: _controller,
            options: _permissions,
            multiSelect: true,
            searchable: true,
            clearable: true,
            animated: true,
            // Cascade each option row in via nib_motion's stagger.
            staggerOptions: true,
            animation: NibSelectAnimation.slideFade,
            placeholder: 'Grant permissions…',
            onSelectionChanged: (values) => debugPrint('permissions: $values'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.tonal(
              onPressed: () => _controller.setSelection(
                _permissions.map((o) => o.value).toList(),
              ),
              child: const Text('Select all'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _controller.clear,
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _controller.selectedValues.isEmpty
              ? 'Nothing selected'
              : 'Granted: ${_controller.selectedValues.join(', ')}',
        ),
      ],
    );
  }
}

/// 4. Animation gallery — a `NibSelect` (dogfooded as the picker) chooses the
/// entrance/exit preset, a switch toggles the per-row cascade, and a target
/// select below plays it. Open/close the target to feel each preset.
class SelectAnimationGalleryExample extends StatefulWidget {
  const SelectAnimationGalleryExample({super.key});

  @override
  State<SelectAnimationGalleryExample> createState() =>
      _SelectAnimationGalleryExampleState();
}

class _SelectAnimationGalleryExampleState
    extends State<SelectAnimationGalleryExample> {
  NibSelectAnimation _animation = NibSelectAnimation.fadeScale;
  bool _stagger = false;

  static const _presetOptions = [
    NibSelectOption(value: NibSelectAnimation.none, label: 'none'),
    NibSelectOption(value: NibSelectAnimation.fade, label: 'fade'),
    NibSelectOption(value: NibSelectAnimation.slide, label: 'slide'),
    NibSelectOption(value: NibSelectAnimation.scale, label: 'scale'),
    NibSelectOption(value: NibSelectAnimation.fadeScale, label: 'fadeScale'),
    NibSelectOption(value: NibSelectAnimation.slideFade, label: 'slideFade'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Animation preset'),
        const SizedBox(height: 8),
        SizedBox(
          width: 260,
          child: NibSelect<NibSelectAnimation>(
            value: _animation,
            options: _presetOptions,
            onChanged: (v) =>
                setState(() => _animation = v ?? NibSelectAnimation.fadeScale),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: _stagger,
              onChanged: (v) => setState(() => _stagger = v),
            ),
            const Text('Stagger option rows'),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Target — open it to see the preset'),
        const SizedBox(height: 8),
        SizedBox(
          width: 300,
          // Re-key on the settings so a fresh state picks up the new preset
          // even mid-interaction.
          child: NibSelect<String>(
            key: ValueKey('$_animation-$_stagger'),
            options: _fruits,
            animated: true,
            animation: _animation,
            staggerOptions: _stagger,
            placeholder: 'Open me…',
            onChanged: (value) => debugPrint('gallery: $value'),
          ),
        ),
      ],
    );
  }
}

/// 5. Behaviour demo — a select pinned to the bottom of the viewport so its
/// dropdown must flip open *upward* and clamp its height (the overlay
/// positioning this component must get right, per the spec).
class SelectOpensUpwardExample extends StatelessWidget {
  const SelectOpensUpwardExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pinned to the bottom — the dropdown opens upward.'),
        const Spacer(),
        SizedBox(
          width: 300,
          child: NibSelect<String>(
            options: _fruits,
            placeholder: 'Opens upward…',
            onChanged: (value) => debugPrint('bottom select: $value'),
          ),
        ),
      ],
    );
  }
}

/// 6. Colors — backgroundColor/borderColor/placeholderStyle escape hatches.
class SelectColorsExample extends StatelessWidget {
  const SelectColorsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Colors — backgroundColor/borderColor/placeholderStyle'),
        const SizedBox(height: 8),
        SizedBox(
          width: 300,
          child: NibSelect<String>(
            options: _fruits,
            placeholder: 'Choose a fruit…',
            backgroundColor: const Color(0xFFF3E8FF),
            borderColor: const Color(0xFF7C3AED),
            placeholderStyle: const TextStyle(
              color: Color(0xFF7C3AED),
              fontWeight: FontWeight.w600,
            ),
            onChanged: (value) => debugPrint('colored select: $value'),
          ),
        ),
      ],
    );
  }
}
