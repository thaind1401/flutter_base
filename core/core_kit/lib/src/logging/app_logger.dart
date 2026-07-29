import 'package:core_kit/src/logging/log_redactor.dart';

enum LogLevel { verbose, debug, info, warning, error }

/// Logging is an interface, not a global function, so that a package can be
/// unit-tested without a console and so the host app can swap in Crashlytics
/// or Sentry without touching a single call site.
abstract interface class AppLogger {
  void log(LogLevel level, Object? message, {String? tag, Object? error, StackTrace? stackTrace});

  void verbose(Object? message, {String? tag});

  void debug(Object? message, {String? tag});

  void info(Object? message, {String? tag});

  void warning(Object? message, {String? tag, Object? error, StackTrace? stackTrace});

  void error(Object? message, {String? tag, Object? error, StackTrace? stackTrace});
}

/// Implements the convenience methods once so concrete loggers only supply
/// [log] and [write].
abstract base class BaseAppLogger implements AppLogger {
  const BaseAppLogger({this.minimumLevel = LogLevel.verbose, this.redact = true});

  /// Messages below this level are dropped before any formatting work.
  final LogLevel minimumLevel;

  /// Whether to scrub tokens, emails and phone numbers before writing.
  /// Leave on outside of local debugging; logs reach crash reports and CI.
  final bool redact;

  /// The single sink every level funnels through.
  void write(LogLevel level, String message, {Object? error, StackTrace? stackTrace});

  @override
  void log(LogLevel level, Object? message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (level.index < minimumLevel.index) return;
    final prefix = tag == null ? '' : '[$tag] ';
    final raw = '$prefix$message';
    write(level, redact ? LogRedactor.redact(raw) : raw, error: error, stackTrace: stackTrace);
  }

  @override
  void verbose(Object? message, {String? tag}) => log(LogLevel.verbose, message, tag: tag);

  @override
  void debug(Object? message, {String? tag}) => log(LogLevel.debug, message, tag: tag);

  @override
  void info(Object? message, {String? tag}) => log(LogLevel.info, message, tag: tag);

  @override
  void warning(Object? message, {String? tag, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.warning, message, tag: tag, error: error, stackTrace: stackTrace);

  @override
  void error(Object? message, {String? tag, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
}

/// Discards everything. The default in tests and in release builds until the
/// host registers a real logger.
final class NoopLogger extends BaseAppLogger {
  const NoopLogger();

  @override
  void write(LogLevel level, String message, {Object? error, StackTrace? stackTrace}) {}
}

/// Captures records in memory. Lets a test assert on what was logged without
/// polluting stdout.
final class InMemoryLogger extends BaseAppLogger {
  InMemoryLogger({super.minimumLevel, super.redact});

  final List<({LogLevel level, String message})> records = [];

  @override
  void write(LogLevel level, String message, {Object? error, StackTrace? stackTrace}) {
    records.add((level: level, message: message));
  }
}
