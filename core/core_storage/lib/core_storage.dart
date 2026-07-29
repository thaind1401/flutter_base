/// Key-value persistence behind narrow interfaces.
///
/// Consumers depend on [KeyValueStore] / [SecureStore] / [PreferenceStore],
/// never on `flutter_secure_storage` or `shared_preferences` directly.
library core_storage;

export 'di.module.dart' show CoreStoragePackageModule;
export 'src/in_memory_store.dart';
export 'src/key_value_store.dart';
export 'src/preference_store_impl.dart';
export 'src/secure_store_impl.dart';
