import 'package:app/app/app.dart';
import 'package:app/app/bootstrap.dart';
import 'package:app/app/di/injection.dart';
import 'package:app/app/l10n/app_localizations.dart';
import 'package:app/app/theme/theme_mode_controller.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// What `app/test/app_smoke_test.dart` structurally cannot check.
///
/// That test mocks three method channels — `flutter_secure_storage`,
/// `shared_preferences` and `connectivity_plus` — because a widget test has no
/// platform behind it. Every plugin therefore "works" there by construction. So
/// the failures it can never see are exactly the ones that only exist on a
/// device: a keychain that is not entitled, an Android `minSdk` below what the
/// storage plugin needs, an EncryptedSharedPreferences migration that throws on
/// first launch, a plugin that silently fails to register in a release build.
/// Each one produces an app that opens fine in CI and dies on a real handset.
///
/// Deliberately no network. `core_network` does not export its Dio adapter, so
/// a test that reaches the wire here would hang on a real socket rather than
/// fail with something readable, and a base project has no backend to point at.
/// Everything below exercises the storage and startup path only.
///
/// Run with `make integration` against a booted emulator, simulator or device.
/// It is not part of `make ci`: CI runners have no device, and a gate that
/// cannot run is a gate nobody trusts. `.github/workflows/integration.yml`
/// boots an Android emulator and runs this on a schedule and on demand.
///
/// **These run under a flavor, and the flavor is not fixed.** `make integration`
/// passes `env_config/dev/dart_defines.json`, which is gitignored and generated
/// once from the sample — `make env` leaves an existing file alone, so a clone
/// created before `DEV_AUTH_BYPASS` was added to the sample simply does not have
/// it. Whether the app lands on login or on home therefore depends on the
/// machine, not on the code.
///
/// So assert the *rule* the config implies, never one config's outcome. The boot
/// test below hardcoded the login screen and failed on its first real run for
/// exactly that reason.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    // Real stores on a real device persist across tests in the same run, unlike
    // the per-test mock maps the widget test gets for free. Wiping both is what
    // keeps these independent of their order.
    await getIt<SecureStore>().clear();
    await getIt<PreferenceStore>().clear();
    await getIt.reset();
  });

  testWidgets('the app boots against real plugins and lands where the flavor says', (tester) async {
    final bootstrap = await Bootstrap.run();

    await tester.pumpWidget(App(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // The destination is decided by the config, so the assertion has to be too.
    // `DEV_AUTH_BYPASS` seeds a session before the first frame, and it is read
    // from a gitignored env file whose contents differ per machine.
    //
    // Asserting the *rule* rather than one of its outcomes is what makes this
    // useful in both directions: it fails if a build with the bypass on still
    // shows login, and if a build with it off silently skips login — which is
    // the one that would matter in production.
    final loginTitle = (await _authCopy()).loginTitle;

    if (getIt<AppEnvironmentConfig>().devAuthBypass) {
      expect(find.text(loginTitle), findsNothing, reason: 'the bypass must skip login entirely');
      expect(find.text('Dev Bypass'), findsOneWidget, reason: 'the seeded session should land on home');
    } else {
      expect(find.text(loginTitle), findsOneWidget);
    }
  });

  testWidgets('the platform keychain round-trips a value', (tester) async {
    // The single most common device-only failure in this stack: secure storage
    // that constructs fine and then throws, or silently returns null, because
    // the keystore is not available. `SessionStoreImpl` is built on this, so a
    // broken keychain means nobody can stay signed in — and nothing before this
    // point would have noticed.
    await Bootstrap.run();
    final store = getIt<SecureStore>();

    final written = await store.writeString('integration.probe', 'value');
    expect(written.isOk, isTrue, reason: 'the platform keychain rejected a write');

    final read = await store.readString('integration.probe');
    expect(read, const Ok<String?>('value'));

    await store.remove('integration.probe');
    expect(await store.readString('integration.probe'), const Ok<String?>(null));
  });

  testWidgets('a theme chosen in one launch is applied by the next', (tester) async {
    // The persistence claim, end to end, through the real SharedPreferences
    // rather than `setMockInitialValues`. The unit test proves the controller's
    // logic; this proves the value actually survives in platform storage under
    // the key the next launch reads.
    final first = await Bootstrap.run();
    await first.themeMode.select(ThemeMode.dark);
    await getIt.reset();

    final second = await Bootstrap.run();
    await tester.pumpWidget(App(bootstrap: second));
    await tester.pump();

    expect(second.themeMode.value, ThemeMode.dark);
    expect(Theme.of(tester.element(find.byType(LoadingOverlayHost))).brightness, Brightness.dark);
    expect(getIt<ThemeModeController>().value, ThemeMode.dark);

    await tester.pumpAndSettle();
  });
}

/// The login copy, in whatever language the *device* is set to.
///
/// The flavor is not the only thing about this test that varies per machine —
/// the locale does too, and the boot assertion above used to hardcode "Welcome
/// back". That passes on an English handset and fails on every other one, with
/// a message about a missing widget that points at the router rather than at
/// the assertion. It cost a real debugging session on a Vietnamese phone.
///
/// `app/test/app_smoke_test.dart` can hardcode the string safely, because a
/// widget test resolves to the template language no matter what the host is
/// set to. On a device there is no such guarantee, so the expectation is
/// resolved the same way the app resolves it.
Future<AuthL10n> _authCopy() {
  final device = WidgetsBinding.instance.platformDispatcher.locale;
  final locale = AppLocalizationsSetup.supportedLocales.firstWhere(
    (supported) => supported.languageCode == device.languageCode,
    // Matches Flutter's own fallback: an unsupported device language gets the
    // template locale, which is what the app itself will be rendering.
    orElse: () => AppLocalizationsSetup.supportedLocales.first,
  );
  return AuthL10n.delegate.load(locale);
}
