import 'dart:convert';

/// The error shape this base assumes a backend returns:
///
/// ```json
/// { "success": false, "code": "LEAVE_QUOTA_EXCEEDED", "message": "...",
///   "errors": { "cooldownRemainingSeconds": 265 }, "traceId": "..." }
/// ```
///
/// Parsing lives here, once, instead of being re-derived inside every
/// repository. When a project's backend differs, this is the single file to
/// adapt — [DioFailureMapper] and every repository above it stay untouched.
final class ApiErrorEnvelope {
  const ApiErrorEnvelope({this.code, this.message, this.traceId, this.errors = const {}, this.fieldErrors = const {}});

  final String? code;
  final String? message;
  final String? traceId;

  /// Free-form detail object, e.g. `{cooldownRemainingSeconds: 265}`.
  final Map<String, Object?> errors;

  /// Field-level validation messages, when the backend returns them.
  final Map<String, List<String>> fieldErrors;

  static const ApiErrorEnvelope empty = ApiErrorEnvelope();

  /// Tolerant by design: response bodies arrive as a decoded map, as a raw JSON
  /// string, as HTML from a proxy, or as nothing at all. None of those may
  /// throw — a parse failure here would mask the real error being reported.
  static ApiErrorEnvelope parse(Object? data) {
    final map = _asMap(data);
    if (map == null) {
      final text = data is String ? data.trim() : null;
      return ApiErrorEnvelope(message: (text == null || text.isEmpty) ? null : text);
    }

    // Some gateways nest the payload one level down under `data` or `error`.
    final nested = _asMap(map['error']) ?? _asMap(map['data']);

    String? pick(String key) {
      final value = map[key] ?? nested?[key];
      final text = value?.toString().trim();
      return (text == null || text.isEmpty) ? null : text;
    }

    final rawErrors = _asMap(map['errors']) ?? _asMap(nested?['errors']) ?? const {};
    return ApiErrorEnvelope(
      code: pick('code') ?? pick('errorCode'),
      message: pick('message') ?? pick('error_description'),
      traceId: pick('traceId') ?? pick('trace_id') ?? pick('requestId'),
      errors: rawErrors,
      fieldErrors: _parseFieldErrors(rawErrors),
    );
  }

  static Map<String, Object?>? _asMap(Object? data) {
    if (data is Map) return data.map((k, Object? v) => MapEntry('$k', v));
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        return decoded is Map ? decoded.map((k, Object? v) => MapEntry('$k', v)) : null;
      } catch (_) {
        // Plain text or HTML body — not an envelope.
        return null;
      }
    }
    return null;
  }

  /// Accepts both `{"email": "is invalid"}` and `{"email": ["is invalid"]}`,
  /// which real backends mix even within one API.
  static Map<String, List<String>> _parseFieldErrors(Map<String, Object?> errors) {
    final result = <String, List<String>>{};
    errors.forEach((key, Object? value) {
      if (value is List) {
        result[key] = value.map((Object? e) => '$e').toList();
      } else if (value is String) {
        result[key] = [value];
      }
    });
    return result;
  }
}
