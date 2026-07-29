import 'package:core_kit/core_kit.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Form state as data, not as a pile of booleans.
///
/// The inputs are `FormzInput`s, so validity and error come from the same
/// object the field renders — the submit button cannot say "enabled" while the
/// field says "invalid".
@immutable
final class LoginState extends Equatable {
  const LoginState({
    this.email = const Email.pure(),
    this.password = const Password.pure(),
    this.status = FormzSubmissionStatus.initial,
    this.failure,
  });

  final Email email;
  final Password password;
  final FormzSubmissionStatus status;

  /// Kept so the screen can render an inline banner; the toast is fired as a
  /// one-shot effect instead, because a state field would re-fire on rebuild.
  final Failure? failure;

  bool get isValid => Formz.validate([email, password]);

  bool get isSubmitting => status == FormzSubmissionStatus.inProgress;

  /// Submit is blocked while in flight — the second tap of a double tap would
  /// otherwise fire a second login request.
  bool get canSubmit => isValid && !isSubmitting;

  LoginState copyWith({Email? email, Password? password, FormzSubmissionStatus? status, Failure? failure}) =>
      LoginState(
        email: email ?? this.email,
        password: password ?? this.password,
        status: status ?? this.status,
        // Explicitly not `failure ?? this.failure`: a new attempt must clear the
        // previous error rather than inherit it.
        failure: failure,
      );

  @override
  List<Object?> get props => [email, password, status, failure];
}

/// One-shot outcomes. Delivered over the effect stream, never stored in state.
sealed class LoginEffect {
  const LoginEffect();
}

final class LoginSucceeded extends LoginEffect {
  const LoginSucceeded();
}

final class LoginFailed extends LoginEffect {
  const LoginFailed(this.failure);

  final Failure failure;
}
