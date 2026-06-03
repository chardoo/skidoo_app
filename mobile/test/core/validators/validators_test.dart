import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/validators/validators.dart';

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
}
