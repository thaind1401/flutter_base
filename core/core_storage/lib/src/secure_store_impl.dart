import 'dart:convert';

import 'package:core_kit/core_kit.dart';
import 'package:core_storage/src/key_value_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Keychain (iOS) / EncryptedSharedPreferences (Android) backed store.
///
/// Every read is defensive on purpose. The keystore genuinely fails in the
/// field: a device restored from backup, a user who changed their lock screen,
/// an Android keystore invalidated by a biometric enrolment. Those surface as
/// platform exceptions that would otherwise crash startup, so they are mapped
/// to [CacheFailure] and the caller treats them as "no value stored".
@LazySingleton(as: SecureStore)
final class SecureStoreImpl implements SecureStore {
  const SecureStoreImpl(this._storage);

  final FlutterSecureStorage _storage;

  /// The options this base ships with.
  ///
  /// `first_unlock` rather than the default `unlocked`: a background fetch or a
  /// push handler runs while the device is locked and still has to read the
  /// refresh token. `encryptedSharedPreferences` puts the Android side in the
  /// keystore instead of a plain XML file.
  static const FlutterSecureStorage defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<Result<T>> _guard<T>(Future<T> Function() body) => Result.guardAsync(
    body,
    onError: (e, s) => CacheFailure(debugMessage: 'secure storage: $e', cause: e, stackTrace: s),
  );

  @override
  Future<Result<String?>> readString(String key) => _guard(() => _storage.read(key: key));

  @override
  Future<Result<Unit>> writeString(String key, String value) => _guard(() async {
    await _storage.write(key: key, value: value);
    return unit;
  });

  @override
  Future<Result<bool?>> readBool(String key) async =>
      (await readString(key)).map((raw) => raw == null ? null : raw == 'true');

  @override
  Future<Result<Unit>> writeBool(String key, {required bool value}) => writeString(key, '$value');

  @override
  Future<Result<int?>> readInt(String key) async =>
      (await readString(key)).map((raw) => raw == null ? null : int.tryParse(raw));

  @override
  Future<Result<Unit>> writeInt(String key, int value) => writeString(key, '$value');

  @override
  Future<Result<Map<String, Object?>?>> readJson(String key) async => (await readString(key)).flatMap((raw) {
    if (raw == null || raw.isBlank) return const Ok<Map<String, Object?>?>(null);
    // A parse failure here means a model shipped without a migration. Report it
    // rather than silently returning null, so the caller can clear the key.
    return Result.guard<Map<String, Object?>?>(
      () => jsonDecode(raw) as Map<String, Object?>,
      onError: (e, s) => CacheFailure(debugMessage: 'corrupt json at "$key": $e', cause: e, stackTrace: s),
    );
  });

  @override
  Future<Result<Unit>> writeJson(String key, Map<String, Object?> value) => writeString(key, jsonEncode(value));

  @override
  Future<Result<bool>> containsKey(String key) => _guard(() => _storage.containsKey(key: key));

  @override
  Future<Result<Unit>> remove(String key) => _guard(() async {
    await _storage.delete(key: key);
    return unit;
  });

  @override
  Future<Result<Unit>> clear() => _guard(() async {
    await _storage.deleteAll();
    return unit;
  });
}
