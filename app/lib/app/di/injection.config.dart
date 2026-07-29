// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:app/app/di/app_module.dart' as _i296;
import 'package:app/app/di/device_request_context.dart' as _i410;
import 'package:app/app/session/session_cubit.dart' as _i132;
import 'package:core_kit/core_kit.dart' as _i895;
import 'package:core_network/core_network.dart' as _i309;
import 'package:core_storage/core_storage.dart' as _i78;
import 'package:core_ui/core_ui.dart' as _i728;
import 'package:feature_auth/feature_auth.dart' as _i277;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    await _i78.CoreStoragePackageModule().init(gh);
    await _i309.CoreNetworkPackageModule().init(gh);
    await _i728.CoreUiPackageModule().init(gh);
    await _i277.FeatureAuthPackageModule().init(gh);
    final appModule = _$AppModule();
    gh.lazySingleton<_i895.AppEnvironmentConfig>(
      () => appModule.environmentConfig,
    );
    gh.lazySingleton<_i309.RequestContextProvider>(
      () => _i410.DeviceRequestContext(),
    );
    gh.lazySingleton<_i895.AppLogger>(
      () => appModule.environmentLogger(gh<_i895.AppEnvironmentConfig>()),
    );
    gh.lazySingleton<_i132.SessionCubit>(
      () => _i132.SessionCubit(
        gh<_i277.SessionStore>(),
        gh<_i277.SignOutUseCase>(),
        logger: gh<_i895.AppLogger>(),
      ),
    );
    gh.lazySingleton<_i895.ConnectivityMonitor>(
      () => appModule.connectivityMonitor(
        gh<_i895.AppEnvironmentConfig>(),
        gh<_i895.AppLogger>(),
      ),
    );
    gh.lazySingleton<_i309.ApiClient>(
      () => appModule.apiClient(
        gh<_i895.AppEnvironmentConfig>(),
        gh<_i309.AuthSessionDelegate>(),
        gh<_i309.RequestContextProvider>(),
        gh<_i895.ConnectivityMonitor>(),
        gh<_i895.AppLogger>(),
      ),
    );
    gh.lazySingleton<_i309.Dio>(() => appModule.dio(gh<_i309.ApiClient>()));
    return this;
  }
}

class _$AppModule extends _i296.AppModule {}
