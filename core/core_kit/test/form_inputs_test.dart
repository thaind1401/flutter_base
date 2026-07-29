import 'package:core_kit/core_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Email', () {
    test('pure input is not validated yet', () {
      expect(const Email.pure().isPure, isTrue);
      expect(const Email.pure().displayError, isNull);
    });

    test('rejects blank and malformed addresses', () {
      expect(const Email.dirty('').error, EmailError.empty);
      expect(const Email.dirty('   ').error, EmailError.empty);
      expect(const Email.dirty('nope').error, EmailError.invalid);
      expect(const Email.dirty('a@b').error, EmailError.invalid);
    });

    test('accepts an ordinary address', () {
      expect(const Email.dirty('thai.nguyen@example.com').error, isNull);
    });
  });

  group('Password', () {
    test('applies the configured policy', () {
      const policy = PasswordPolicy(minLength: 8, requireSymbol: true);
      expect(const Password.dirty('', policy: policy).error, PasswordError.empty);
      expect(const Password.dirty('Ab1!', policy: policy).error, PasswordError.tooShort);
      expect(const Password.dirty('abcdefg1!', policy: policy).error, PasswordError.missingUppercase);
      expect(const Password.dirty('Abcdefgh!', policy: policy).error, PasswordError.missingDigit);
      expect(const Password.dirty('Abcdefg1', policy: policy).error, PasswordError.missingSymbol);
      expect(const Password.dirty('Abcdefg1!', policy: policy).error, isNull);
    });
  });

  group('ConfirmPassword', () {
    test('must match the original', () {
      expect(const ConfirmPassword.dirty('a', original: 'b').error, ConfirmPasswordError.mismatch);
      expect(const ConfirmPassword.dirty('a', original: 'a').error, isNull);
    });
  });

  group('Phone', () {
    test('ignores formatting characters', () {
      expect(const Phone.dirty('+84 (90) 123-4567').error, isNull);
      expect(const Phone.dirty('123').error, PhoneError.invalid);
    });
  });

  test('Formz.validate gates the submit button', () {
    expect(Formz.validate([const Email.dirty('a@b.com'), const Password.dirty('Abcdefg1')]), isTrue);
    expect(Formz.validate([const Email.dirty('nope'), const Password.dirty('Abcdefg1')]), isFalse);
  });
}
