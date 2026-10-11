import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/validators/validators.dart';

void main() {
  group('Validators.emailValidator', () {
    test('accepts well-formed addresses', () {
      expect(Validators.emailValidator('user@example.com'), isNull);
      expect(Validators.emailValidator('a.b+tag@sub.domain.co'), isNull);
    });

    test('rejects empty / null / malformed', () {
      expect(Validators.emailValidator(null), isNotNull);
      expect(Validators.emailValidator(''), isNotNull);
      expect(Validators.emailValidator('not-an-email'), isNotNull);
      expect(Validators.emailValidator('missing@domain'), isNotNull);
      expect(Validators.emailValidator('@no-local.com'), isNotNull);
    });

    test('trims surrounding whitespace before matching', () {
      expect(Validators.emailValidator('  user@example.com  '), isNull);
    });
  });

  group('Validators.codeValidator', () {
    test('requires at least 3 characters', () {
      expect(Validators.codeValidator('12'), isNotNull);
      expect(Validators.codeValidator('123'), isNull);
    });

    test('rejects empty / null', () {
      expect(Validators.codeValidator(null), isNotNull);
      expect(Validators.codeValidator(''), isNotNull);
    });
  });

  group('Validators.nameValidator', () {
    test('rejects blank and single character', () {
      expect(Validators.nameValidator(null), isNotNull);
      expect(Validators.nameValidator('   '), isNotNull);
      expect(Validators.nameValidator('a'), isNotNull);
    });

    test('accepts two or more characters', () {
      expect(Validators.nameValidator('Jo'), isNull);
      expect(Validators.nameValidator('Joseph'), isNull);
    });
  });

  group('Validators.phoneNumberValidator', () {
    test('accepts Ghana mobile format', () {
      expect(Validators.phoneNumberValidator('0241234567'), isNull);
      expect(Validators.phoneNumberValidator('0551234567'), isNull);
    });

    test('rejects malformed numbers', () {
      expect(Validators.phoneNumberValidator(null), isNotNull);
      expect(Validators.phoneNumberValidator(''), isNotNull);
      expect(Validators.phoneNumberValidator('1234567'), isNotNull);
      expect(Validators.phoneNumberValidator('024abc1234'), isNotNull);
    });
  });

  group('Validators.passwordValidator (login — lenient)', () {
    test('only requires non-empty', () {
      expect(Validators.passwordValidator(''), isNotNull);
      expect(Validators.passwordValidator('x'), isNull);
    });
  });

  group('Validators.signupPasswordValidator (strict)', () {
    test('requires at least minPasswordLength characters (matches backend)', () {
      expect(Validators.minPasswordLength, 8);
      expect(Validators.signupPasswordValidator(''), isNotNull);
      expect(Validators.signupPasswordValidator('Abc1!de'), isNotNull); // 7
      // 8 chars meeting the full policy (lower + upper + number + symbol).
      expect(Validators.signupPasswordValidator('Abcdef1!'), isNull);
    });

    test('requires lower + upper + number + symbol', () {
      expect(Validators.signupPasswordValidator('ABCDEF1!'), isNotNull); // no lower
      expect(Validators.signupPasswordValidator('abcdef1!'), isNotNull); // no upper
      expect(Validators.signupPasswordValidator('Abcdefg!'), isNotNull); // no number
      expect(Validators.signupPasswordValidator('Abcdefg1'), isNotNull); // no symbol
      expect(Validators.signupPasswordValidator('Abcdef1!'), isNull); // all four
    });
  });

  group('Validators.required', () {
    test('fails on blank, passes on content', () {
      expect(Validators.required(null), isNotNull);
      expect(Validators.required('   '), isNotNull);
      expect(Validators.required('ok'), isNull);
    });

    test('includes the field name in the message', () {
      expect(Validators.required(null, field: 'Title'), contains('Title'));
    });
  });

  group('Validators.maxLength', () {
    test('passes when within limit (and when empty)', () {
      expect(Validators.maxLength('', 5), isNull);
      expect(Validators.maxLength('hello', 5), isNull);
    });

    test('fails when over limit', () {
      expect(Validators.maxLength('hello!', 5), isNotNull);
    });
  });

  group('Validators.lengthBetween', () {
    test('enforces min and max', () {
      expect(Validators.lengthBetween('', 3, 10), isNotNull);
      expect(Validators.lengthBetween('ab', 3, 10), isNotNull);
      expect(Validators.lengthBetween('abc', 3, 10), isNull);
      expect(Validators.lengthBetween('abcdefghijk', 3, 10), isNotNull);
    });

    test('trims before measuring', () {
      expect(Validators.lengthBetween('  abc  ', 3, 10), isNull);
    });
  });

  group('Validators.amount (required)', () {
    test('requires a positive number', () {
      expect(Validators.amount(''), isNotNull);
      expect(Validators.amount('abc'), isNotNull);
      expect(Validators.amount('0'), isNotNull);
      expect(Validators.amount('-5'), isNotNull);
      expect(Validators.amount('500'), isNull);
      expect(Validators.amount('12.50'), isNull);
    });
  });

  group('Validators.optionalAmount', () {
    test('blank passes', () {
      expect(Validators.optionalAmount(''), isNull);
      expect(Validators.optionalAmount(null), isNull);
    });

    test('present value must be a positive number', () {
      expect(Validators.optionalAmount('abc'), isNotNull);
      expect(Validators.optionalAmount('0'), isNotNull);
      expect(Validators.optionalAmount('-1'), isNotNull);
      expect(Validators.optionalAmount('250'), isNull);
    });
  });

  group('Validators.url', () {
    test('accepts http and https URLs with authority', () {
      expect(Validators.url('https://example.com'), isNull);
      expect(Validators.url('http://example.com/path?q=1'), isNull);
    });

    test('rejects non-http schemes and bare strings', () {
      expect(Validators.url('ftp://example.com'), isNotNull);
      expect(Validators.url('example.com'), isNotNull);
      expect(Validators.url('https://'), isNotNull);
    });

    test('respects isRequired flag for blank input', () {
      expect(Validators.url('', isRequired: true), isNotNull);
      expect(Validators.url('', isRequired: false), isNull);
    });
  });

  group('Validators.nationalPhoneValidator', () {
    // The reported bug: a long number was flagged, a short one was not.
    //
    // The validator was being handed the full E.164 number rather than the
    // digits typed into the field, so the dial code paid most of the
    // minimum. `+233` is four characters of the six required — two typed
    // digits were enough to pass, while a long number still tripped the
    // ceiling. That asymmetry is exactly what was seen on screen.
    test('rejects a number that is too short', () {
      expect(Validators.nationalPhoneValidator('24'), isNotNull);
      expect(Validators.nationalPhoneValidator('241'), isNotNull);
      expect(Validators.nationalPhoneValidator('241234'), isNotNull);
    });

    test('rejects a number that is too long', () {
      expect(Validators.nationalPhoneValidator('12345678901234'), isNotNull);
    });

    test('accepts a real national number', () {
      // Ghana is nine digits; the shorter and longer ones are real lengths
      // elsewhere, and must not be refused.
      expect(Validators.nationalPhoneValidator('241234567'), isNull);
      expect(Validators.nationalPhoneValidator('12345678'), isNull);
      expect(Validators.nationalPhoneValidator('1234567890'), isNull);
    });

    test('asks for a number when the field is empty', () {
      expect(Validators.nationalPhoneValidator(''), contains('required'));
      expect(Validators.nationalPhoneValidator(null), contains('required'));
      expect(Validators.nationalPhoneValidator('   '), contains('required'));
    });

    test('says which way it is wrong', () {
      // "Invalid number" for both left somebody with a short number no idea
      // what to do about it.
      expect(Validators.nationalPhoneValidator('24'), contains('short'));
      expect(
          Validators.nationalPhoneValidator('12345678901234'), contains('long'));
    });

    test('counts digits, not characters', () {
      // Spacing is how people write phone numbers, and the field is fed
      // whatever the formatter left behind.
      expect(Validators.nationalPhoneValidator('24 123 4567'), isNull);
      expect(Validators.nationalPhoneValidator('24 1'), isNotNull);
    });

    test('a dial code is not part of what it measures', () {
      // The regression guard. If the full E.164 number is ever fed back in,
      // this two-digit number would pass on the strength of `+233`.
      expect(Validators.nationalPhoneValidator('+23324'), isNotNull,
          reason: 'the dial code must not pay for the minimum');
    });
  });
}
