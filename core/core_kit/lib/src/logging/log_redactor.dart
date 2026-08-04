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
    // Added after probing the redactor with realistic payloads rather than with
    // the strings it was written against. Each of these went through untouched.
    'authToken',
    'auth_token',
    'sessionId',
    'session_id',
    'cookie',
    'privateKey',
    'private_key',
    'passwd',
    'credential',
    'credentials',
  };

  /// Headers whose entire value is a secret, matched to end of line.
  ///
  /// Separate from [sensitiveKeys] because the value is not a single token:
  /// `Authorization: Basic dXNlcjpwYXNz` has a scheme in front of the secret,
  /// and a cookie header is a whole `;`-delimited list. Stopping at the first
  /// space — which the key/value patterns do — kept the scheme and leaked the
  /// credential.
  static const Set<String> sensitiveHeaders = {
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'x-auth-token',
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

  /// The same keys, unquoted — `{password: hunter2}`.
  ///
  /// This is how a Dart `Map` prints, and `logger.debug('body: $map')` is the
  /// most natural line a developer writes. Before this pattern existed the
  /// probe showed `{password: hunter2, email: a@b.com}` coming out with the
  /// *email* masked and the password intact: every key here was already listed,
  /// and the one format they are most often seen in was the one not covered.
  ///
  /// `(?<!")` keeps it off the quoted JSON that [_jsonPair] already handled, so
  /// a match here is genuinely the bare form.
  /// The separator is captured, not assumed: rewriting every match as `key: …`
  /// turned `?token=abc` into `?token: ***REDACTED***` and mangled the query
  /// string. The value was safe either way; the log was no longer readable as a
  /// URL, which is most of why it is being logged.
  static final RegExp _unquotedPair = RegExp(
    '(?<!")\\b(${sensitiveKeys.join('|')})(\\s*[:=]\\s*)([^,;&}\\]\\s]+)',
    caseSensitive: false,
  );

  /// A whole header value, to end of line.
  ///
  /// `(?<!")` again, so a JSON body mentioning `"authorization"` is left to
  /// [_jsonPair] rather than having the rest of the line swallowed.
  static final RegExp _headerLine = RegExp(
    '(?<!")\\b(${sensitiveHeaders.join('|')})\\s*:\\s*[^\'\\n]+',
    caseSensitive: false,
  );

  /// A card number written the way it is printed on the card.
  ///
  /// [_longDigits] only sees an unbroken run, so `4111111111111111` was masked
  /// and `4111 1111 1111 1111` was not.
  static final RegExp _groupedCard = RegExp(r'\b\d{4}([ -]\d{4}){3}\b');

  /// Order is load-bearing.
  ///
  /// The quoted forms run before the bare ones so `(?<!")` has something to
  /// exclude, `_authHeader` runs before `_headerLine` so the curl form stops at
  /// its closing quote instead of eating the rest of the line, and the grouped
  /// card runs before [_longDigits] because the latter would otherwise mask the
  /// first group and leave the rest.
  static String redact(String input) {
    if (input.isEmpty) return input;
    return input
        .replaceAllMapped(_jsonPair, (m) => '"${m[1]}":"$mask"')
        .replaceAllMapped(_queryPair, (m) => '${m[1]}=$mask')
        .replaceAll(_authHeader, "-H 'authorization: $mask")
        .replaceAllMapped(_headerLine, (m) => '${m[1]}: $mask')
        .replaceAllMapped(_unquotedPair, (m) => '${m[1]}${m[2]}$mask')
        .replaceAll(_bearer, 'Bearer $mask')
        .replaceAll(_jwt, mask)
        .replaceAllMapped(_email, (m) => _maskEmail(m[0]!))
        .replaceAll(_groupedCard, mask)
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
