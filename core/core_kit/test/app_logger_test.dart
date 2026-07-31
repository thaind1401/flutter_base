import 'package:core_kit/core_kit.dart';
import 'package:test/test.dart';

/// `BaseAppLogger` implements the level convenience methods once, so every
/// logger in the app inherits two behaviours from it: the minimum-level filter
/// and redaction. Both are the kind that fail open — a broken filter logs more
/// than intended and a broken redactor writes a bearer token into a crash
/// report, and neither changes anything visible until someone reads the logs.
///
/// `LogRedactor` has its own tests for the patterns it scrubs. What is tested
/// here is that `BaseAppLogger` actually calls it.
void main() {
  group('level filtering', () {
    test('everything is written at the default level', () {
      final logger = InMemoryLogger();

      logger
        ..verbose('v')
        ..debug('d')
        ..info('i')
        ..warning('w')
        ..error('e');

      expect(logger.records.map((r) => r.level), [
        LogLevel.verbose,
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warning,
        LogLevel.error,
      ]);
    });

    test('records below the minimum are dropped', () {
      // The production shape: `ConsoleLogger(minimumLevel: warning)`. A debug
      // call there must cost nothing, not merely be hidden downstream.
      final logger = InMemoryLogger(minimumLevel: LogLevel.warning);

      logger
        ..verbose('v')
        ..debug('d')
        ..info('i')
        ..warning('w')
        ..error('e');

      expect(logger.records.map((r) => r.message), ['w', 'e']);
    });

    test('the boundary level itself is kept', () {
      // `<` not `<=`: an off-by-one here silently drops the level the operator
      // explicitly asked for.
      final logger = InMemoryLogger(minimumLevel: LogLevel.info);

      logger
        ..debug('below')
        ..info('at the boundary');

      expect(logger.records.map((r) => r.message), ['at the boundary']);
    });

    test('log() honours the filter as well as the shorthands', () {
      final logger = InMemoryLogger(minimumLevel: LogLevel.error);

      logger
        ..log(LogLevel.info, 'dropped')
        ..log(LogLevel.error, 'kept');

      expect(logger.records.map((r) => r.message), ['kept']);
    });
  });

  group('formatting', () {
    test('a tag is prefixed in brackets', () {
      final logger = InMemoryLogger();

      logger.info('bootstrap complete', tag: 'startup');

      expect(logger.records.single.message, '[startup] bootstrap complete');
    });

    test('no tag means no prefix and no stray space', () {
      final logger = InMemoryLogger();

      logger.info('plain');

      expect(logger.records.single.message, 'plain');
    });

    test('a non-string message is interpolated', () {
      final logger = InMemoryLogger();

      logger
        ..info(42)
        ..info(null);

      expect(logger.records.map((r) => r.message), ['42', 'null']);
    });
  });

  group('redaction', () {
    test('is on by default', () {
      // The whole point: a call site that logs a payload without thinking must
      // still not write the token. `LogRedactor` is the safety net and this is
      // the assertion that it is actually wired in.
      final logger = InMemoryLogger();

      logger.info('Authorization: Bearer abcdef1234567890');

      expect(logger.records.single.message, isNot(contains('abcdef1234567890')));
    });

    test('can be turned off for local debugging', () {
      final logger = InMemoryLogger(redact: false);

      logger.info('Authorization: Bearer abcdef1234567890');

      expect(logger.records.single.message, contains('abcdef1234567890'));
    });

    test('the tag is inside the redacted string, not appended after it', () {
      // If the tag were prefixed after redaction, a secret in the tag would
      // survive. Cheap to get wrong, invisible when it is.
      final logger = InMemoryLogger();

      logger.info('body', tag: 'user@example.com');

      expect(logger.records.single.message, isNot(contains('user@example.com')));
    });
  });

  test('NoopLogger accepts every call and keeps nothing', () {
    // The default in tests and in a release build before the host registers a
    // real logger, so it has to be total rather than merely quiet.
    const logger = NoopLogger();

    expect(() {
      logger
        ..verbose('v')
        ..debug('d')
        ..info('i')
        ..warning('w', error: StateError('boom'), stackTrace: StackTrace.current)
        ..error('e', error: StateError('boom'), stackTrace: StackTrace.current)
        ..log(LogLevel.info, 'direct');
    }, returnsNormally);
  });
}
