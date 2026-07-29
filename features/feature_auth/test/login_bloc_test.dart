import 'package:bloc_test/bloc_test.dart';
import 'package:core_kit/core_kit.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/src/presentation/login/login_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_auth.dart';

void main() {
  late FakeAuthRepository repository;
  late FakeSessionStore sessionStore;
  late SignInUseCase signIn;

  setUp(() {
    repository = FakeAuthRepository();
    sessionStore = FakeSessionStore();
    signIn = SignInUseCase(repository, sessionStore);
  });

  group('LoginBloc validation', () {
    blocTest<LoginBloc, LoginState>(
      'marks the email invalid as the user types',
      build: () => LoginBloc(signIn),
      act: (bloc) => bloc.add(const LoginEmailChanged('nope')),
      expect: () => [isA<LoginState>().having((s) => s.email.error, 'email error', EmailError.invalid)],
    );

    blocTest<LoginBloc, LoginState>(
      'submitting an empty form dirties both fields instead of calling the API',
      build: () => LoginBloc(signIn),
      act: (bloc) => bloc.add(const LoginSubmitted()),
      expect: () => [
        isA<LoginState>()
            .having((s) => s.email.isPure, 'email pure', isFalse)
            .having((s) => s.password.isPure, 'password pure', isFalse)
            .having((s) => s.status, 'status', FormzSubmissionStatus.failure),
      ],
      verify: (_) => expect(repository.signInCalls, 0),
    );

    blocTest<LoginBloc, LoginState>(
      'canSubmit is false until both inputs are valid',
      build: () => LoginBloc(signIn),
      act: (bloc) => bloc
        ..add(const LoginEmailChanged('a@b.com'))
        ..add(const LoginPasswordChanged('short')),
      verify: (bloc) => expect(bloc.state.canSubmit, isFalse),
    );
  });

  group('LoginBloc submission', () {
    blocTest<LoginBloc, LoginState>(
      'signs in and persists the session',
      build: () => LoginBloc(signIn),
      act: (bloc) => bloc
        ..add(const LoginEmailChanged('a@b.com'))
        ..add(const LoginPasswordChanged('Abcdefg1'))
        ..add(const LoginSubmitted()),
      skip: 2,
      expect: () => [
        isA<LoginState>().having((s) => s.status, 'status', FormzSubmissionStatus.inProgress),
        isA<LoginState>().having((s) => s.status, 'status', FormzSubmissionStatus.success),
      ],
      verify: (_) {
        expect(repository.signInCalls, 1);
        expect(sessionStore.saved, isNotNull);
      },
    );

    blocTest<LoginBloc, LoginState>(
      'surfaces a failure without persisting anything',
      build: () {
        repository.failWith = const BusinessFailure(code: 'BAD_CREDENTIALS');
        return LoginBloc(signIn);
      },
      act: (bloc) => bloc
        ..add(const LoginEmailChanged('a@b.com'))
        ..add(const LoginPasswordChanged('Abcdefg1'))
        ..add(const LoginSubmitted()),
      skip: 3,
      expect: () => [
        isA<LoginState>()
            .having((s) => s.status, 'status', FormzSubmissionStatus.failure)
            .having((s) => s.failure, 'failure', isA<BusinessFailure>()),
      ],
      verify: (_) => expect(sessionStore.saved, isNull),
    );

    test('emits LoginSucceeded as a one-shot effect', () async {
      final bloc = LoginBloc(signIn);
      final effects = <Object>[];
      final subscription = bloc.effects.listen(effects.add);

      bloc
        ..add(const LoginEmailChanged('a@b.com'))
        ..add(const LoginPasswordChanged('Abcdefg1'))
        ..add(const LoginSubmitted());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(effects, [isA<LoginSucceeded>()]);
      await subscription.cancel();
      await bloc.close();
    });

    test('a second tap while submitting is dropped, not queued', () async {
      // Without droppable() the queued event fires a second login request and
      // the backend sees a duplicate sign-in.
      repository.delay = const Duration(milliseconds: 60);
      final bloc = LoginBloc(signIn);

      bloc
        ..add(const LoginEmailChanged('a@b.com'))
        ..add(const LoginPasswordChanged('Abcdefg1'));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      bloc
        ..add(const LoginSubmitted())
        ..add(const LoginSubmitted());
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(repository.signInCalls, 1);
      await bloc.close();
    });
  });

  group('SignInUseCase', () {
    test('trims a pasted email before sending it', () async {
      await signIn((email: '  a@b.com  ', password: 'Abcdefg1'));
      expect(repository.lastEmail, 'a@b.com');
    });

    test('still succeeds when the keystore write fails', () async {
      // The user is authenticated; a storage problem only costs them the
      // "stay signed in" convenience and must not look like a failed login.
      sessionStore.failSave = const CacheFailure();
      final result = await signIn((email: 'a@b.com', password: 'Abcdefg1'));
      expect(result.isOk, isTrue);
    });
  });
}
