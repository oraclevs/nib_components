import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';

void main() {
  group('NibValidators.required', () {
    test('fails on null, empty, and whitespace-only', () {
      final v = NibValidators.required();
      expect(v(null), isNotNull);
      expect(v(''), isNotNull);
      expect(v('   '), isNotNull);
    });

    test('passes on non-empty text', () {
      expect(NibValidators.required()('hi'), isNull);
    });

    test('uses a custom message', () {
      expect(NibValidators.required('Need this')(''), 'Need this');
    });
  });

  group('NibValidators.minLength / maxLength', () {
    test('minLength ignores empty (delegates to required)', () {
      expect(NibValidators.minLength(5)(''), isNull);
      expect(NibValidators.minLength(5)(null), isNull);
    });

    test('minLength fails below the floor, passes at/above it', () {
      final v = NibValidators.minLength(5);
      expect(v('abcd'), isNotNull);
      expect(v('abcde'), isNull);
    });

    test('maxLength fails above the ceiling, passes at/below it', () {
      final v = NibValidators.maxLength(5);
      expect(v('abcdef'), isNotNull);
      expect(v('abcde'), isNull);
      expect(v(''), isNull);
    });
  });

  group('NibValidators.email', () {
    test('passes valid addresses, ignores empty', () {
      final v = NibValidators.email();
      expect(v('a@b.com'), isNull);
      expect(v('first.last+tag@sub.example.co'), isNull);
      expect(v(''), isNull);
    });

    test('fails malformed addresses', () {
      final v = NibValidators.email();
      expect(v('not-an-email'), isNotNull);
      expect(v('a@b'), isNotNull);
      expect(v('@b.com'), isNotNull);
    });
  });

  group('NibValidators.name', () {
    test('passes ordinary names, ignores empty', () {
      final v = NibValidators.name();
      expect(v('Ada Lovelace'), isNull);
      expect(v("O'Brien-Smith"), isNull);
      expect(v(''), isNull);
    });

    test('fails a name starting with a digit or symbol', () {
      final v = NibValidators.name();
      expect(v('1Ada'), isNotNull);
      expect(v('@Ada'), isNotNull);
    });
  });

  group('NibValidators.phone', () {
    test('passes common formats, ignores empty', () {
      final v = NibValidators.phone();
      expect(v('+1 (555) 123-4567'), isNull);
      expect(v('5551234567'), isNull);
      expect(v(''), isNull);
    });

    test('fails text that is not a phone number', () {
      expect(NibValidators.phone()('call me maybe'), isNotNull);
    });
  });

  group('NibValidators.pattern', () {
    test('runs an arbitrary regex, ignores empty', () {
      final v = NibValidators.pattern(RegExp(r'^\d{4}$'), 'Need 4 digits');
      expect(v('1234'), isNull);
      expect(v('12a4'), 'Need 4 digits');
      expect(v(''), isNull);
    });
  });

  group('NibValidators.password', () {
    test('ignores empty', () {
      expect(NibValidators.password()(''), isNull);
    });

    test('reports the first unmet requirement', () {
      expect(NibValidators.password()('short'), contains('8 characters'));
      expect(NibValidators.password()('longenough'), contains('uppercase'));
      expect(NibValidators.password()('LONGENOUGH'), contains('lowercase'));
      expect(NibValidators.password()('LongEnough'), contains('number'));
      expect(NibValidators.password()('LongEnough1'), isNull);
    });

    test('requireSpecialChar is opt-in and enforced when set', () {
      final v = NibValidators.password(requireSpecialChar: true);
      expect(v('LongEnough1'), contains('special character'));
      expect(v('LongEnough1!'), isNull);
    });

    test('individual requirements can be disabled', () {
      final v = NibValidators.password(
        requireUppercase: false,
        requireLowercase: false,
        requireNumber: false,
      );
      expect(v('alllowercase'), isNull);
    });
  });

  group('NibValidators.compose', () {
    test('returns the first failing validator\'s message', () {
      final v = NibValidators.compose([
        NibValidators.required(),
        NibValidators.email(),
      ]);
      expect(v(''), NibValidators.required()(''));
      expect(v('not-an-email'), NibValidators.email()('not-an-email'));
      expect(v('a@b.com'), isNull);
    });

    test('an empty validator list always passes', () {
      expect(NibValidators.compose([])('anything'), isNull);
    });
  });
}
