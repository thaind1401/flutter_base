import 'dart:async';

import 'package:core_kit/core_kit.dart';
import 'package:feature_auth/feature_auth.dart';

/// Hand-written fakes rather than generated mocks.
///
/// For interfaces this small a fake is shorter than the mock setup, reads as
/// documentation of what the collaborator does, and does not need codegen to
/// run before the tests do.
final class FakeAuthRepository implements AuthRepository {
  int signInCalls = 0;
  String? lastEmail;
  Failure? failWith;
  Duration delay = Duration.zero;

  static AuthSession session({DateTime? expiresAt}) => AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
    user: const AuthUser(id: 'u1', email: 'a@b.com', displayName: 'Tester'),
  );

  @override
  Future<Result<AuthSession>> signIn({required String email, required String password}) async {
    signInCalls++;
    lastEmail = email;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = failWith;
    if (failure != null) return Err(failure);
    return Ok(session());
  }

  @override
  Future<Result<Unit>> signOut() async => const Ok(unit);

  @override
  Future<Result<AuthUser>> currentUser() async => Ok(session().user);
}

final class FakeSessionStore implements SessionStore {
  AuthSession? saved;
  Failure? failSave;
  final StreamController<SessionSnapshot> _changes = StreamController<SessionSnapshot>.broadcast();

  @override
  AuthSession? get current => saved;

  @override
  SessionStatus get status => saved == null ? SessionStatus.unauthenticated : SessionStatus.authenticated;

  @override
  SessionSnapshot get snapshot => SessionSnapshot(status: status, session: saved);

  @override
  Stream<SessionSnapshot> get changes => _changes.stream;

  @override
  Future<Result<AuthSession?>> restore() async => Ok(saved);

  @override
  Future<Result<AuthSession?>> read() async => Ok(saved);

  @override
  Future<Result<Unit>> save(AuthSession session) async {
    final failure = failSave;
    if (failure != null) return Err(failure);
    saved = session;
    _changes.add(SessionSnapshot(status: SessionStatus.authenticated, session: session));
    return const Ok(unit);
  }

  @override
  Future<Result<Unit>> clear() async {
    saved = null;
    _changes.add(const SessionSnapshot(status: SessionStatus.unauthenticated));
    return const Ok(unit);
  }

  @override
  /// Does **not** await the close.
  ///
  /// `StreamController.close()` returns a future created inside whatever zone
  /// called it. In a `testWidgets` body that is the fake-async zone, while
  /// `addTearDown` is awaited outside it — so awaiting the close there hangs the
  /// test forever with no error, and the whole package's suite with it. A fake's
  /// teardown must never be able to do that.
  Future<void> dispose() async => unawaited(_changes.close());
}
