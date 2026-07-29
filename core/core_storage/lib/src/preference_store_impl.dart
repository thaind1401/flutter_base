import 'dart:async';
import 'dart:convert';

import 'package:core_kit/core_kit.dart';
import 'package:core_storage/src/key_value_store.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences`-backed store for non-sensitive values.
///
/// The [SharedPreferences] instance is injected rather than resolved lazily
/// inside each method: `getInstance()` touches a platform channel, and doing
/// that on every read turns a synchronous-looking cache into a source of jank.
/// The composition root awaits it once during startup.
@LazySingleton(as: PreferenceStore)
final class PreferenceStoreImpl implements PreferenceStore {
  const PreferenceStoreImpl(this._prefs);

  final SharedPreferences _prefs;

  /// Resolved once by the DI module during app bootstrap.
  static Future<SharedPreferences> open() => SharedPreferences.getInstance();

  Future<Result<T>> _guard<T>(FutureOr<T> Function() body) => Result.guardAsync(
    body,
    onError: (e, s) => CacheFailure(debugMessage: 'preferences: $e', cause: e, stackTrace: s),
  );

  @override
  Future<Result<String?>> readString(String key) => _guard(() => _prefs.getString(key));

  @override
  Future<Result<Unit>> writeString(String key, String value) => _guard(() async {
    await _prefs.setString(key, value);
    return unit;
  });

  @override
  Future<Result<bool?>> readBool(String key) => _guard(() => _prefs.getBool(key));

  @override
  Future<Result<Unit>> writeBool(String key, {required bool value}) => _guard(() async {
    await _prefs.setBool(key, value);
    return unit;
  });

  @override
  Future<Result<int?>> readInt(String key) => _guard(() => _prefs.getInt(key));

  @override
  Future<Result<Unit>> writeInt(String key, int value) => _guard(() async {
    await _prefs.setInt(key, value);
    return unit;
  });

  @override
  Future<Result<Map<String, Object?>?>> readJson(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isBlank) return const Ok<Map<String, Object?>?>(null);
    return Result.guard<Map<String, Object?>?>(
      () => jsonDecode(raw) as Map<String, Object?>,
      onError: (e, s) => CacheFailure(debugMessage: 'corrupt json at "$key": $e', cause: e, stackTrace: s),
    );
  }

  @override
  Future<Result<Unit>> writeJson(String key, Map<String, Object?> value) => writeString(key, jsonEncode(value));

  @override
  Future<Result<bool>> containsKey(String key) => _guard(() => _prefs.containsKey(key));

  @override
  Future<Result<Unit>> remove(String key) => _guard(() async {
    await _prefs.remove(key);
    return unit;
  });

  @override
  Future<Result<Unit>> clear() => _guard(() async {
    await _prefs.clear();
    return unit;
  });
}
