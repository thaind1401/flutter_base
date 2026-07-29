import 'package:formz/formz.dart';

/// Validation errors are enums, never strings.
///
/// The domain decides *what* is wrong; the presentation layer decides *how to
/// say it* in the user's language. Putting a message here would hard-code
/// English into a package that has no localizations.
enum RequiredTextError { empty, tooShort, tooLong }

enum EmailError { empty, invalid }

enum PasswordError { empty, tooShort, missingUppercase, missingDigit, missingSymbol }

enum ConfirmPasswordError { empty, mismatch }

enum PhoneError { empty, invalid }

final class RequiredText extends FormzInput<String, RequiredTextError> {
  const RequiredText.pure({this.minLength = 1, this.maxLength = 255}) : super.pure('');

  const RequiredText.dirty(super.value, {this.minLength = 1, this.maxLength = 255}) : super.dirty();

  final int minLength;
  final int maxLength;

  @override
  RequiredTextError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return RequiredTextError.empty;
    if (trimmed.length < minLength) return RequiredTextError.tooShort;
    if (trimmed.length > maxLength) return RequiredTextError.tooLong;
    return null;
  }
}

final class Email extends FormzInput<String, EmailError> {
  const Email.pure() : super.pure('');

  const Email.dirty(super.value) : super.dirty();

  // Deliberately permissive: strict RFC 5322 rejects addresses that real mail
  // servers accept. The server is the authority; this only catches typos.
  static final RegExp _pattern = RegExp(r'^[\w.!#$%&’*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$');

  @override
  EmailError? validator(String value) {
    if (value.trim().isEmpty) return EmailError.empty;
    return _pattern.hasMatch(value.trim()) ? null : EmailError.invalid;
  }
}

final class Password extends FormzInput<String, PasswordError> {
  const Password.pure({this.policy = const PasswordPolicy()}) : super.pure('');

  const Password.dirty(super.value, {this.policy = const PasswordPolicy()}) : super.dirty();

  final PasswordPolicy policy;

  @override
  PasswordError? validator(String value) {
    if (value.isEmpty) return PasswordError.empty;
    if (value.length < policy.minLength) return PasswordError.tooShort;
    if (policy.requireUppercase && !value.contains(RegExp('[A-Z]'))) return PasswordError.missingUppercase;
    if (policy.requireDigit && !value.contains(RegExp('[0-9]'))) return PasswordError.missingDigit;
    if (policy.requireSymbol && !value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]\\/;+=~`]'))) {
      return PasswordError.missingSymbol;
    }
    return null;
  }
}

/// The rules a project's backend enforces, in one object so the client and the
/// copy on the sign-up screen cannot drift apart.
final class PasswordPolicy {
  const PasswordPolicy({
    this.minLength = 8,
    this.requireUppercase = true,
    this.requireDigit = true,
    this.requireSymbol = false,
  });

  final int minLength;
  final bool requireUppercase;
  final bool requireDigit;
  final bool requireSymbol;
}

final class ConfirmPassword extends FormzInput<String, ConfirmPasswordError> {
  const ConfirmPassword.pure({this.original = ''}) : super.pure('');

  const ConfirmPassword.dirty(super.value, {this.original = ''}) : super.dirty();

  final String original;

  @override
  ConfirmPasswordError? validator(String value) {
    if (value.isEmpty) return ConfirmPasswordError.empty;
    return value == original ? null : ConfirmPasswordError.mismatch;
  }
}

final class Phone extends FormzInput<String, PhoneError> {
  const Phone.pure() : super.pure('');

  const Phone.dirty(super.value) : super.dirty();

  static final RegExp _pattern = RegExp(r'^\+?[0-9]{8,15}$');

  @override
  PhoneError? validator(String value) {
    final compact = value.replaceAll(RegExp(r'[\s\-().]'), '');
    if (compact.isEmpty) return PhoneError.empty;
    return _pattern.hasMatch(compact) ? null : PhoneError.invalid;
  }
}
