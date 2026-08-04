import 'package:core_kit/core_kit.dart';
import 'package:core_network/core_network.dart';
import 'package:core_network/testing.dart';
import 'package:feature_auth/src/data/data_sources/token_refresh_api.dart';
import 'package:feature_auth/src/data/session/session_auth_delegate.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_auth.dart';

/// The adapter `core_network` calls on a 401.
///
/// `isPublicEndpoint` is what the class comment calls the classic auth bug:
/// omit `/auth/login` and a wrong password 401s, triggers a refresh, fails, and
/// retries forever. It is a `Set` of prefixes matched with `startsWith` — easy
/// to change, and impossible to notice breaking without a test, because the
/// symptom is the app spinning on a bad password rather than an error anywhere.
///
/// The refresh path runs through the **real** `TokenRefreshApi` with a stubbed
/// adapter underneath, not a fake API. `TokenRefreshApi` is `final` and builds
/// its own bare `Dio` on purpose — that is what stops a refresh from re-entering
/// the auth interceptor — so stubbing the transport is the only way in, and it
/// is also the better one: the request body, the DTO parse and the failure
/// mapping are exercised instead of being replaced by a fake that agrees.
void main() {
  const baseUrl = 'https://api.example.com';

  /// The wire shape, snake_case, exactly as `AuthSessionDto`'s `@JsonKey`s
  /// declare it — so the parse is real. Writing it in camelCase silently
  /// produces a DTO with missing required fields, which is how a fixture ends
  /// up testing the failure path while claiming to test the success one.
  const refreshed =
      '{"access_token":"new-access","refresh_token":"new-refresh","expires_in":3600,'
      '"user":{"id":"u1","email":"a@b.com","display_name":"Tester"}}';

  late FakeSessionStore store;

  setUp(() => store = FakeSessionStore());
  tearDown(() => store.dispose());

  ({SessionAuthDelegate delegate, StubHttpAdapter adapter}) build({Object? outcome, AppLogger? logger}) {
    final adapter = StubHttpAdapter.always(outcome ?? jsonResponse(refreshed));
    final dio = Dio(BaseOptions(baseUrl: baseUrl))..httpClientAdapter = adapter;
    final api = TokenRefreshApi.withClient(dio, const PassthroughFailureMapper());
    return (delegate: SessionAuthDelegate(store, api, logger: logger ?? const NoopLogger()), adapter: adapter);
  }

  group('isPublicEndpoint', () {
    bool isPublic(String path) => build().delegate.isPublicEndpoint(RequestOptions(path: path));

    test('login, refresh and register are public', () {
      // Each of these 401s legitimately. Treating any as authenticated turns a
      // wrong password into an infinite refresh loop.
      expect(isPublic('/auth/login'), isTrue);
      expect(isPublic('/auth/refresh'), isTrue);
      expect(isPublic('/auth/register'), isTrue);
    });

    test('the /public/ prefix matches anything beneath it', () {
      expect(isPublic('/public/config'), isTrue);
      expect(isPublic('/public/terms/v2'), isTrue);
    });

    test('an authenticated path is not public', () {
      expect(isPublic('/me'), isFalse);
      expect(isPublic('/orders/42'), isFalse);
      // Sits under /auth but is not in the list, and must carry a token.
      expect(isPublic('/auth/logout'), isFalse);
    });

    test('matching is anchored at the start of the path', () {
      // `startsWith` is what makes the `/public/` entry work. Documenting the
      // consequence rather than leaving the next reader to find it: a path that
      // merely begins with a listed prefix is also treated as public.
      expect(isPublic('/auth/loginhistory'), isTrue, reason: 'documents prefix semantics, does not endorse them');
      expect(isPublic('/v2/auth/login'), isFalse, reason: 'a prefix is anchored, not searched for');
    });
  });

  group('accessToken', () {
    test('is the stored token when signed in', () async {
      store.saved = FakeAuthRepository.session();

      expect(await build().delegate.accessToken(), 'access-token');
    });

    test('is null when signed out, rather than an empty string', () async {
      // `AuthInterceptor` checks for null *and* blank before attaching the
      // header; returning '' here would send `Authorization: Bearer `.
      expect(await build().delegate.accessToken(), isNull);
    });
  });

  group('refreshSession', () {
    test('returns false without touching the network when there is no session', () async {
      // Nothing to refresh. Calling anyway wastes a round trip on every
      // unauthenticated 401.
      final subject = build();

      expect(await subject.delegate.refreshSession(), isFalse);
      expect(subject.adapter.requests, isEmpty);
    });

    test('exchanges the refresh token and stores the new session', () async {
      store.saved = FakeAuthRepository.session();
      final subject = build();

      final result = await subject.delegate.refreshSession();
      await pumpEventQueue();

      expect(result, isTrue);
      expect(subject.adapter.callsTo('/auth/refresh'), 1);
      expect(subject.adapter.requests.single.data.toString(), contains('refresh-token'));
      // The *new* tokens are persisted, not the old ones — the whole point.
      expect(store.saved?.accessToken, 'new-access');
      expect(store.saved?.refreshToken, 'new-refresh');
    });

    test('a rejected refresh token returns false and is logged, not thrown', () async {
      // It runs inside a Dio interceptor. Throwing escapes as an unhandled
      // error rather than reaching the caller's `Result`.
      store.saved = FakeAuthRepository.session();
      final logger = InMemoryLogger();
      final subject = build(outcome: jsonResponse('{"message":"expired"}', status: 401), logger: logger);

      expect(await subject.delegate.refreshSession(), isFalse);
      expect(logger.records.single.message, contains('token refresh failed'));
      expect(logger.records.single.level, LogLevel.warning);
    });

    test('a transport failure returns false rather than propagating', () async {
      store.saved = FakeAuthRepository.session();
      final logger = InMemoryLogger();
      final subject = build(
        outcome: DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          type: DioExceptionType.connectionError,
        ),
        logger: logger,
      );

      expect(await subject.delegate.refreshSession(), isFalse);
      expect(logger.records, hasLength(1));
    });

    test('the log line does not leak either token', () async {
      store.saved = FakeAuthRepository.session();
      final logger = InMemoryLogger();
      final subject = build(outcome: jsonResponse('{}', status: 500), logger: logger);

      await subject.delegate.refreshSession();

      expect(logger.records.single.message, isNot(contains('refresh-token')));
      expect(logger.records.single.message, isNot(contains('access-token')));
    });

    test('an unparseable success body fails closed instead of storing garbage', () async {
      // A backend that changes the response shape must not leave the app
      // believing it holds a valid session.
      store.saved = FakeAuthRepository.session();
      final subject = build(outcome: jsonResponse('{"unexpected":true}'));

      expect(await subject.delegate.refreshSession(), isFalse);
      expect(store.saved?.accessToken, 'access-token', reason: 'the old session is left untouched');
    });
  });

  group('onSessionExpired', () {
    test('clears the stored session', () async {
      // The host listens on the store and routes back to login; clearing is the
      // only thing the transport layer is allowed to do about an expiry.
      store.saved = FakeAuthRepository.session();

      await build().delegate.onSessionExpired();

      expect(store.saved, isNull);
    });

    test('is safe when there is nothing to clear', () async {
      await expectLater(build().delegate.onSessionExpired(), completes);
    });
  });
}
