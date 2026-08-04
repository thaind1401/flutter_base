import 'package:core_kit/core_kit.dart';
import 'package:test/test.dart';

/// `AppEnvironmentConfig` is the only place in the codebase that reads
/// `String.fromEnvironment`, which makes it the only place a build-script typo
/// or a missing `--dart-define` can change behaviour app-wide — and it had no
/// tests at all.
///
/// Two of its rules are safety rules rather than configuration: network logging
/// is off in production because request bodies routinely carry personal data
/// and release logs are readable with `adb logcat`, and `devAuthBypass` fakes
/// authentication outright. Both are derived rather than read straight from a
/// define, and derived rules are exactly what silently inverts.
void main() {
  group('AppEnvironment.resolve', () {
    test('maps each flavor name to its value', () {
      expect(AppEnvironment.resolve(rawOverride: 'dev'), AppEnvironment.dev);
      expect(AppEnvironment.resolve(rawOverride: 'stg'), AppEnvironment.stg);
      expect(AppEnvironment.resolve(rawOverride: 'prod'), AppEnvironment.prod);
    });

    test('an absent define falls back to dev', () {
      // A plain `flutter test` or an IDE run config passes no APP_ENV. Falling
      // back to dev is what makes those work without every developer having to
      // configure defines first.
      expect(AppEnvironment.resolve(rawOverride: ''), AppEnvironment.dev);
    });

    test('an unknown flavor trips an assert rather than silently becoming dev', () {
      // The dangerous shape: a build script that writes APP_ENV=production
      // instead of prod. Falling back to dev quietly would ship a build with
      // logging on and pinning off.
      expect(() => AppEnvironment.resolve(rawOverride: 'production'), throwsA(isA<AssertionError>()));
    });

    test('isProduction is true only for prod', () {
      expect(AppEnvironment.prod.isProduction, isTrue);
      expect(AppEnvironment.dev.isProduction, isFalse);
      expect(AppEnvironment.stg.isProduction, isFalse);
    });
  });

  group('AppEnvironmentConfig', () {
    test('defaults are the conservative ones', () {
      const config = AppEnvironmentConfig(environment: AppEnvironment.dev, baseUrl: 'https://example.com');

      expect(config.connectTimeout, const Duration(seconds: 30));
      expect(config.receiveTimeout, const Duration(seconds: 30));
      expect(config.sendTimeout, const Duration(seconds: 30));
      // Every flag defaults to off. A config built without arguments must not
      // enable logging or bypass authentication by omission.
      expect(config.enableNetworkLogging, isFalse);
      expect(config.enableCertificatePinning, isFalse);
      expect(config.devAuthBypass, isFalse);
    });

    test('isProduction follows the environment', () {
      const prod = AppEnvironmentConfig(environment: AppEnvironment.prod, baseUrl: 'https://api.example.com');
      const stg = AppEnvironmentConfig(environment: AppEnvironment.stg, baseUrl: 'https://stg.example.com');

      expect(prod.isProduction, isTrue);
      expect(stg.isProduction, isFalse);
    });

    test('fromEnvironment under `flutter test` yields a safe dev config', () {
      // No defines are passed here, so this pins what a build with nothing
      // configured produces: dev, logging on, pinning off, and — critically —
      // no auth bypass, because `DEV_AUTH_BYPASS` defaults to false.
      final config = AppEnvironmentConfig.fromEnvironment();

      expect(config.environment, AppEnvironment.dev);
      expect(config.baseUrl, 'https://api.example.com');
      expect(config.enableNetworkLogging, isTrue);
      expect(config.enableCertificatePinning, isFalse);
      expect(config.devAuthBypass, isFalse);
    });

    test('value equality covers every field', () {
      // `props` completeness matters here for the same reason it does in a
      // state class: a field left out means a change to it is invisible to `==`.
      const a = AppEnvironmentConfig(environment: AppEnvironment.dev, baseUrl: 'https://a.example.com');
      const b = AppEnvironmentConfig(environment: AppEnvironment.dev, baseUrl: 'https://a.example.com');
      const differentUrl = AppEnvironmentConfig(environment: AppEnvironment.dev, baseUrl: 'https://b.example.com');
      const differentEnv = AppEnvironmentConfig(environment: AppEnvironment.prod, baseUrl: 'https://a.example.com');
      const differentBypass = AppEnvironmentConfig(
        environment: AppEnvironment.dev,
        baseUrl: 'https://a.example.com',
        devAuthBypass: true,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(differentUrl));
      expect(a, isNot(differentEnv));
      expect(a, isNot(differentBypass));
    });
  });
}
