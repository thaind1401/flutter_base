import 'package:app/app/di/injection.dart';
import 'package:app/app/session/session_cubit.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The composition root's regression test.
///
/// A DI graph fails at *runtime*, on a real device, usually in whichever flow
/// the reviewer did not open. Resolving every registration here turns that into
/// a test failure — and it is the one test that must exist in a project whose
/// wiring spans nine packages.
Future<Object?> _secureStorageStub(MethodCall call) async => call.method == 'readAll' ? <String, String>{} : null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // flutter_secure_storage talks to a platform channel that does not exist in
    // a test host; an empty stub is enough for construction and reads.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      _secureStorageStub,
    );
    await configureDependencies();
  });

  tearDown(getIt.reset);

  group('composition root', () {
    test('registers the app-wide primitives', () {
      expect(getIt<AppEnvironmentConfig>(), isNotNull);
      expect(getIt<AppLogger>(), isNotNull);
    });

    test('registers the storage layer from core_storage', () {
      expect(getIt<SecureStore>(), isA<SecureStoreImpl>());
      expect(getIt<PreferenceStore>(), isA<PreferenceStoreImpl>());
      expect(getIt<SharedPreferences>(), isNotNull);
    });

    test('registers the transport, including the failure mapper', () {
      expect(getIt<ApiClient>(), isNotNull);
      expect(getIt<Dio>(), isNotNull);
      expect(getIt<FailureMapper>(), isA<DioFailureMapper>());
    });

    test('wires the auth delegate into the transport without a cycle', () {
      // This is the inversion that lets core_network attach a token while
      // knowing nothing about feature_auth. If it ever regresses, the graph
      // either fails to resolve here or deadlocks on a device.
      expect(getIt<AuthSessionDelegate>(), isNotNull);
      expect(getIt<ApiClient>().dio, isNotNull);
    });

    test('registers one connectivity monitor, shared by the banner and the transport', () {
      // A second instance would leave the banner listening to an object nothing
      // reports into, and it would fail silently.
      expect(getIt<ConnectivityMonitor>(), isA<ConnectivityMonitorImpl>());
      expect(getIt<ConnectivityMonitor>(), same(getIt<ConnectivityMonitor>()));
    });

    test('registers the design system from core_ui', () {
      // One assertion per external module, so a package left out of
      // `externalPackageModulesBefore` fails here. core_ui was missing from
      // that list: this type went unregistered and the app white-screened on
      // the first frame while every gate stayed green.
      expect(getIt<LoadingOverlayController>(), isNotNull);
      expect(getIt<LoadingOverlayController>(), same(getIt<LoadingOverlayController>()));
    });

    test('registers the auth feature end to end', () {
      expect(getIt<AuthRepository>(), isNotNull);
      expect(getIt<SessionStore>(), isNotNull);
      expect(getIt<SignInUseCase>(), isNotNull);
      expect(getIt<SignOutUseCase>(), isNotNull);
      expect(getIt<SessionCubit>(), isNotNull);
    });

    test('hands out a fresh LoginBloc per request', () {
      // Registered as a factory: a reused bloc would carry the previous
      // attempt's error and password into the next sign-in.
      expect(getIt<LoginBloc>(), isNot(same(getIt<LoginBloc>())));
    });

    test('holds one instance of each singleton', () {
      expect(getIt<SessionStore>(), same(getIt<SessionStore>()));
      expect(getIt<ApiClient>(), same(getIt<ApiClient>()));
    });

    test('resolves the environment from dart-defines with a dev fallback', () {
      // Tests run without --dart-define, which must mean dev and never crash.
      expect(getIt<AppEnvironmentConfig>().environment, AppEnvironment.dev);
      expect(getIt<AppEnvironmentConfig>().enableNetworkLogging, isTrue);
    });
  });
}
