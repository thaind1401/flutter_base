import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:feature_auth/src/domain/use_cases/auth_use_cases.dart';
import 'package:feature_auth/src/presentation/login/login_state.dart';
import 'package:injectable/injectable.dart';

sealed class LoginEvent {
  const LoginEvent();
}

final class LoginEmailChanged extends LoginEvent {
  const LoginEmailChanged(this.value);

  final String value;
}

final class LoginPasswordChanged extends LoginEvent {
  const LoginPasswordChanged(this.value);

  final String value;
}

final class LoginSubmitted extends LoginEvent {
  const LoginSubmitted();
}

/// Reference bloc.
///
/// Everything a feature bloc should look like:
///   * depends on use cases only — no repository, no Dio, no storage;
///   * no `try/catch`, because the use case returns a `Result`;
///   * one-shot outcomes go out as effects, not as state flags;
///   * `droppable()` on submit, so a second tap while a request is in flight is
///     discarded rather than queued.
@injectable
final class LoginBloc extends BaseBloc<LoginEvent, LoginState> {
  LoginBloc(this._signIn) : super(const LoginState()) {
    on<LoginEmailChanged>(_onEmailChanged);
    on<LoginPasswordChanged>(_onPasswordChanged);
    on<LoginSubmitted>(_onSubmitted, transformer: droppable());
  }

  final SignInUseCase _signIn;

  void _onEmailChanged(LoginEmailChanged event, Emitter<LoginState> emit) {
    emit(state.copyWith(email: Email.dirty(event.value), status: FormzSubmissionStatus.initial));
  }

  void _onPasswordChanged(LoginPasswordChanged event, Emitter<LoginState> emit) {
    emit(state.copyWith(password: Password.dirty(event.value), status: FormzSubmissionStatus.initial));
  }

  Future<void> _onSubmitted(LoginSubmitted event, Emitter<LoginState> emit) async {
    if (!state.isValid) {
      // Re-emitting the inputs as dirty makes a pristine field reveal its error
      // when the user submits an empty form.
      emit(
        state.copyWith(
          email: Email.dirty(state.email.value),
          password: Password.dirty(state.password.value),
          status: FormzSubmissionStatus.failure,
        ),
      );
      return;
    }

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    final result = await _signIn((email: state.email.value, password: state.password.value));

    switch (result) {
      case Ok():
        emit(state.copyWith(status: FormzSubmissionStatus.success));
        emitEffect(const LoginSucceeded());
      case Err(:final failure):
        emit(state.copyWith(status: FormzSubmissionStatus.failure, failure: failure));
        emitEffect(LoginFailed(failure));
    }
  }
}
