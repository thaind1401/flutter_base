/// Scrubs secrets and personal data out of anything headed for a log sink.
///
/// This is a safety net, not a licence to log payloads. Redaction is pattern
/// based, so a field name nobody anticipated still leaks; keep sensitive data
/// out of log statements in the first place.
abstract final class LogRedactor {
  static const String mask = '***REDACTED***';

  /// JSON/map keys whose value is replaced wholesale, case-insensitively.
  static const Set<String> sensitiveKeys = {
    'password',
    'newPassword',
    'oldPassword',
    'confirmPassword',
    'pin',
    'otp',
    'token',
    'accessToken',
    'refreshToken',
    'idToken',
    'id_token',
    'access_token',
    'refresh_token',
    'authorization',
    'apiKey',
    'api_key',
    'secret',
    'clientSecret',
    'client_secret',
    'signature',
    'ssn',
    'nationalId',
    'cardNumber',
    'cvv',
  };

  // Dart's RegExp has no inline `(?i)` flag; case-insensitivity is a constructor
  // argument. Getting this wrong silently compiles into a pattern that never
  // matches, which is how bearer tokens end up in CI logs.
  static final RegExp _bearer = RegExp(r'bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false);
  static final RegExp _authHeader = RegExp(r"(-H\s+'?authorization:\s*)([^'\n]+)", caseSensitive: false);
  static final RegExp _jwt = RegExp(r'\beyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\b');
  static final RegExp _email = RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.-]+\b');
  static final RegExp _longDigits = RegExp(r'\b\d{9,19}\b');

  /// Key/value pairs in JSON (`"token": "x"`) and in query strings (`token=x`).
  static final RegExp _jsonPair = RegExp(
    '"(${sensitiveKeys.join('|')})"\\s*:\\s*("(?:[^"\\\\]|\\\\.)*"|[^,}\\s]+)',
    caseSensitive: false,
  );
  static final RegExp _queryPair = RegExp('(?<=[?&])(${sensitiveKeys.join('|')})=([^&\\s]*)', caseSensitive: false);

  static String redact(String input) {
    if (input.isEmpty) return input;
    return input
        .replaceAllMapped(_jsonPair, (m) => '"${m[1]}":"$mask"')
        .replaceAllMapped(_queryPair, (m) => '${m[1]}=$mask')
        .replaceAll(_authHeader, "-H 'authorization: $mask")
        .replaceAll(_bearer, 'Bearer $mask')
        .replaceAll(_jwt, mask)
        .replaceAllMapped(_email, (m) => _maskEmail(m[0]!))
        .replaceAll(_longDigits, mask);
  }

  /// Redacts a decoded structure, preserving shape so the log stays readable.
  static Object? redactValue(Object? value) {
    if (value is Map) {
      return value.map((key, dynamic v) {
        final isSensitive = sensitiveKeys.any((s) => s.toLowerCase() == key.toString().toLowerCase());
        return MapEntry(key, isSensitive ? mask : redactValue(v));
      });
    }
    if (value is List) return value.map<Object?>(redactValue).toList();
    if (value is String) return redact(value);
    return value;
  }

  /// `john.doe@corp.com` -> `j***@corp.com`: enough to correlate two log lines,
  /// not enough to identify a person.
  static String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return mask;
    return '${email[0]}***${email.substring(at)}';
  }
}
