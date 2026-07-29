//@GeneratedMicroModule;CoreStoragePackageModule;package:core_storage/di.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i687;

import 'package:core_storage/src/in_memory_store.dart' as _i377;
import 'package:core_storage/src/key_value_store.dart' as _i275;
import 'package:core_storage/src/preference_store_impl.dart' as _i975;
import 'package:core_storage/src/secure_store_impl.dart' as _i40;
import 'package:core_storage/src/storage_module.dart' as _i314;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

class CoreStoragePackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) async {
    final storageModule = _$StorageModule();
    await gh.lazySingletonAsync<_i460.SharedPreferences>(
      () => storageModule.sharedPreferences,
      preResolve: true,
    );
    gh.lazySingleton<_i558.FlutterSecureStorage>(
        () => storageModule.secureStorage);
    gh.lazySingleton<_i377.InMemoryStore>(() => storageModule.inMemoryStore);
    gh.lazySingleton<_i275.SecureStore>(
        () => _i40.SecureStoreImpl(gh<_i558.FlutterSecureStorage>()));
    gh.lazySingleton<_i275.PreferenceStore>(
        () => _i975.PreferenceStoreImpl(gh<_i460.SharedPreferences>()));
  }
}

class _$StorageModule extends _i314.StorageModule {}
