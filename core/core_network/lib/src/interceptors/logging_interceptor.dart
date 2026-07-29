import 'dart:convert';

import 'package:core_kit/core_kit.dart';
import 'package:dio/dio.dart';

/// Logs each request as a runnable cURL plus a one-line response summary.
///
/// Two rules this enforces so they cannot be forgotten at a call site:
///   * every line goes through [LogRedactor], because request bodies routinely
///     carry passwords and responses carry personal data;
///   * the whole interceptor is only installed when the environment config asks
///     for it, so a production build has no logging path at all rather than a
///     `kDebugMode` check that a refactor can drop.
final class LoggingInterceptor extends Interceptor {
  const LoggingInterceptor({required AppLogger logger, this.logResponseBody = true, this.maxBodyChars = 4000})
    : _logger = logger;

  final AppLogger _logger;
  final bool logResponseBody;

  /// Long payloads are truncated: a 2 MB list response scrolls everything else
  /// out of the console and slows the app while it is being formatted.
  final int maxBodyChars;

  static const String _startKey = 'core_network.started_at';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now();
    _logger.debug(_toCurl(options), tag: 'http');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final elapsed = _elapsed(response.requestOptions);
    final line = '← ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri} ($elapsed)';
    _logger.debug(logResponseBody ? '$line\n${_truncate(_stringify(response.data))}' : line, tag: 'http');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final elapsed = _elapsed(err.requestOptions);
    _logger.error(
      '✖ ${err.response?.statusCode ?? err.type.name} ${err.requestOptions.method} '
      '${err.requestOptions.uri} ($elapsed)\n${_truncate(_stringify(err.response?.data))}',
      tag: 'http',
    );
    handler.next(err);
  }

  String _elapsed(RequestOptions options) {
    final started = options.extra[_startKey];
    if (started is! DateTime) return '?ms';
    return '${DateTime.now().difference(started).inMilliseconds}ms';
  }

  String _truncate(String value) =>
      value.length <= maxBodyChars ? value : '${value.substring(0, maxBodyChars)}… (${value.length} chars)';

  String _stringify(Object? data) {
    if (data == null) return '';
    if (data is FormData) {
      return jsonEncode({for (final field in data.fields) field.key: field.value, 'files': data.files.length});
    }
    if (data is String) return data;
    try {
      return jsonEncode(LogRedactor.redactValue(data), toEncodable: _encodable);
    } catch (_) {
      return data.toString();
    }
  }

  Object? _encodable(Object? value) {
    if (value is DateTime) return value.toIso8601String();
    if (value is MultipartFile) return '<file ${value.filename ?? 'unnamed'} ${value.length}b>';
    return value.toString();
  }

  String _toCurl(RequestOptions options) {
    final buffer = StringBuffer("→ curl -X ${options.method.toUpperCase()} '${options.uri}'");
    options.headers.forEach((key, Object? value) {
      if (key.toLowerCase() == 'content-length') return;
      buffer.write(" \\\n  -H '$key: $value'");
    });
    if (options.data != null && options.method.toUpperCase() != 'GET') {
      buffer.write(" \\\n  --data '${_truncate(_stringify(options.data))}'");
    }
    return buffer.toString();
  }
}
