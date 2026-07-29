import 'dart:developer' as developer;

import 'package:core_kit/core_kit.dart';
import 'package:flutter/foundation.dart';

/// Writes to the IDE console in debug builds.
///
/// Registered as the [AppLogger] for the whole app. To send logs to Crashlytics
/// or Sentry, write another [BaseAppLogger] and change the one line in
/// `AppModule` — no call site moves, because nothing calls `print` directly.
final class ConsoleLogger extends BaseAppLogger {
  const ConsoleLogger({super.minimumLevel = LogLevel.debug, super.redact = true});

  @override
  void write(LogLevel level, String message, {Object? error, StackTrace? stackTrace}) {
    // Release builds get no console sink at all: log output is readable with
    // `adb logcat` on any device, and these lines carry request bodies.
    if (kReleaseMode) return;
    developer.log(
      '${_prefix(level)} $message',
      name: 'app',
      error: error,
      stackTrace: stackTrace,
      level: _severity(level),
    );
  }

  String _prefix(LogLevel level) => switch (level) {
    LogLevel.verbose => '·',
    LogLevel.debug => '›',
    LogLevel.info => 'ℹ',
    LogLevel.warning => '⚠',
    LogLevel.error => '✖',
  };

  /// `dart:developer` severities, matching the `logging` package's levels so
  /// DevTools filters work as expected.
  int _severity(LogLevel level) => switch (level) {
    LogLevel.verbose => 300,
    LogLevel.debug => 500,
    LogLevel.info => 800,
    LogLevel.warning => 900,
    LogLevel.error => 1000,
  };
}
