import 'package:app/app/di/console_logger.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_network/core_network.dart';
import 'package:injectable/injectable.dart';

/// The composition root's own registrations.
///
/// Everything here is either an app-wide primitive (config, logger) or a wiring
/// decision that no single package can make on its own — `ApiClient` needs the
/// auth delegate from `feature_auth` and the request context from this package,
/// so only the root can see all three.
///
/// This is what replaced the previous generation's 30-entry
/// `ignoreUnregisteredTypes` list: packages register what they own, and the
/// small remainder that spans packages is wired here, explicitly.
@module
abstract class AppModule {
  /// Reads `--dart-define`s once. Nothing else in the app calls
  /// `String.fromEnvironment`, so the full set of build-time inputs is
  /// discoverable in `AppEnvironmentConfig`.
  @lazySingleton
  AppEnvironmentConfig get environmentConfig => AppEnvironmentConfig.fromEnvironment();

  @lazySingleton
  AppLogger environmentLogger(AppEnvironmentConfig config) =>
      // Verbose in dev, warnings and above in production.
      ConsoleLogger(minimumLevel: config.isProduction ? LogLevel.warning : LogLevel.debug);

  /// The app's single connectivity source of truth. One instance: the banner
  /// listens to the same object the transport reports into.
  @lazySingleton
  ConnectivityMonitor connectivityMonitor(AppEnvironmentConfig config, AppLogger logger) =>
      ConnectivityMonitorImpl.resolve(config, logger);

  @lazySingleton
  ApiClient apiClient(
    AppEnvironmentConfig config,
    AuthSessionDelegate authDelegate,
    RequestContextProvider contextProvider,
    ConnectivityMonitor connectivityMonitor,
    AppLogger logger,
  ) => ApiClient(
    config: config,
    authDelegate: authDelegate,
    contextProvider: contextProvider,
    // Real traffic is the monitor's most reliable input; this is the wire.
    connectivityMonitor: connectivityMonitor,
    logger: logger,
  );

  /// Data sources take a `Dio`, not an `ApiClient`, so a Retrofit class can be
  /// constructed directly against a stub adapter in a test.
  @lazySingleton
  Dio dio(ApiClient client) => client.dio;
}
