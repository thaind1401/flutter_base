//@GeneratedMicroModule;FeatureAuthPackageModule;package:feature_auth/di.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i687;

import 'package:core_kit/core_kit.dart' as _i895;
import 'package:core_network/core_network.dart' as _i309;
import 'package:core_storage/core_storage.dart' as _i78;
import 'package:feature_auth/src/data/data_sources/auth_api.dart' as _i244;
import 'package:feature_auth/src/data/data_sources/token_refresh_api.dart'
    as _i996;
import 'package:feature_auth/src/data/repositories/auth_repository_impl.dart'
    as _i953;
import 'package:feature_auth/src/data/session/session_auth_delegate.dart'
    as _i478;
import 'package:feature_auth/src/data/session/session_store_impl.dart' as _i60;
import 'package:feature_auth/src/domain/repositories/auth_repository.dart'
    as _i1063;
import 'package:feature_auth/src/domain/session/session_store.dart' as _i812;
import 'package:feature_auth/src/domain/use_cases/auth_use_cases.dart' as _i131;
import 'package:feature_auth/src/presentation/login/login_bloc.dart' as _i928;
import 'package:injectable/injectable.dart' as _i526;

class FeatureAuthPackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i812.SessionStore>(
      () => _i60.SessionStoreImpl(
        gh<_i78.SecureStore>(),
        logger: gh<_i895.AppLogger>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.factory<_i244.AuthApi>(() => _i244.AuthApi(gh<_i309.Dio>()));
    gh.lazySingleton<_i996.TokenRefreshApi>(() => _i996.TokenRefreshApi(
          gh<_i895.AppEnvironmentConfig>(),
          gh<_i895.FailureMapper>(),
        ));
    gh.lazySingleton<_i309.AuthSessionDelegate>(() => _i478.SessionAuthDelegate(
          gh<_i812.SessionStore>(),
          gh<_i996.TokenRefreshApi>(),
          logger: gh<_i895.AppLogger>(),
        ));
    gh.factory<_i131.RestoreSessionUseCase>(
        () => _i131.RestoreSessionUseCase(gh<_i812.SessionStore>()));
    gh.lazySingleton<_i1063.AuthRepository>(() => _i953.AuthRepositoryImpl(
          gh<_i244.AuthApi>(),
          gh<_i895.AppEnvironmentConfig>(),
          gh<_i895.FailureMapper>(),
        ));
    gh.factory<_i131.SignInUseCase>(() => _i131.SignInUseCase(
          gh<_i1063.AuthRepository>(),
          gh<_i812.SessionStore>(),
        ));
    gh.factory<_i131.SignOutUseCase>(() => _i131.SignOutUseCase(
          gh<_i1063.AuthRepository>(),
          gh<_i812.SessionStore>(),
        ));
    gh.factory<_i928.LoginBloc>(
        () => _i928.LoginBloc(gh<_i131.SignInUseCase>()));
  }
}
