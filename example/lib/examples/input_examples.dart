import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal — label + placeholder.
class InputMinimalExample extends StatefulWidget {
  const InputMinimalExample({super.key});

  @override
  State<InputMinimalExample> createState() => _InputMinimalExampleState();
}

class _InputMinimalExampleState extends State<InputMinimalExample> {
  String _value = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Minimal — "$_value"'),
        const SizedBox(height: 16),
        NibInput(
          label: 'Name',
          placeholder: 'Ada Lovelace',
          onChanged: (v) => setState(() => _value = v),
        ),
      ],
    );
  }
}

/// 2. Common variant — search field with a leading icon and clearable.
class InputSearchExample extends StatefulWidget {
  const InputSearchExample({super.key});

  @override
  State<InputSearchExample> createState() => _InputSearchExampleState();
}

class _InputSearchExampleState extends State<InputSearchExample> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Search — prefix icon + clearable'),
        const SizedBox(height: 16),
        NibInput(
          placeholder: 'Search components…',
          prefixIcon: const Icon(Icons.search),
          clearable: true,
        ),
      ],
    );
  }
}

/// 3. Advanced — password field, validation error (animated), custom shape.
class InputAdvancedExample extends StatefulWidget {
  const InputAdvancedExample({super.key});

  @override
  State<InputAdvancedExample> createState() => _InputAdvancedExampleState();
}

class _InputAdvancedExampleState extends State<InputAdvancedExample> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Advanced — predefined validator, animated, custom radius'),
        const SizedBox(height: 16),
        NibInput(
          label: 'Password',
          placeholder: 'At least 8 characters',
          obscureText: _obscure,
          keyboardType: TextInputType.visiblePassword,
          animated: true,
          validator: NibValidators.compose([
            NibValidators.required(),
            NibValidators.password(),
          ]),
          helperText: 'Use a mix of upper/lowercase letters and a number.',
          borderRadius: BorderRadius.circular(16),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          ),
        ),
      ],
    );
  }
}
