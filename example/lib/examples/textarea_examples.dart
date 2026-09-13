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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Counter — maxLength 140, grows from 2 to 6 lines then scrolls',
        ),
        const SizedBox(height: 16),
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
  State<TextareaAdvancedExample> createState() =>
      _TextareaAdvancedExampleState();
}

class _TextareaAdvancedExampleState extends State<TextareaAdvancedExample> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Advanced — predefined validator, animated, custom radius/padding',
        ),
        const SizedBox(height: 16),
        NibTextarea(
          label: 'Feedback',
          placeholder: 'What could be better?',
          animated: true,
          validator: NibValidators.required('Feedback is required.'),
          helperText: 'Shown while there is no error.',
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.all(16),
        ),
      ],
    );
  }
}

/// 4. Colors — backgroundColor/borderColor/hintStyle escape hatches.
class TextareaColorsExample extends StatelessWidget {
  const TextareaColorsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Colors — backgroundColor/borderColor/hintStyle'),
        const SizedBox(height: 16),
        NibTextarea(
          label: 'Bio',
          placeholder: 'Tell us about yourself…',
          backgroundColor: const Color(0xFFF3E8FF),
          borderColor: const Color(0xFF7C3AED),
          hintStyle: const TextStyle(
            color: Color(0xFF7C3AED),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
