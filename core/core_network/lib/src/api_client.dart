import 'package:core_kit/core_kit.dart';
import 'package:core_network/src/auth_session_delegate.dart';
import 'package:core_network/src/interceptors/auth_interceptor.dart';
import 'package:core_network/src/interceptors/connectivity_interceptor.dart';
import 'package:core_network/src/interceptors/logging_interceptor.dart';
import 'package:core_network/src/interceptors/request_context_interceptor.dart';
import 'package:core_network/src/interceptors/retry_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// The app's HTTP entry point: one configured [Dio] plus the bare client used
/// for token refresh and request replay.
///
/// Interceptor order is deliberate and load-bearing:
///   1. request context — headers every request needs, including retries;
///   2. auth — attaches the token, and on 401 refreshes and replays;
///   3. retry — backoff for transport blips;
///   4. logging — last, so what it prints is what actually went on the wire.
///
/// Retry sits *after* auth so a 401 is resolved by refreshing rather than by
/// hammering the same expired token three times.
final class ApiClient {
  ApiClient({
    required AppEnvironmentConfig config,
    AuthSessionDelegate authDelegate = const NoAuthSessionDelegate(),
    RequestContextProvider contextProvider = const EmptyRequestContextProvider(),
    ConnectivityMonitor connectivityMonitor = const NoopConnectivityMonitor(),
    AppLogger logger = const NoopLogger(),
  }) : _config = config,
       _logger = logger {
    _raw = _createDio(config);
    _dio = _createDio(config)
      ..interceptors.addAll([
        RequestContextInterceptor(contextProvider),
        AuthInterceptor(delegate: authDelegate, retryClient: _raw, logger: logger),
        RetryInterceptor(client: _raw, logger: logger),
        // After retry: the outcome that matters for connectivity is the final
        // one. Reporting each failed attempt would flip the banner to offline
        // during a retry that is about to succeed.
        ConnectivityInterceptor(connectivityMonitor),
        if (config.enableNetworkLogging) LoggingInterceptor(logger: logger),
      ]);
  }

  final AppEnvironmentConfig _config;
  final AppLogger _logger;

  late final Dio _dio;
  late final Dio _raw;

  /// The authenticated client every data source should use.
  Dio get dio => _dio;

  /// No auth, no retry, no logging. Only for the refresh call itself — using
  /// [dio] there would re-enter the 401 handler and recurse.
  Dio get rawDio => _raw;

  AppEnvironmentConfig get config => _config;

  Dio _createDio(AppEnvironmentConfig config) => Dio(
    BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      sendTimeout: config.sendTimeout,
      headers: const {'Accept': 'application/json'},
      contentType: Headers.jsonContentType,
      // Let every status through to the failure mapper. Dio's default throws
      // before the response body is read, discarding the error envelope that
      // carries the business code the UI needs.
      validateStatus: (status) => status != null && status < 400,
    ),
  );

  /// Drops pooled keep-alive connections.
  ///
  /// Needed after the device changes network (VPN on, wifi to cellular): the
  /// pooled sockets are bound to the old route and hang until timeout.
  /// `httpClientAdapter.close()` alone is one-way — later requests would throw
  /// — so the adapter is replaced rather than merely closed.
  void resetConnectionPool() {
    _logger.info('resetting connection pool', tag: 'http');
    for (final client in [_dio, _raw]) {
      client.httpClientAdapter.close(force: true);
      client.httpClientAdapter = IOHttpClientAdapter();
    }
  }

  void close({bool force = false}) {
    _dio.close(force: force);
    _raw.close(force: force);
  }
}
