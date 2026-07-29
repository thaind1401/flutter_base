import 'dart:async';
import 'dart:math';

import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart' show HttpClientAdapter, ResponseBody;
import 'package:flutter_test/flutter_test.dart';

/// Counts attempts per path and lets a test decide what each one returns.
final class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options, int attempt) handler;
  final Map<String, int> attempts = {};

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) {
    final count = (attempts[options.path] ?? 0) + 1;
    attempts[options.path] = count;
    return handler(options, count);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, [String body = '{}']) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Future<ResponseBody> _connectionError(RequestOptions options) =>
    Future<ResponseBody>.error(DioException(requestOptions: options, type: DioExceptionType.connectionError));

({Dio dio, _StubAdapter adapter}) _client(
  Future<ResponseBody> Function(RequestOptions options, int attempt) handler, {
  int maxAttempts = 3,
}) {
  final adapter = _StubAdapter(handler);
  final raw = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = adapter
    ..interceptors.add(
      RetryInterceptor(
        client: raw,
        maxAttempts: maxAttempts,
        // Near-zero backoff, and a seeded Random so the jitter cannot make the
        // test flaky.
        baseDelay: const Duration(milliseconds: 1),
        maxDelay: const Duration(milliseconds: 4),
        random: Random(1),
      ),
    );
  return (dio: dio, adapter: adapter);
}

void main() {
  group('RetryInterceptor retries', () {
    test('a connection error on a GET, then succeeds', () async {
      final client = _client((options, attempt) async {
        if (attempt == 1) return _connectionError(options);
        return _json(200);
      });

      final response = await client.dio.get<dynamic>('/v1/items');

      expect(response.statusCode, 200);
      expect(client.adapter.attempts['/v1/items'], 2);
    });

    test('a 5xx on a GET', () async {
      final client = _client((options, attempt) async => attempt < 3 ? _json(503) : _json(200));

      final response = await client.dio.get<dynamic>('/v1/items');

      expect(response.statusCode, 200);
      expect(client.adapter.attempts['/v1/items'], 3);
    });

    test('timeouts', () async {
      final client = _client((options, attempt) async {
        if (attempt == 1) {
          return Future<ResponseBody>.error(
            DioException(requestOptions: options, type: DioExceptionType.receiveTimeout),
          );
        }
        return _json(200);
      });

      expect((await client.dio.get<dynamic>('/v1/items')).statusCode, 200);
      expect(client.adapter.attempts['/v1/items'], 2);
    });

    test('stops after maxAttempts and surfaces the last error', () async {
      final client = _client((options, attempt) async => _connectionError(options), maxAttempts: 3);

      await expectLater(client.dio.get<dynamic>('/v1/items'), throwsA(isA<DioException>()));
      // Three total attempts, not three retries on top of the original.
      expect(client.adapter.attempts['/v1/items'], 3);
    });
  });

  group('RetryInterceptor does not retry', () {
    test('a POST, because replaying it can duplicate a server-side effect', () async {
      // This is the rule that keeps a flaky network from creating two orders.
      final client = _client((options, attempt) async => _connectionError(options));

      await expectLater(client.dio.post<dynamic>('/v1/orders'), throwsA(isA<DioException>()));
      expect(client.adapter.attempts['/v1/orders'], 1);
    });

    test('a 4xx, because a rejection is a decision and not a glitch', () async {
      final client = _client((options, attempt) async => _json(422));

      await expectLater(client.dio.get<dynamic>('/v1/items'), throwsA(isA<DioException>()));
      expect(client.adapter.attempts['/v1/items'], 1);
    });

    test('a 5xx on a POST', () async {
      final client = _client((options, attempt) async => _json(500));

      await expectLater(client.dio.post<dynamic>('/v1/orders'), throwsA(isA<DioException>()));
      expect(client.adapter.attempts['/v1/orders'], 1);
    });

    test('a cancellation', () async {
      final client = _client(
        (options, attempt) async =>
            Future<ResponseBody>.error(DioException(requestOptions: options, type: DioExceptionType.cancel)),
      );

      await expectLater(client.dio.get<dynamic>('/v1/items'), throwsA(isA<DioException>()));
      expect(client.adapter.attempts['/v1/items'], 1);
    });
  });

  group('RetryInterceptor opt-in and opt-out', () {
    test('a POST the caller marks idempotent is retried', () async {
      // For an endpoint with an idempotency key, replaying is safe and the
      // caller is the only one who knows that.
      final client = _client((options, attempt) async => attempt == 1 ? _connectionError(options) : _json(200));

      final response = await client.dio.post<dynamic>(
        '/v1/orders',
        options: Options(extra: {RetryInterceptor.retryableExtraKey: true}),
      );

      expect(response.statusCode, 200);
      expect(client.adapter.attempts['/v1/orders'], 2);
    });

    test('a GET the caller opts out of is not retried', () async {
      // For a poll that the caller reschedules itself, retrying doubles the load.
      final client = _client((options, attempt) async => _connectionError(options));

      await expectLater(
        client.dio.get<dynamic>('/v1/items', options: Options(extra: {RetryInterceptor.retryableExtraKey: false})),
        throwsA(isA<DioException>()),
      );
      expect(client.adapter.attempts['/v1/items'], 1);
    });
  });

  group('RetryInterceptor backoff', () {
    test('waits longer between successive attempts', () async {
      final timestamps = <DateTime>[];
      final adapter = _StubAdapter((options, attempt) async {
        timestamps.add(DateTime.now());
        return _connectionError(options);
      });
      final raw = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(
          RetryInterceptor(
            client: raw,
            maxAttempts: 3,
            baseDelay: const Duration(milliseconds: 60),
            maxDelay: const Duration(seconds: 5),
            random: Random(7),
          ),
        );

      await expectLater(dio.get<dynamic>('/v1/items'), throwsA(isA<DioException>()));

      expect(timestamps, hasLength(3), reason: 'maxAttempts: 3 means three total attempts');
      final firstGap = timestamps[1].difference(timestamps[0]).inMilliseconds;
      final secondGap = timestamps[2].difference(timestamps[1]).inMilliseconds;
      // Backoff doubles each round. Jitter randomises within [50%, 100%] of the
      // cap, so the assertion is on the ordering rather than on exact values —
      // without jitter every device that dropped connectivity at the same
      // moment would retry in lockstep and stampede the server as it recovers.
      expect(secondGap, greaterThan(firstGap));
    });
  });
}
