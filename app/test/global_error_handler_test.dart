import 'package:app/app/error/global_error_handler.dart';
import 'package:core_kit/core_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// The hooks are process-global statics, so every case installs, asserts and
// restores. Leaking them makes the *next* test file report its deliberate
// exceptions through a logger it never registered — which is a failure that
// looks like it comes from the wrong file.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryLogger logger;

  setUp(() {
    logger = InMemoryLogger();
    GlobalErrorHandler.install(() => logger);
  });

  tearDown(GlobalErrorHandler.reset);

  group('FlutterError.onError', () {
    test('reports a framework error to the logger', () {
      // `context` is the framework's description of what it was doing — "while
      // building", "during a gesture" — and it is the difference between a
      // usable crash report and a bare exception type, so it is folded into the
      // message rather than dropped.
      final details = FlutterErrorDetails(
        exception: StateError('render failed'),
        stack: StackTrace.current,
        library: 'widgets library',
        context: ErrorDescription('while building'),
      );

      FlutterError.onError!(details);

      expect(logger.records, hasLength(1));
      expect(logger.records.single.level, LogLevel.error);
      expect(logger.records.single.message, contains('while building'));
    });

    test('drops details the framework marked silent', () {
      // An overflow already reported this frame, an image that failed to decode.
      // Reporting these fills a crash report from a scrolling list alone.
      FlutterError.onError!(FlutterErrorDetails(exception: StateError('repeat'), silent: true));

      expect(logger.records, isEmpty);
    });

    test('still presents the error, so the red screen does not disappear', () {
      // The regression this guards: replacing `FlutterError.onError` wholesale
      // reports the error and stops showing it, and a developer's build failure
      // silently becomes a log line nobody reads.
      final presented = <FlutterErrorDetails>[];
      final previous = FlutterError.presentError;
      FlutterError.presentError = presented.add;
      addTearDown(() => FlutterError.presentError = previous);

      FlutterError.onError!(FlutterErrorDetails(exception: StateError('boom')));

      expect(presented, hasLength(1));
      expect(logger.records, hasLength(1));
    });
  });

  group('PlatformDispatcher.onError', () {
    test('reports an uncaught async error and marks it handled', () {
      final handled = PlatformDispatcher.instance.onError!(StateError('unawaited'), StackTrace.current);

      // False hands the error to the platform default, which terminates the
      // isolate on Android. An unawaited background future is not a reason to
      // close the app on the user.
      expect(handled, isTrue);
      expect(logger.records.single.level, LogLevel.error);
      expect(logger.records.single.message, contains('uncaught async error'));
    });

    // What is NOT asserted here, so the gap is visible rather than assumed:
    // that a real unawaited future — `Bootstrap.run` starts one for the
    // connectivity probe — actually arrives at this handler. It cannot be:
    // `flutter_test` runs every case inside its own error zone, which catches
    // the failure and fails the test before `PlatformDispatcher` is consulted.
    // Writing that test means writing one that passes for the wrong reason.
    //
    // The handler's contract is covered above by calling it directly. The
    // wiring — that Flutter routes uncaught async errors to
    // `PlatformDispatcher.onError` at all — is the framework's, not this
    // repo's, and the place it is confirmed is a real run of the app.
  });

  test('installing twice does not report an error twice', () {
    // `main` reinstalls on a retried start. Without the guard each install
    // chains onto the previous handler and every error is reported once per
    // call — which reads as a crash storm in whatever reporter is attached.
    GlobalErrorHandler.install(() => logger);
    GlobalErrorHandler.install(() => logger);

    FlutterError.onError!(FlutterErrorDetails(exception: StateError('once')));

    expect(logger.records, hasLength(1));
  });

  test('resolves the logger per error, not at install time', () {
    // Why `install` takes a supplier: the hooks go in before
    // `configureDependencies()`, so at that moment the real logger does not
    // exist yet. Binding one eagerly would pin the fallback for the whole run
    // and no crash would ever reach the registered reporter.
    var current = InMemoryLogger();
    GlobalErrorHandler.reset();
    GlobalErrorHandler.install(() => current);

    final replacement = InMemoryLogger();
    current = replacement;
    FlutterError.onError!(FlutterErrorDetails(exception: StateError('late')));

    expect(replacement.records, hasLength(1));
  });
}
