import 'package:core_kit/core_kit.dart';
import 'package:core_network/core_network.dart';
import 'package:core_network/testing.dart';
import 'package:feature_auth/src/data/data_sources/auth_api.dart';
import 'package:feature_auth/src/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reference repository, exercised end to end from Retrofit down.
///
/// Its own comment says "copy this shape for every new repository", which makes
/// its behaviour the template: the call goes through `guard`, the DTO becomes an
/// entity, nothing throws. A repository that throws breaks rule 1 for every
/// layer above it, and the only way to see that is to make the transport fail.
///
/// The other thing under test is `devAuthBypass`. It fakes authentication
/// outright — the login button succeeds regardless of what was typed — and its
/// only guard is a flag. A regression that leaves it on in a release build
/// ships an app anyone can sign into.
void main() {
  const config = AppEnvironmentConfig(environment: AppEnvironment.dev, baseUrl: 'https://api.example.com');

  const sessionJson =
      '{"access_token":"access","refresh_token":"refresh","expires_in":3600,'
      '"user":{"id":"u1","email":"a@b.com","display_name":"Tester"}}';
  const userJson = '{"id":"u1","email":"a@b.com","display_name":"Tester"}';

  ({AuthRepositoryImpl repository, StubHttpAdapter adapter}) build({
    Map<String, Object>? outcomes,
    AppEnvironmentConfig environment = config,
  }) {
    final adapter = StubHttpAdapter.paths(
      outcomes ??
          {
            '/auth/login': jsonResponse(sessionJson),
            '/auth/logout': jsonResponse('{}'),
            '/auth/me': jsonResponse(userJson),
          },
    );
    final dio = Dio(BaseOptions(baseUrl: config.baseUrl))..httpClientAdapter = adapter;
    return (
      repository: AuthRepositoryImpl(AuthApi(dio), environment, const PassthroughFailureMapper()),
      adapter: adapter,
    );
  }

  group('signIn', () {
    test('maps the response DTO to an entity', () async {
      final subject = build();

      final result = await subject.repository.signIn(email: 'a@b.com', password: 'secret');

      expect(result.isOk, isTrue);
      expect(result.valueOrNull?.accessToken, 'access');
      expect(result.valueOrNull?.user.email, 'a@b.com');
    });

    test('sends the credentials in the request body', () async {
      final subject = build();

      await subject.repository.signIn(email: 'a@b.com', password: 'secret');

      final body = subject.adapter.requests.single.data.toString();
      expect(body, contains('a@b.com'));
      expect(body, contains('secret'));
    });

    test('a 401 becomes an Err, not a thrown exception', () async {
      // Rule 1: nothing above the data layer throws. If `guard` were removed
      // the exception would escape into a use case and then into a bloc, where
      // no `try/catch` exists to receive it.
      final subject = build(outcomes: {'/auth/login': jsonResponse('{"message":"bad password"}', status: 401)});

      final result = await subject.repository.signIn(email: 'a@b.com', password: 'wrong');

      expect(result.isErr, isTrue);
    });

    test('a transport failure becomes an Err too', () async {
      final subject = build(
        outcomes: {
          '/auth/login': DioException(
            requestOptions: RequestOptions(path: '/auth/login'),
            type: DioExceptionType.connectionError,
          ),
        },
      );

      final result = await subject.repository.signIn(email: 'a@b.com', password: 'secret');

      expect(result.isErr, isTrue);
    });

    test('a malformed success body becomes an Err rather than a crash', () async {
      // A backend that renames a field must produce a failed login, not an
      // uncaught `TypeError` on the first frame after the button is tapped.
      final subject = build(outcomes: {'/auth/login': jsonResponse('{"unexpected":true}')});

      final result = await subject.repository.signIn(email: 'a@b.com', password: 'secret');

      expect(result.isErr, isTrue);
    });
  });

  group('devAuthBypass', () {
    const bypass = AppEnvironmentConfig(
      environment: AppEnvironment.dev,
      baseUrl: 'https://api.example.com',
      devAuthBypass: true,
    );

    test('succeeds without any network call', () async {
      // The flag's whole purpose, and the assertion that matters is the *absence*
      // of a request: a bypass that still calls the API would fail offline,
      // which is the situation it exists for.
      final subject = build(environment: bypass);

      final result = await subject.repository.signIn(email: 'anything', password: 'anything');

      expect(result.isOk, isTrue);
      expect(subject.adapter.requests, isEmpty);
    });

    test('succeeds even when the endpoint would reject the credentials', () async {
      final subject = build(
        environment: bypass,
        outcomes: {'/auth/login': jsonResponse('{"message":"bad password"}', status: 401)},
      );

      expect((await subject.repository.signIn(email: 'x', password: 'y')).isOk, isTrue);
    });

    test('is off by default, so the network is what decides', () async {
      // The guard that stops a fake session reaching a real build. `config` has
      // no `devAuthBypass`, so a rejected password must fail.
      final subject = build(outcomes: {'/auth/login': jsonResponse('{"message":"bad"}', status: 401)});

      expect((await subject.repository.signIn(email: 'x', password: 'y')).isErr, isTrue);
      expect(subject.adapter.callsTo('/auth/login'), 1);
    });
  });

  group('signOut', () {
    test('calls the endpoint and reports success', () async {
      final subject = build();

      final result = await subject.repository.signOut();

      expect(result, const Ok<Unit>(unit));
      expect(subject.adapter.callsTo('/auth/logout'), 1);
    });

    test('a server error becomes an Err rather than throwing', () async {
      // `SignOutUseCase` clears local state first and then calls this, so a
      // failure here must not prevent the user from ending up signed out.
      final subject = build(outcomes: {'/auth/logout': jsonResponse('{}', status: 500)});

      expect((await subject.repository.signOut()).isErr, isTrue);
    });
  });

  group('currentUser', () {
    test('maps the user DTO to an entity', () async {
      final subject = build();

      final result = await subject.repository.currentUser();

      expect(result.valueOrNull?.id, 'u1');
      expect(result.valueOrNull?.displayName, 'Tester');
    });

    test('a 403 becomes an Err', () async {
      final subject = build(outcomes: {'/auth/me': jsonResponse('{"message":"nope"}', status: 403)});

      expect((await subject.repository.currentUser()).isErr, isTrue);
    });
  });
}
