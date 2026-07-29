//@GeneratedMicroModule;CoreNetworkPackageModule;package:core_network/di.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i687;

import 'package:core_kit/core_kit.dart' as _i895;
import 'package:core_network/src/dio_failure_mapper.dart' as _i332;
import 'package:injectable/injectable.dart' as _i526;

class CoreNetworkPackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i895.FailureMapper>(() => const _i332.DioFailureMapper());
  }
}
