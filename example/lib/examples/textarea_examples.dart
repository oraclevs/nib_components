import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal — label + placeholder, defaults (minLines: 3, unbounded grow).
class TextareaMinimalExample extends StatefulWidget {
  const TextareaMinimalExample({super.key});

  @override
  State<TextareaMinimalExample> createState() => _TextareaMinimalExampleState();
}

class _TextareaMinimalExampleState extends State<TextareaMinimalExample> {
  String _value = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Minimal — ${_value.length} chars typed'),
        const SizedBox(height: 16),
        NibTextarea(
          label: 'Bio',
          placeholder: 'Tell us about yourself…',
          onChanged: (v) => setState(() => _value = v),
        ),
      ],
    );
  }
}

/// 2. Common variant — maxLength + counter, min/max line bounds, helper text.
class TextareaCounterExample extends StatefulWidget {
  const TextareaCounterExample({super.key});

  @override
  State<TextareaCounterExample> createState() => _TextareaCounterExampleState();
}

class _TextareaCounterExampleState extends State<TextareaCounterExample> {
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Counter — maxLength 140, grows from 2 to 6 lines then scrolls'),
        SizedBox(height: 16),
        NibTextarea(
          label: 'Tweet',
          placeholder: "What's happening?",
          minLines: 2,
          maxLines: 6,
          maxLength: 140,
          showCounter: true,
          helperText: 'Keep it punchy.',
        ),
      ],
    );
  }
}

/// 3. Advanced — validation error (animated helper/error swap), custom shape.
class TextareaAdvancedExample extends StatefulWidget {
  const TextareaAdvancedExample({super.key});

  @override
  State<TextareaAdvancedExample> createState() => _TextareaAdvancedExampleState();
}

class _TextareaAdvancedExampleState extends State<TextareaAdvancedExample> {
  String _value = '';
  bool _submitted = false;

  bool get _hasError => _submitted && _value.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Advanced — animated validation, custom radius/padding'),
        const SizedBox(height: 16),
        NibTextarea(
          label: 'Feedback',
          placeholder: 'What could be better?',
          animated: true,
          errorText: _hasError ? 'Feedback is required' : null,
          helperText: 'Shown when there is no error.',
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.all(16),
          onChanged: (v) => setState(() => _value = v),
        ),
        const SizedBox(height: 12),
        NibButton(
          label: 'Submit',
          onPressed: () => setState(() => _submitted = true),
        ),
      ],
    );
  }
}
