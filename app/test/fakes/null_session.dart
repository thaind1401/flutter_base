import 'package:core_kit/core_kit.dart';
import 'package:feature_auth/feature_auth.dart';

/// Does nothing, successfully. Enough to construct a [SessionCubit] for tests
/// that only exercise logic reading its status.
final class NullSessionStore implements SessionStore {
  @override
  AuthSession? get current => null;

  @override
  Stream<SessionSnapshot> get changes => const Stream.empty();

  @override
  SessionStatus get status => SessionStatus.unknown;

  @override
  SessionSnapshot get snapshot => const SessionSnapshot.unknown();

  @override
  Future<Result<AuthSession?>> restore() async => const Ok(null);

  @override
  Future<Result<AuthSession?>> read() async => const Ok(null);

  @override
  Future<Result<Unit>> save(AuthSession session) async => const Ok(unit);

  @override
  Future<Result<Unit>> clear() async => const Ok(unit);

  @override
  Future<void> dispose() async {}
}

final class NullAuthRepository implements AuthRepository {
  const NullAuthRepository();

  @override
  Future<Result<AuthSession>> signIn({required String email, required String password}) async =>
      const Err(UnexpectedFailure(debugMessage: 'not used in this test'));

  @override
  Future<Result<Unit>> signOut() async => const Ok(unit);

  @override
  Future<Result<AuthUser>> currentUser() async => const Err(UnexpectedFailure());
}

/// The real use cases over null collaborators, rather than fake use cases.
/// Exercising the production classes keeps the test honest about its wiring.
SignOutUseCase nullSignOutUseCase() => SignOutUseCase(const NullAuthRepository(), NullSessionStore());

WatchSessionUseCase nullWatchSessionUseCase() => WatchSessionUseCase(NullSessionStore());

StartSessionUseCase nullStartSessionUseCase() => StartSessionUseCase(NullSessionStore());
