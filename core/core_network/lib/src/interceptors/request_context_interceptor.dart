import 'package:core_network/src/auth_session_delegate.dart';
import 'package:dio/dio.dart';

/// Adds the app's standard headers (device id, app version, locale) to every
/// outbound request, sourced from an inverted [RequestContextProvider].
///
/// Headers already set on the request win, so a single call can override the
/// default without a special-case flag.
final class RequestContextInterceptor extends Interceptor {
  const RequestContextInterceptor(this._provider);

  final RequestContextProvider _provider;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final headers = await _provider.headers();
    for (final entry in headers.entries) {
      options.headers.putIfAbsent(entry.key, () => entry.value);
    }
    handler.next(options);
  }
}
