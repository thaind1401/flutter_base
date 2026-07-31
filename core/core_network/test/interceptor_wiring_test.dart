import 'package:core_kit/core_kit.dart';
import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two small interceptors and the client that assembles them.
///
/// `ConnectivityInterceptor` is the reason the offline banner is accurate
/// without polling: every response the app already makes is a free probe. Its
/// whole value is in *which* outcomes count as proof, and getting that wrong is
/// invisible until a backend outage puts a "check your wifi" banner over it.
///
/// `ApiClient` decides interceptor order, and the order is load-bearing: retry
/// sits after auth so a 401 is resolved by refreshing rather than by hammering
/// the same expired token three times.

/// Records what the transport reported, so a test can assert on the sequence
/// rather than on a final state that hides an intermediate flip.
final class _RecordingMonitor implements ConnectivityMonitor {
  final List<bool> reports = [];

  @override
  ConnectivityStatus get status => ConnectivityStatus.online;

  @override
  bool get isOffline => false;

  @override
  Stream<ConnectivityStatus> get changes => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<ConnectivityStatus> check() async => ConnectivityStatus.online;

  @override
  void reportUnreachable() => reports.add(false);

  @override
  void reportReachable() => reports.add(true);

  @override
  Future<void> dispose() async {}
}

final class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.outcome);

  final Object outcome;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) {
    if (outcome is ResponseBody) return Future.value(outcome as ResponseBody);
    return Future.error(outcome);
  }

  @override
  void close({bool force = false}) {}
}

final class _StaticContextProvider implements RequestContextProvider {
  const _StaticContextProvider(this.value);

  final Map<String, String> value;

  @override
  Future<Map<String, String>> headers() async => value;
}

void main() {
  RequestOptions options({Map<String, Object?>? headers}) =>
      RequestOptions(path: '/things', headers: headers ?? <String, Object?>{});

  group('ConnectivityInterceptor', () {
    late _RecordingMonitor monitor;
    late ConnectivityInterceptor interceptor;

    setUp(() {
      monitor = _RecordingMonitor();
      interceptor = ConnectivityInterceptor(monitor);
    });

    void feedError(DioExceptionType type, {int? statusCode}) {
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter(
          statusCode == null
              ? DioException(
                  requestOptions: RequestOptions(path: '/things'),
                  type: type,
                )
              : ResponseBody.fromString('{}', statusCode),
        )
        ..interceptors.add(interceptor);
      expectLater(dio.get<dynamic>('/things'), throwsA(isA<DioException>()));
    }

    test('a successful response proves the network works', () {
      interceptor.onResponse(
        Response<dynamic>(requestOptions: options(), statusCode: 200),
        ResponseInterceptorHandler(),
      );

      expect(monitor.reports, [true]);
    });

    test('a connection error reports unreachable', () async {
      feedError(DioExceptionType.connectionError);
      await pumpEventQueue();

      expect(monitor.reports, [false]);
    });

    test('a connection timeout reports unreachable', () async {
      feedError(DioExceptionType.connectionTimeout);
      await pumpEventQueue();

      expect(monitor.reports, [false]);
    });

    test('a 500 reports REACHABLE, not offline', () async {
      // The server answered. Treating a backend outage as "no connection" sends
      // everyone to check their wifi over a problem they cannot affect, and it
      // is the single easiest thing to get backwards here.
      feedError(DioExceptionType.badResponse, statusCode: 500);
      await pumpEventQueue();

      expect(monitor.reports, [true]);
    });

    test('ambiguous failures report nothing at all', () async {
      // A slow upload, a proxy, a cancelled request: none of these say anything
      // certain about connectivity, and guessing flickers the banner.
      for (final type in [
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.badCertificate,
        DioExceptionType.cancel,
        DioExceptionType.unknown,
      ]) {
        monitor.reports.clear();
        feedError(type);
        await pumpEventQueue();

        expect(monitor.reports, isEmpty, reason: '$type must not be treated as a connectivity signal');
      }
    });
  });

  group('RequestContextInterceptor', () {
    test('adds the provider headers to a request', () async {
      const interceptor = RequestContextInterceptor(
        _StaticContextProvider({'X-Device-Id': 'abc', 'X-App-Version': '1.2.3'}),
      );
      final request = options();

      await interceptor.onRequest(request, RequestInterceptorHandler());

      expect(request.headers['X-Device-Id'], 'abc');
      expect(request.headers['X-App-Version'], '1.2.3');
    });

    test('a header already on the request wins', () async {
      // `putIfAbsent`, so a single call can override a default without the
      // interceptor needing a special-case flag.
      const interceptor = RequestContextInterceptor(_StaticContextProvider({'X-App-Version': 'default'}));
      final request = options(headers: {'X-App-Version': 'explicit'});

      await interceptor.onRequest(request, RequestInterceptorHandler());

      expect(request.headers['X-App-Version'], 'explicit');
    });

    test('an empty provider is a no-op', () async {
      const interceptor = RequestContextInterceptor(EmptyRequestContextProvider());
      final request = options();

      await interceptor.onRequest(request, RequestInterceptorHandler());

      expect(request.headers, isEmpty);
    });
  });

  group('NoAuthSessionDelegate', () {
    const delegate = NoAuthSessionDelegate();

    test('attaches nothing and treats everything as public', () async {
      // The default when no auth is wired up. Returning false from
      // `isPublicEndpoint` here would make every 401 attempt a refresh that
      // cannot succeed, which is an infinite loop rather than a failed call.
      expect(await delegate.accessToken(), isNull);
      expect(await delegate.refreshSession(), isFalse);
      expect(delegate.isPublicEndpoint(options()), isTrue);
      await expectLater(delegate.onSessionExpired(), completes);
    });
  });

  group('ApiClient', () {
    const config = AppEnvironmentConfig(environment: AppEnvironment.dev, baseUrl: 'https://api.example.com');

    test('applies the config to the authenticated client', () {
      final client = ApiClient(config: config);
      addTearDown(client.close);

      expect(client.dio.options.baseUrl, 'https://api.example.com');
      expect(client.dio.options.connectTimeout, config.connectTimeout);
      expect(client.config, config);
    });

    /// Dio installs its own `ImplyContentTypeInterceptor` at index 0 on every
    /// client it creates. It is not ours and not something this package
    /// controls, so it is filtered out rather than baked into the expectations
    /// — pinning it would turn a Dio upgrade into a failure in this file.
    List<Type> appInterceptors(Dio dio) =>
        dio.interceptors.map((i) => i.runtimeType).where((t) => t.toString() != 'ImplyContentTypeInterceptor').toList();

    test('rawDio carries none of our interceptors', () {
      // Load-bearing: the refresh call and every replay go out on this one.
      // A single one of ours here re-enters the 401 handler and recurses.
      final client = ApiClient(config: config);
      addTearDown(client.close);

      expect(appInterceptors(client.rawDio), isEmpty);
      expect(client.rawDio, isNot(same(client.dio)));
    });

    test('interceptor order is context, auth, retry, connectivity', () {
      // Retry after auth, so an expired token is refreshed rather than retried
      // three times unchanged. Connectivity after retry, so the banner reflects
      // the final outcome instead of flipping during a retry that succeeds.
      final client = ApiClient(config: config);
      addTearDown(client.close);

      expect(appInterceptors(client.dio), [
        RequestContextInterceptor,
        AuthInterceptor,
        RetryInterceptor,
        ConnectivityInterceptor,
      ]);
    });

    test('the logging interceptor is absent unless the config enables it', () {
      // Not a `kDebugMode` check inside the interceptor — the whole thing is
      // left out, so a production build has no logging path to accidentally
      // re-enable.
      final quiet = ApiClient(config: config);
      final loud = ApiClient(
        config: const AppEnvironmentConfig(
          environment: AppEnvironment.dev,
          baseUrl: 'https://api.example.com',
          enableNetworkLogging: true,
        ),
      );
      addTearDown(quiet.close);
      addTearDown(loud.close);

      expect(quiet.dio.interceptors.whereType<LoggingInterceptor>(), isEmpty);
      expect(loud.dio.interceptors.whereType<LoggingInterceptor>(), hasLength(1));
    });

    test('4xx and 5xx reach the failure mapper instead of being thrown early', () {
      // Dio's default `validateStatus` throws before the body is read, which
      // discards the error envelope carrying the business code the UI needs.
      final client = ApiClient(config: config);
      addTearDown(client.close);

      final validate = client.dio.options.validateStatus;
      expect(validate(200), isTrue);
      expect(validate(399), isTrue);
      expect(validate(400), isFalse);
      expect(validate(500), isFalse);
    });

    test('resetConnectionPool leaves both clients usable', () {
      // `httpClientAdapter.close()` alone is one-way and later requests throw,
      // so the adapter is replaced rather than merely closed.
      final client = ApiClient(config: config);
      addTearDown(client.close);
      final beforeDio = client.dio.httpClientAdapter;
      final beforeRaw = client.rawDio.httpClientAdapter;

      client.resetConnectionPool();

      // Both clients, and both must be *replaced* rather than merely closed —
      // `httpClientAdapter.close()` is one-way, so a client left holding the
      // closed adapter throws on its next request. `rawDio` matters as much as
      // `dio`: it is what the token refresh and every retry replay go out on,
      // so a half-reset leaves auth broken after a network change.
      expect(client.dio.httpClientAdapter, isNot(same(beforeDio)));
      expect(client.rawDio.httpClientAdapter, isNot(same(beforeRaw)));
      expect(client.dio.httpClientAdapter, isNot(same(client.rawDio.httpClientAdapter)));
    });
  });
}
