import 'package:core_kit/core_kit.dart';

/// The one storage abstraction the rest of the app codes against.
///
/// Why an interface rather than calling `SharedPreferences` directly:
///   * a repository can be unit-tested with [InMemoryStore], no plugin channel
///     and no `TestWidgetsFlutterBinding` needed;
///   * swapping the backing engine (Hive, Isar, sqflite) touches one file;
///   * every operation returns [Result], so a locked keystore or a corrupt
///     payload surfaces as a [CacheFailure] instead of an uncaught platform
///     exception in a random call site.
abstract interface class KeyValueStore {
  Future<Result<String?>> readString(String key);

  Future<Result<Unit>> writeString(String key, String value);

  Future<Result<bool?>> readBool(String key);

  Future<Result<Unit>> writeBool(String key, {required bool value});

  Future<Result<int?>> readInt(String key);

  Future<Result<Unit>> writeInt(String key, int value);

  /// Decoded JSON object. Returns `Ok(null)` when the key is absent and a
  /// [CacheFailure] when the stored text is no longer parseable — which happens
  /// after a model change ships without a migration.
  Future<Result<Map<String, Object?>?>> readJson(String key);

  Future<Result<Unit>> writeJson(String key, Map<String, Object?> value);

  Future<Result<bool>> containsKey(String key);

  Future<Result<Unit>> remove(String key);

  /// Wipes everything this store owns. Used on logout.
  Future<Result<Unit>> clear();
}

/// Marker for the store backed by the platform keychain/keystore.
/// Tokens, refresh tokens and biometric material go here — nothing else.
abstract interface class SecureStore implements KeyValueStore {}

/// Marker for the store backed by `SharedPreferences`/`NSUserDefaults`.
/// Preferences, feature flags and non-sensitive caches. Readable on a rooted
/// device, so never put credentials here.
abstract interface class PreferenceStore implements KeyValueStore {}
