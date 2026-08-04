import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_auth.dart';

/// The use cases carry the decisions that neither the repository nor the bloc
/// owns, and every one of them is a rule about ordering or about what counts as
/// a failure. Those are exactly the rules a refactor quietly inverts.
void main() {
  late FakeAuthRepository repository;
  late FakeSessionStore store;

  setUp(() {
    repository = FakeAuthRepository();
    store = FakeSessionStore();
  });

  tearDown(() => store.dispose());

  group('SignInUseCase', () {
    test('signs in and persists the session', () async {
      // Persistence lives here rather than in the repository: "authenticate"
      // and "remember this device" are two decisions, and a future biometric
      // or guest flow reuses the repository without the storage side effect.
      final useCase = SignInUseCase(repository, store);

      final result = await useCase((email: 'a@b.com', password: 'secret'));

      expect(result.isOk, isTrue);
      expect(repository.signInCalls, 1);
      expect(store.saved, isNotNull);
    });

    test('trims the email before it reaches the repository', () async {
      // A trailing space from an autofill or a paste otherwise reaches the
      // backend and fails a lookup that should have matched.
      final useCase = SignInUseCase(repository, store);

      await useCase((email: '  a@b.com  ', password: 'secret'));

      expect(repository.lastEmail, 'a@b.com');
    });

    test('the password is passed through untouched', () async {
      // Deliberately *not* trimmed — leading or trailing whitespace can be part
      // of a password, and silently stripping it locks the user out of an
      // account they can still sign into from the web.
      final useCase = SignInUseCase(repository, store);

      await useCase((email: 'a@b.com', password: '  spaced  '));

      expect(repository.signInCalls, 1);
    });

    test('a repository failure is returned and nothing is stored', () async {
      repository.failWith = const UnauthorizedFailure(debugMessage: 'wrong password');
      final useCase = SignInUseCase(repository, store);

      final result = await useCase((email: 'a@b.com', password: 'wrong'));

      expect(result.failureOrNull, isA<UnauthorizedFailure>());
      expect(store.saved, isNull);
    });

    test('a keystore write failure still reports a successful sign-in', () async {
      // The documented rule, and a counter-intuitive one: the user *is*
      // authenticated. Failing the login because the keychain was unavailable
      // would block them from an app they have valid credentials for; the only
      // real consequence is signing in again next launch.
      store.failSave = const CacheFailure(debugMessage: 'keystore locked');
      final useCase = SignInUseCase(repository, store);

      final result = await useCase((email: 'a@b.com', password: 'secret'));

      expect(result.isOk, isTrue);
      expect(store.saved, isNull, reason: 'the write really did fail');
    });
  });

  group('SignOutUseCase', () {
    test('clears local state before calling the server', () async {
      // Order matters: if the revoke call hangs, the user is already signed out
      // locally rather than stuck watching a spinner they cannot escape.
      store.saved = FakeAuthRepository.session();
      final useCase = SignOutUseCase(repository, store);

      final result = await useCase(const NoParams());

      expect(result.isOk, isTrue);
      expect(store.saved, isNull);
    });

    test('succeeds even when there was no session to clear', () async {
      final useCase = SignOutUseCase(repository, store);

      expect((await useCase(const NoParams())).isOk, isTrue);
    });
  });

  group('RestoreSessionUseCase', () {
    test('a first launch is Ok(null), not a failure', () async {
      // Modelling "no session" as an error would make the splash screen show a
      // toast to every new user.
      final useCase = RestoreSessionUseCase(store);

      expect(await useCase(const NoParams()), const Ok<AuthSession?>(null));
    });

    test('returns the stored session when there is one', () async {
      store.saved = FakeAuthRepository.session();
      final useCase = RestoreSessionUseCase(store);

      expect((await useCase(const NoParams())).valueOrNull?.accessToken, 'access-token');
    });
  });

  group('StartSessionUseCase', () {
    test('goes through restore, which is what publishes the status', () async {
      // The difference from `RestoreSessionUseCase`, and the reason both exist:
      // startup needs the store to *publish*, or the router's first redirect
      // still sees `unknown` and the app flashes login at a signed-in user.
      store.saved = FakeAuthRepository.session();
      final useCase = StartSessionUseCase(store);

      final result = await useCase(const NoParams());

      expect(result.valueOrNull, isNotNull);
    });
  });

  group('WatchSessionUseCase', () {
    test('emits the current snapshot before any change arrives', () async {
      // `changes` is a broadcast stream with no replay. Without this seed, a
      // subscriber constructed after sign-in sits on its initial state until
      // the next transition — which, for a signed-in user idling on one screen,
      // may never come.
      store.saved = FakeAuthRepository.session();
      final useCase = WatchSessionUseCase(store);

      final first = await useCase(const NoParams()).first;

      expect(first.valueOrNull?.status, SessionStatus.authenticated);
    });

    test('emits the unauthenticated snapshot when signed out', () async {
      final useCase = WatchSessionUseCase(store);

      final first = await useCase(const NoParams()).first;

      expect(first.valueOrNull?.status, SessionStatus.unauthenticated);
      expect(first.valueOrNull?.session, isNull);
    });

    test('subsequent changes follow the seed', () async {
      final useCase = WatchSessionUseCase(store);
      final seen = <SessionStatus>[];
      final subscription = useCase(const NoParams()).listen((result) {
        if (result case Ok(:final value)) seen.add(value.status);
      });
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      await store.save(FakeAuthRepository.session());
      await pumpEventQueue();
      await store.clear();
      await pumpEventQueue();

      expect(seen, [SessionStatus.unauthenticated, SessionStatus.authenticated, SessionStatus.unauthenticated]);
    });
  });
}
