import 'dart:async';

import 'package:core_network/core_network.dart';
// The stub adapter needs Dio's transport internals, which the barrel
// deliberately does not re-export.
import 'package:dio/dio.dart' show HttpClientAdapter, ResponseBody;
import 'package:flutter_test/flutter_test.dart';

/// Records what the session was asked to do so the tests can assert on the
/// *number* of refreshes, which is the whole point of the interceptor.
final class _FakeSessionDelegate implements AuthSessionDelegate {
  _FakeSessionDelegate({this.refreshSucceeds = true});

  bool refreshSucceeds;
  String? token = 'expired-token';
  int refreshCalls = 0;
  int expiredCalls = 0;
  Completer<void>? gateRefresh;

  @override
  Future<String?> accessToken() async => token;

  @override
  Future<bool> refreshSession() async {
    refreshCalls++;
    // Lets a test hold every concurrent caller inside one refresh.
    if (gateRefresh != null) await gateRefresh!.future;
    if (refreshSucceeds) token = 'fresh-token';
    return refreshSucceeds;
  }

  @override
  Future<void> onSessionExpired() async => expiredCalls++;

  @override
  bool isPublicEndpoint(RequestOptions options) => options.path.startsWith('/auth/');
}

/// Serves canned responses and counts hits per path, so a test can tell an
/// original request from its replay.
final class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options, int hit) handler;
  final Map<String, int> hits = {};

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) {
    final count = (hits[options.path] ?? 0) + 1;
    hits[options.path] = count;
    return handler(options, count);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, String body) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

({Dio dio, Dio raw, _StubAdapter adapter}) _buildClient(
  _FakeSessionDelegate delegate,
  Future<ResponseBody> Function(RequestOptions options, int hit) handler,
) {
  final adapter = _StubAdapter(handler);
  final raw = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = adapter
    ..interceptors.add(AuthInterceptor(delegate: delegate, retryClient: raw));
  return (dio: dio, raw: raw, adapter: adapter);
}

void main() {
  group('AuthInterceptor', () {
    test('attaches the bearer token to protected requests', () async {
      final delegate = _FakeSessionDelegate()..token = 'abc123';
      String? seen;
      final client = _buildClient(delegate, (options, hit) async {
        seen = options.headers['Authorization'] as String?;
        return _json(200, '{}');
      });

      await client.dio.get<dynamic>('/v1/profile');
      expect(seen, 'Bearer abc123');
    });

    test('leaves public endpoints unauthenticated', () async {
      final delegate = _FakeSessionDelegate()..token = 'abc123';
      String? seen;
      final client = _buildClient(delegate, (options, hit) async {
        seen = options.headers['Authorization'] as String?;
        return _json(200, '{}');
      });

      await client.dio.post<dynamic>('/auth/login');
      expect(seen, isNull);
    });

    test('refreshes once on 401 and replays the original request', () async {
      final delegate = _FakeSessionDelegate();
      final client = _buildClient(delegate, (options, hit) async {
        // First attempt 401s; the replay carries the refreshed token.
        if (hit == 1) return _json(401, '{"message":"expired"}');
        expect(options.headers['Authorization'], 'Bearer fresh-token');
        return _json(200, '{"ok":true}');
      });

      final response = await client.dio.get<dynamic>('/v1/profile');
      expect(response.statusCode, 200);
      expect(delegate.refreshCalls, 1);
      expect(client.adapter.hits['/v1/profile'], 2);
    });

    test('collapses concurrent 401s into a single refresh', () async {
      // The regression this guards: one refresh per in-flight request rotates
      // the refresh token N times and the backend invalidates the session.
      final delegate = _FakeSessionDelegate()..gateRefresh = Completer<void>();
      final client = _buildClient(delegate, (options, hit) async {
        if (options.headers['Authorization'] == 'Bearer fresh-token') return _json(200, '{}');
        return _json(401, '{}');
      });

      final pending = Future.wait([
        client.dio.get<dynamic>('/v1/a'),
        client.dio.get<dynamic>('/v1/b'),
        client.dio.get<dynamic>('/v1/c'),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      delegate.gateRefresh!.complete();
      final responses = await pending;

      expect(responses.every((r) => r.statusCode == 200), isTrue);
      expect(delegate.refreshCalls, 1);
    });

    test('gives up and reports session expiry when the refresh fails', () async {
      final delegate = _FakeSessionDelegate(refreshSucceeds: false);
      final client = _buildClient(delegate, (options, hit) async => _json(401, '{}'));

      await expectLater(client.dio.get<dynamic>('/v1/profile'), throwsA(isA<DioException>()));
      expect(delegate.refreshCalls, 1);
      expect(delegate.expiredCalls, 1);
    });

    test('does not loop when the replayed request also returns 401', () async {
      final delegate = _FakeSessionDelegate();
      final client = _buildClient(delegate, (options, hit) async => _json(401, '{}'));

      await expectLater(client.dio.get<dynamic>('/v1/profile'), throwsA(isA<DioException>()));
      // Exactly one refresh and one replay — the retried flag stops the cycle.
      expect(delegate.refreshCalls, 1);
      expect(client.adapter.hits['/v1/profile'], 2);
    });

    test('never refreshes when a public endpoint returns 401', () async {
      // A wrong password must surface as a 401 to the login screen, not start
      // a refresh loop.
      final delegate = _FakeSessionDelegate();
      final client = _buildClient(delegate, (options, hit) async => _json(401, '{"code":"BAD_CREDENTIALS"}'));

      await expectLater(client.dio.post<dynamic>('/auth/login'), throwsA(isA<DioException>()));
      expect(delegate.refreshCalls, 0);
      expect(delegate.expiredCalls, 0);
    });

    test('passes non-401 errors straight through', () async {
      final delegate = _FakeSessionDelegate();
      final client = _buildClient(delegate, (options, hit) async => _json(500, '{}'));

      await expectLater(client.dio.get<dynamic>('/v1/profile'), throwsA(isA<DioException>()));
      expect(delegate.refreshCalls, 0);
    });
  });
}
