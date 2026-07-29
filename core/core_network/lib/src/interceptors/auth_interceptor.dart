import 'dart:async';

import 'package:core_kit/core_kit.dart';
import 'package:core_network/src/auth_session_delegate.dart';
import 'package:dio/dio.dart';

/// Attaches the bearer token and recovers from a 401 exactly once per request.
///
/// The hard part is concurrency: when the token expires, every in-flight
/// request fails with 401 at the same moment. A naive implementation fires one
/// refresh per failed request, which at best wastes calls and at worst makes
/// the backend rotate the refresh token N times and invalidate the session.
/// [_refreshInFlight] collapses them into a single refresh that all waiters
/// await.
final class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required AuthSessionDelegate delegate,
    required Dio retryClient,
    AppLogger logger = const NoopLogger(),
  }) : _delegate = delegate,
       _retryClient = retryClient,
       _logger = logger;

  static const String _retriedFlag = 'core_network.retried_after_refresh';

  final AuthSessionDelegate _delegate;

  /// A client **without** this interceptor, used to replay the original
  /// request. Replaying through the same client would re-enter the 401 path.
  final Dio _retryClient;

  final AppLogger _logger;

  Future<bool>? _refreshInFlight;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (_delegate.isPublicEndpoint(options)) return handler.next(options);

    final token = await _delegate.accessToken();
    if (token != null && token.isNotBlank) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = options.extra[_retriedFlag] == true;

    if (!isUnauthorized || alreadyRetried || _delegate.isPublicEndpoint(options)) {
      return handler.next(err);
    }

    final refreshed = await _refreshOnce();
    if (!refreshed) {
      await _delegate.onSessionExpired();
      return handler.next(err);
    }

    try {
      // Mark before replaying: if the replay also 401s, the flag stops a loop.
      options.extra[_retriedFlag] = true;
      final token = await _delegate.accessToken();
      if (token != null && token.isNotBlank) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      final response = await _retryClient.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  /// Runs at most one refresh at a time; concurrent callers await the same one.
  Future<bool> _refreshOnce() {
    final pending = _refreshInFlight;
    if (pending != null) return pending;

    final future = _delegate
        .refreshSession()
        .catchError((Object error) {
          _logger.warning('token refresh threw', tag: 'auth', error: error);
          return false;
        })
        .whenComplete(() => _refreshInFlight = null);

    _refreshInFlight = future;
    return future;
  }
}
