import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:feature_auth/src/domain/entities/auth_session.dart';
import 'package:feature_auth/src/domain/repositories/auth_repository.dart';
import 'package:feature_auth/src/domain/session/session_store.dart';
import 'package:injectable/injectable.dart';

/// Parameters are a typed record — never `Map<String, dynamic>`.
///
/// An untyped body turns a renamed field into a runtime bug that only the
/// backend notices; a record makes it a compile error at the call site.
typedef SignInParams = ({String email, String password});

/// Signs in and persists the session.
///
/// The persistence deliberately lives in the use case rather than the
/// repository: "authenticate" and "remember this device" are two decisions, and
/// a future biometric or guest flow reuses the repository without the storage
/// side effect.
@injectable
class SignInUseCase extends UseCase<SignInParams, AuthSession> {
  const SignInUseCase(this._repository, this._sessionStore);

  final AuthRepository _repository;
  final SessionStore _sessionStore;

  @override
  Future<Result<AuthSession>> execute(SignInParams params) async {
    final result = await _repository.signIn(email: params.email.trim(), password: params.password);
    return result.flatMapAsync((session) async {
      final saved = await _sessionStore.save(session);
      // A keystore write failure must not present as a failed login — the user
      // is authenticated; they will simply have to sign in again next launch.
      return saved.fold((_) => Ok(session), (_) => Ok(session));
    });
  }
}

/// Clears local state, then tells the server. Order matters: if the revoke call
/// hangs, the user is already signed out locally rather than stuck on a spinner.
@injectable
class SignOutUseCase extends CompletableUseCase<NoParams> {
  const SignOutUseCase(this._repository, this._sessionStore);

  final AuthRepository _repository;
  final SessionStore _sessionStore;

  @override
  Future<Result<Unit>> execute(NoParams params) async {
    await _sessionStore.clear();
    await _repository.signOut();
    return const Ok(unit);
  }
}

/// Restores a persisted session at startup.
///
/// Returns `Ok(null)` for "no session" — that is a normal first launch, not an
/// error, and modelling it as a failure would make the splash show a toast.
@injectable
class RestoreSessionUseCase extends NoParamsUseCase<AuthSession?> {
  const RestoreSessionUseCase(this._sessionStore);

  final SessionStore _sessionStore;

  @override
  Future<Result<AuthSession?>> execute(NoParams params) => _sessionStore.read();
}
