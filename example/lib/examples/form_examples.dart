import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// A real Flutter [Form] built entirely out of Nib fields — [NibInput] and
/// [NibTextarea] are both [FormField]s, so this is the exact same
/// `Form(key:)` + `formKey.currentState!.validate()`/`.save()`/`.reset()`
/// pattern as a form built out of [TextFormField]s. No Nib-specific
/// plumbing required.
///
/// Submit calls `validate()` (which force-shows every field's error at
/// once, even ones the user never touched — that's Flutter's own `Form`
/// behavior, not something Nib adds) then, only if valid, `save()`, which
/// fires each field's `onSaved` so this widget can collect every value.
class SignUpFormExample extends StatefulWidget {
  const SignUpFormExample({super.key});

  @override
  State<SignUpFormExample> createState() => _SignUpFormExampleState();
}

class _SignUpFormExampleState extends State<SignUpFormExample> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  String? _name;
  String? _email;
  String? _result;

  void _submit() {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      setState(() => _result = null);
      return;
    }
    _formKey.currentState!.save();
    setState(() => _result = 'Welcome, $_name — confirmation sent to $_email.');
  }

  void _reset() {
    _formKey.currentState!.reset();
    setState(() {
      _name = _email = _result = null;
      _obscurePassword = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Sign-up Form — Submit validates every field at once'),
          const SizedBox(height: 16),
          NibInput(
            label: 'Name',
            validator: NibValidators.required(),
            onSaved: (v) => _name = v,
          ),
          const SizedBox(height: 12),
          NibInput(
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            validator: NibValidators.compose(
              [NibValidators.required(), NibValidators.email()],
            ),
            onSaved: (v) => _email = v,
          ),
          const SizedBox(height: 12),
          NibInput(
            label: 'Password',
            obscureText: _obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            helperText: 'At least 8 characters, upper+lowercase, a number.',
            validator: NibValidators.compose(
              [NibValidators.required(), NibValidators.password()],
            ),
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
            ),
          ),
          const SizedBox(height: 12),
          NibTextarea(
            label: 'Bio',
            placeholder: 'Optional — tell us a bit about yourself',
            minLines: 2,
            validator: NibValidators.minLength(10, 'Use at least 10 characters, or leave it empty.'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              NibButton(label: 'Submit', onPressed: _submit),
              const SizedBox(width: 8),
              NibButton(label: 'Reset', variant: NibButtonVariant.outline, onPressed: _reset),
            ],
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Text(_result!),
          ],
        ],
      ),
    );
  }
}
