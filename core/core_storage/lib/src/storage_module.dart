import 'package:core_storage/src/in_memory_store.dart';
import 'package:core_storage/src/preference_store_impl.dart';
import 'package:core_storage/src/secure_store_impl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Third-party objects this package needs registered.
///
/// `SharedPreferences` is `@preResolve`d so the container awaits it once during
/// bootstrap; every consumer then gets a ready instance by constructor
/// injection instead of awaiting a channel call at use time.
@module
abstract class StorageModule {
  @preResolve
  @lazySingleton
  Future<SharedPreferences> get sharedPreferences => PreferenceStoreImpl.open();

  /// Registered here rather than constructed inside [SecureStoreImpl] so a test
  /// can inject a fake without reaching into the implementation.
  @lazySingleton
  FlutterSecureStorage get secureStorage => SecureStoreImpl.defaultStorage;

  /// Volatile scratch space, distinct from the two persistent stores. Register
  /// it by concrete type so a caller that wants "cleared on restart" has to ask
  /// for it explicitly and cannot get it by accident.
  @lazySingleton
  InMemoryStore get inMemoryStore => InMemoryStore();
}
