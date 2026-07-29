import 'dart:convert';

import 'package:core_kit/core_kit.dart';
import 'package:core_storage/src/key_value_store.dart';

/// Process-lifetime store. Two jobs:
///   * the default fake in unit tests, so no package needs a plugin mock;
///   * a real cache for values that must not outlive the process (a decrypted
///     payload, an in-flight OTP challenge).
final class InMemoryStore implements SecureStore, PreferenceStore {
  InMemoryStore([Map<String, Object?>? seed]) : _data = {...?seed};

  final Map<String, Object?> _data;

  /// Set to fail every operation, to exercise the [CacheFailure] paths that are
  /// otherwise unreachable in a test.
  Failure? failWith;

  Map<String, Object?> get snapshot => Map.unmodifiable(_data);

  Result<T> _guard<T>(T Function() body) {
    final failure = failWith;
    if (failure != null) return Err<T>(failure);
    return Result.guard(
      body,
      onError: (e, s) => CacheFailure(debugMessage: e.toString(), cause: e, stackTrace: s),
    );
  }

  @override
  Future<Result<String?>> readString(String key) async => _guard(() => _data[key] as String?);

  @override
  Future<Result<Unit>> writeString(String key, String value) async => _guard(() {
    _data[key] = value;
    return unit;
  });

  @override
  Future<Result<bool?>> readBool(String key) async => _guard(() => _data[key] as bool?);

  @override
  Future<Result<Unit>> writeBool(String key, {required bool value}) async => _guard(() {
    _data[key] = value;
    return unit;
  });

  @override
  Future<Result<int?>> readInt(String key) async => _guard(() => _data[key] as int?);

  @override
  Future<Result<Unit>> writeInt(String key, int value) async => _guard(() {
    _data[key] = value;
    return unit;
  });

  @override
  Future<Result<Map<String, Object?>?>> readJson(String key) async => _guard(() {
    final raw = _data[key];
    if (raw == null) return null;
    if (raw is Map<String, Object?>) return raw;
    final text = raw as String;
    // Blank text reads as absent, the same as the two real stores. This class
    // stood alone in returning a CacheFailure here, which is the worst kind of
    // divergence in a fake: a repository test passes against InMemoryStore and
    // the identical code fails on device. `runKeyValueStoreContract` runs the
    // same expectations against all three so it cannot drift again.
    if (text.isBlank) return null;
    return jsonDecode(text) as Map<String, Object?>;
  });

  @override
  Future<Result<Unit>> writeJson(String key, Map<String, Object?> value) async => _guard(() {
    _data[key] = jsonEncode(value);
    return unit;
  });

  @override
  Future<Result<bool>> containsKey(String key) async => _guard(() => _data.containsKey(key));

  @override
  Future<Result<Unit>> remove(String key) async => _guard(() {
    _data.remove(key);
    return unit;
  });

  @override
  Future<Result<Unit>> clear() async => _guard(() {
    _data.clear();
    return unit;
  });
}
