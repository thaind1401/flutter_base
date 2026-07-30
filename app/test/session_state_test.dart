import 'dart:async';

import 'package:app/app/session/session_cubit.dart';
import 'package:core_kit/core_kit.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/null_session.dart';

/// A store whose session can change without its status changing — the case that
/// broke `HomeScreen`.
final class _MutableSessionStore implements SessionStore {
  final StreamController<SessionStatus> _changes = StreamController<SessionStatus>.broadcast();

  AuthSession? _session;

  @override
  AuthSession? get current => _session;

  @override
  SessionStatus get status => _session == null ? SessionStatus.unauthenticated : SessionStatus.authenticated;

  @override
  Stream<SessionStatus> get changes => _changes.stream;

  /// Publishes without asserting the status differs, exactly as a profile
  /// update would: the user is new, the status is still `authenticated`.
  void put(AuthSession session) {
    _session = session;
    _changes.add(status);
  }

  @override
  Future<Result<AuthSession?>> restore() async => Ok(_session);

  @override
  Future<Result<AuthSession?>> read() async => Ok(_session);

  @override
  Future<Result<Unit>> save(AuthSession session) async {
    put(session);
    return const Ok(unit);
  }

  @override
  Future<Result<Unit>> clear() async {
    _session = null;
    _changes.add(status);
    return const Ok(unit);
  }

  @override
  Future<void> dispose() => _changes.close();
}

AuthSession _sessionFor(String displayName) => AuthSession(
  accessToken: 'a',
  refreshToken: 'r',
  expiresAt: DateTime(2030),
  user: AuthUser(id: 'u1', email: 'a@b.com', displayName: displayName),
);

void main() {
  group('SessionState', () {
    test('lists every field in props', () {
      // Rule 13. Both BlocSelector and buildWhen decide by `==`; a field missing
      // from props means no widget ever rebuilds when it changes. Asserted
      // field by field because nothing else can check this.
      const base = SessionState(status: SessionStatus.authenticated);

      expect(base, const SessionState(status: SessionStatus.authenticated));
      expect(base, isNot(const SessionState(status: SessionStatus.unauthenticated)));
      expect(
        base,
        isNot(SessionState(status: SessionStatus.authenticated, user: _sessionFor('Ada').user)),
        reason: 'user is missing from props — a profile change would rebuild nothing',
      );
    });

    test('unknown is the pre-restore state', () {
      const state = SessionState.unknown();
      expect(state.status, SessionStatus.unknown);
      expect(state.user, isNull);
      expect(state.isAuthenticated, isFalse);
    });
  });

  group('SessionCubit', () {
    test('starts from whatever the store already holds', () {
      final store = _MutableSessionStore()..put(_sessionFor('Ada'));
      addTearDown(store.dispose);

      final cubit = SessionCubit(store, nullSignOutUseCase());
      addTearDown(cubit.close);

      expect(cubit.state.status, SessionStatus.authenticated);
      expect(cubit.state.user?.displayName, 'Ada');
    });

    test('a new user at an unchanged status still reaches the state', () async {
      // The regression this file exists for. `HomeScreen` used to rebuild on
      // SessionStatus and read `cubit.user` out of band, so this transition —
      // authenticated to authenticated, different user — updated nothing on
      // screen. Carrying the user in the state is what makes it observable.
      final store = _MutableSessionStore()..put(_sessionFor('Ada'));
      addTearDown(store.dispose);

      final cubit = SessionCubit(store, nullSignOutUseCase());
      addTearDown(cubit.close);

      final states = <SessionState>[];
      final subscription = cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);

      store.put(_sessionFor('Grace'));
      await Future<void>.delayed(Duration.zero);

      expect(states, hasLength(1), reason: 'the status did not change, but the state did');
      expect(states.single.status, SessionStatus.authenticated);
      expect(states.single.user?.displayName, 'Grace');
      expect(cubit.user?.displayName, 'Grace');
    });

    test('a repeated session does not emit again', () async {
      // The other half of rule 13: value equality is what stops a redundant
      // publish from rebuilding every subscriber.
      //
      // Note the first `put` below is deliberate rather than incidental. Bloc
      // suppresses an equal state with `if (state == _state && _emitted)`, and
      // `_emitted` is false until something has actually been emitted — so a
      // cubit re-emitting its *initial* state does notify, once. Any test that
      // asserts "equal state is silent" has to get past that first emit first.
      final store = _MutableSessionStore()..put(_sessionFor('Ada'));
      addTearDown(store.dispose);

      final cubit = SessionCubit(store, nullSignOutUseCase());
      addTearDown(cubit.close);

      final states = <SessionState>[];
      final subscription = cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);

      store.put(_sessionFor('Grace'));
      await Future<void>.delayed(Duration.zero);
      store.put(_sessionFor('Grace'));
      await Future<void>.delayed(Duration.zero);

      expect(states, hasLength(1), reason: 'the second publish carried an equal state and should be silent');
      expect(states.single.user?.displayName, 'Grace');
    });

    test('clearing the store drops the user as well as the status', () async {
      final store = _MutableSessionStore()..put(_sessionFor('Ada'));
      addTearDown(store.dispose);

      final cubit = SessionCubit(store, nullSignOutUseCase());
      addTearDown(cubit.close);

      await store.clear();
      await Future<void>.delayed(Duration.zero);

      // A stale user surviving a sign-out is the previous account's name on the
      // next person's home screen.
      expect(cubit.state.status, SessionStatus.unauthenticated);
      expect(cubit.state.user, isNull);
    });
  });
}
