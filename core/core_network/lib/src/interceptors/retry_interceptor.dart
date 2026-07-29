import 'dart:async';
import 'dart:math';

import 'package:core_kit/core_kit.dart';
import 'package:dio/dio.dart';

/// Retries transient transport failures with exponential backoff and jitter.
///
/// Two deliberate restrictions:
///   * **idempotent methods only.** Retrying a POST can double-charge a card or
///     create two leave requests; a caller that knows its POST is safe opts in
///     per request via [retryableExtraKey].
///   * **transport failures only.** A 4xx is a decision, not a glitch, and a
///     5xx is retried only for read methods where a duplicate is harmless.
///
/// Jitter matters: without it, every device that lost connectivity at the same
/// moment retries in lockstep and stampedes the server as it recovers.
final class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio client,
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 8),
    AppLogger logger = const NoopLogger(),
    Random? random,
  }) : _client = client,
       _logger = logger,
       _random = random ?? Random();

  /// Set `options.extra[RetryInterceptor.retryableExtraKey] = true` to opt a
  /// non-idempotent request in, or `false` to opt a GET out.
  static const String retryableExtraKey = 'core_network.retryable';
  static const String _attemptKey = 'core_network.attempt';
  static const Set<String> _idempotentMethods = {'GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE'};

  final Dio _client;
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final AppLogger _logger;
  final Random _random;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_shouldRetry(err)) return handler.next(err);

    final options = err.requestOptions;
    var lastError = err;

    // The loop lives here rather than relying on re-entry through `onError`.
    // Replays go out on a client with no interceptors — that is deliberate, so
    // a retry cannot re-trigger auth or logging — but it also means this
    // interceptor is never invoked again for the replay. An earlier version
    // depended on that re-entry and therefore retried exactly once, whatever
    // `maxAttempts` said.
    for (var attempt = 1; attempt < maxAttempts; attempt++) {
      final delay = _backoff(attempt - 1);
      _logger.debug(
        'retry $attempt/${maxAttempts - 1} for ${options.method} ${options.path} in ${delay.inMilliseconds}ms',
        tag: 'http',
      );
      await Future<void>.delayed(delay);

      options.extra[_attemptKey] = attempt;
      try {
        return handler.resolve(await _client.fetch<dynamic>(options));
      } on DioException catch (retryError) {
        lastError = retryError;
        // A blip that turned into a real rejection (or a 401 after the token
        // lapsed mid-retry) must stop here and reach the caller.
        if (!_shouldRetry(retryError)) break;
      }
    }

    handler.next(lastError);
  }

  bool _shouldRetry(DioException err) {
    final optIn = err.requestOptions.extra[retryableExtraKey];
    if (optIn is bool) return optIn;

    if (!_idempotentMethods.contains(err.requestOptions.method.toUpperCase())) return false;

    return switch (err.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => true,
      DioExceptionType.badResponse => (err.response?.statusCode ?? 0) >= 500,
      _ => false,
    };
  }

  /// `base * 2^attempt`, capped, then randomised across [50%, 100%] of that.
  Duration _backoff(int attempt) {
    final exponential = baseDelay.inMilliseconds * pow(2, attempt).toInt();
    final capped = min(exponential, maxDelay.inMilliseconds);
    return Duration(milliseconds: capped ~/ 2 + _random.nextInt(max(1, capped ~/ 2)));
  }
}
