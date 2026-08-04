import 'package:core_kit/core_kit.dart';
import 'package:flutter/foundation.dart';

/// Where an error that nobody caught ends up.
///
/// Rule 1 covers the *expected* kind: a repository wraps its call in
/// `BaseRepository.guard`, the failure becomes a `Result`, and every layer above
/// handles it as data. Nothing here changes that, and nothing here is an excuse
/// to stop doing it.
///
/// This is for the other kind — the errors that never enter a `Result` because
/// no `try` was ever in their path:
///
///   * a `RenderFlex` overflow or a `build` that throws, reported by the
///     framework through [FlutterError.onError];
///   * a gesture or animation callback that threw;
///   * a platform channel that rejected;
///   * an `unawaited` future that failed — `Bootstrap.run` starts one on purpose
///     for the connectivity probe;
///   * anything thrown after an `await` in a `void` async callback.
///
/// Until this existed none of them went anywhere. [FlutterError.onError]
/// defaults to [FlutterError.presentError], which writes to the console in debug
/// and is silent in a release build. [PlatformDispatcher.onError] defaults to
/// null, and an uncaught asynchronous error with no handler is *discarded*.
///
/// So `AppLogger`'s promise — swap in Crashlytics or Sentry and every call site
/// keeps working — held only for errors somebody had already remembered to log.
/// The crashes were the one category it missed. Installing these two hooks is
/// what makes that promise true, and it is why adopting a crash reporter here is
/// still a one-line change to `AppModule` rather than a hunt for the four places
/// Flutter hands out errors.
///
/// **`runZonedGuarded` is deliberately not used.** [PlatformDispatcher.onError]
/// catches everything the zone did, without the trap that comes with it: the
/// zone that calls `WidgetsFlutterBinding.ensureInitialized()` must be the zone
/// that calls `runApp`, and a mismatch is a startup failure with a message that
/// explains nothing.
///
/// **[ErrorWidget.builder] is deliberately not overridden.** Reporting is
/// already covered — a widget that throws in `build` reaches
/// [FlutterError.onError] above. What is left is cosmetic, and a replacement
/// renders in place of a subtree that just failed, so it cannot safely read
/// `context.colors` or `CoreL10n.of(context)`: the design system or the
/// `Localizations` scope may be the thing that broke, and an error widget that
/// throws is an unbreakable loop. Overriding it means committing to a widget
/// that depends on nothing, which is a project's design decision, not this
/// base's.
abstract final class GlobalErrorHandler {
  static const String _tag = 'crash';

  static bool _installed = false;

  /// Takes a *supplier*, not an `AppLogger`.
  ///
  /// This is installed before `configureDependencies()` has run — an error
  /// thrown while composing the container is exactly the kind that must not be
  /// swallowed — so there is no logger to hand it yet. Resolving per error also
  /// means a host that swaps the registered logger does not have to reinstall.
  static void install(AppLogger Function() logger) {
    // Idempotent: `main` reinstalls on a retried start, and a widget test may
    // call this once per case. Without the guard, chaining onto the previous
    // `FlutterError.onError` builds a longer chain every time and each error is
    // reported once per install.
    if (_installed) return;
    _installed = true;

    FlutterError.onError = (details) {
      // Kept first and unconditional: this is what prints the diagnostic dump in
      // debug and paints the red screen. Reporting an error is not a reason to
      // stop showing it to the developer who caused it.
      FlutterError.presentError(details);

      // `silent` marks details the framework raises as part of normal operation
      // — an overflow already reported this frame, an image that failed to
      // decode. `presentError` honours it and so does this, or a scrolling list
      // over a flaky connection fills a crash report by itself.
      if (details.silent) return;

      logger().error(
        details.context == null ? 'flutter error' : 'flutter error ${details.context}',
        tag: _tag,
        error: details.exception,
        stackTrace: details.stack,
      );
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      logger().error('uncaught async error', tag: _tag, error: error, stackTrace: stackTrace);
      // True means handled. Returning false hands the error to the platform's
      // default handler, which on Android terminates the isolate — an unawaited
      // background future is not a reason to close the app on the user.
      return true;
    };
  }

  /// Restores Flutter's defaults. Tests only: the hooks are process-global, so a
  /// suite that installs them and does not undo it reports the *next* test's
  /// deliberate exceptions through a logger that test never registered.
  @visibleForTesting
  static void reset() {
    _installed = false;
    FlutterError.onError = FlutterError.presentError;
    PlatformDispatcher.instance.onError = null;
  }
}
