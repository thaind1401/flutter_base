import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Build flavors. Adding one means adding an env file and a Makefile target;
/// nothing branches on the flavor name outside of [AppEnvironmentConfig].
enum AppEnvironment {
  dev,
  stg,
  prod;

  bool get isProduction => this == AppEnvironment.prod;

  /// Reads `--dart-define=APP_ENV`.
  ///
  /// An empty value means the define was not passed at all — a plain
  /// `flutter run`, `flutter test`, or an IDE run config — and falls back to
  /// [dev]. A non-empty value matching no flavor is a typo in a build script
  /// and trips an assert in debug so it is caught before it ships.
  static AppEnvironment resolve({String? rawOverride}) {
    final raw = rawOverride ?? const String.fromEnvironment('APP_ENV');
    return AppEnvironment.values.firstWhere(
      (e) => e.name == raw,
      orElse: () {
        assert(raw.isEmpty, 'Unknown APP_ENV "$raw"; expected one of ${AppEnvironment.values.map((e) => e.name)}');
        return AppEnvironment.dev;
      },
    );
  }
}

/// Everything that varies per flavor, resolved once at startup and injected.
///
/// Nothing reads `String.fromEnvironment` outside this class. That keeps the
/// values testable (construct a config directly) and keeps the set of build
/// time inputs discoverable in one place instead of scattered across files.
@immutable
final class AppEnvironmentConfig extends Equatable {
  const AppEnvironmentConfig({
    required this.environment,
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 30),
    this.enableNetworkLogging = false,
    this.enableCertificatePinning = false,
  });

  /// Builds from `--dart-define-from-file=env_config/<flavor>/dart_defines.json`.
  factory AppEnvironmentConfig.fromEnvironment() {
    final env = AppEnvironment.resolve();
    return AppEnvironmentConfig(
      environment: env,
      baseUrl: const String.fromEnvironment('BASE_URL', defaultValue: 'https://api.example.com'),
      connectTimeout: const Duration(seconds: int.fromEnvironment('CONNECT_TIMEOUT_SECONDS', defaultValue: 30)),
      receiveTimeout: const Duration(seconds: int.fromEnvironment('RECEIVE_TIMEOUT_SECONDS', defaultValue: 30)),
      // Network logs are never on in production: request bodies routinely carry
      // personal data, and release logs are readable with `adb logcat`.
      enableNetworkLogging: !env.isProduction,
      enableCertificatePinning: env.isProduction,
    );
  }

  final AppEnvironment environment;
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final bool enableNetworkLogging;
  final bool enableCertificatePinning;

  bool get isProduction => environment.isProduction;

  @override
  List<Object?> get props => [
    environment,
    baseUrl,
    connectTimeout,
    receiveTimeout,
    sendTimeout,
    enableNetworkLogging,
    enableCertificatePinning,
  ];
}
