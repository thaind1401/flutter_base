//@GeneratedMicroModule;CoreUiPackageModule;package:core_ui/di.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i687;

import 'package:core_ui/src/overlays/loading_overlay.dart' as _i631;
import 'package:injectable/injectable.dart' as _i526;

class CoreUiPackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i631.LoadingOverlayController>(
      () => _i631.LoadingOverlayController(),
      dispose: (i) => i.dispose(),
    );
  }
}
