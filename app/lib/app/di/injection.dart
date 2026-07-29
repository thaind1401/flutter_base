import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

/// The one service locator.
final GetIt getIt = GetIt.instance;

/// Composes every package's DI module, in dependency order.
///
/// This list *is* the architecture, written down. Each entry is a package that
/// registered its own dependencies with `@InjectableInit.microPackage()`;
/// the generator verified them inside that package, so this file never has to
/// enumerate — or suppress — individual types.
///
/// Order matters: storage before auth (the session store needs `SecureStore`),
/// network before auth (the repository needs `Dio`). `Before` means these run
/// ahead of this package's own registrations, which is what lets `AppModule`
/// build the `ApiClient` out of pieces the packages provided.
///
/// Every workspace package carrying injectable annotations belongs here. Adding
/// one is not optional bookkeeping: `core_ui` was missing from this list, so
/// `LoadingOverlayController` went unregistered and the app white-screened on
/// the first frame while the whole CI gate stayed green. `app/test/injection_test.dart`
/// now asserts one resolvable type per module so the same omission fails a test.
@InjectableInit(
  externalPackageModulesBefore: [
    ExternalModule(CoreStoragePackageModule),
    ExternalModule(CoreNetworkPackageModule),
    ExternalModule(CoreUiPackageModule),
    ExternalModule(FeatureAuthPackageModule),
  ],
)
Future<GetIt> configureDependencies() => getIt.init();
