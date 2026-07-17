/// A field validator: `null` means valid, a non-null [String] is the error
/// message to show. Matches Flutter's own `FormFieldValidator<String>`
/// signature so the two are interchangeable.
typedef NibValidator = String? Function(String? value);

/// Predefined [NibValidator]s for [NibInput]/[NibTextarea], plus [compose]
/// to chain several into one.
///
/// Every format validator here (everything but [required]) treats an empty
/// value as **valid** — an optional field with no value has nothing to
/// validate the format of. Pair with [required] via [compose] when the field
/// is mandatory:
///
/// ```dart
/// NibInput(
///   label: 'Email',
///   validator: NibValidators.compose([
///     NibValidators.required(),
///     NibValidators.email(),
///   ]),
/// )
/// ```
abstract final class NibValidators {
  static final RegExp _emailPattern =
      RegExp(r"^[\w.\-+%]+@[\w\-]+(\.[\w\-]+)+$");

  static final RegExp _namePattern = RegExp(r"^[\p{L}][\p{L}'\- ]*$", unicode: true);

  static final RegExp _phonePattern = RegExp(r'^\+?[0-9\s\-().]{7,20}$');

  /// Runs [validators] in order, returning the first non-null error (or
  /// `null` if every validator passes).
  static NibValidator compose(List<NibValidator> validators) {
    return (value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }

  /// Fails when [value] is `null`, empty, or whitespace-only.
  static NibValidator required([String message = 'This field is required.']) {
    return (value) =>
        (value == null || value.trim().isEmpty) ? message : null;
  }

  /// Fails when non-empty [value] is shorter than [length] characters.
  static NibValidator minLength(int length, [String? message]) {
    return (value) {
      if (value == null || value.isEmpty) return null;
      return value.length < length
          ? (message ?? 'Must be at least $length characters.')
          : null;
    };
  }

  /// Fails when [value] is longer than [length] characters.
  static NibValidator maxLength(int length, [String? message]) {
    return (value) {
      if (value == null || value.isEmpty) return null;
      return value.length > length
          ? (message ?? 'Must be no more than $length characters.')
          : null;
    };
  }

  /// Fails when non-empty [value] doesn't look like an email address.
  static NibValidator email([String message = 'Enter a valid email address.']) {
    return (value) {
      if (value == null || value.isEmpty) return null;
      return _emailPattern.hasMatch(value) ? null : message;
    };
  }

  /// Fails when non-empty [value] doesn't match [pattern].
  static NibValidator pattern(RegExp pattern, [String message = 'Invalid format.']) {
    return (value) {
      if (value == null || value.isEmpty) return null;
      return pattern.hasMatch(value) ? null : message;
    };
  }

  /// Fails when non-empty [value] doesn't look like a person's name (starts
  /// with a letter; letters, spaces, hyphens, and apostrophes only).
  static NibValidator name([String message = 'Enter a valid name.']) {
    return (value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) return null;
      return _namePattern.hasMatch(trimmed) ? null : message;
    };
  }

  /// Fails when non-empty [value] doesn't look like a phone number (digits,
  /// spaces, and `+`/`-`/`()` only, 7–20 characters).
  static NibValidator phone([String message = 'Enter a valid phone number.']) {
    return (value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) return null;
      return _phonePattern.hasMatch(trimmed) ? null : message;
    };
  }

  /// Fails when non-empty [value] doesn't meet the requested password rules.
  /// Each requirement is reported individually (the first one it fails).
  static NibValidator password({
    int minLength = 8,
    bool requireUppercase = true,
    bool requireLowercase = true,
    bool requireNumber = true,
    bool requireSpecialChar = false,
  }) {
    return (value) {
      if (value == null || value.isEmpty) return null;
      if (value.length < minLength) {
        return 'Must be at least $minLength characters.';
      }
      if (requireUppercase && !value.contains(RegExp('[A-Z]'))) {
        return 'Must contain an uppercase letter.';
      }
      if (requireLowercase && !value.contains(RegExp('[a-z]'))) {
        return 'Must contain a lowercase letter.';
      }
      if (requireNumber && !value.contains(RegExp('[0-9]'))) {
        return 'Must contain a number.';
      }
      if (requireSpecialChar &&
          !value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=~`\[\];/]'))) {
        return 'Must contain a special character.';
      }
      return null;
    };
  }
}
