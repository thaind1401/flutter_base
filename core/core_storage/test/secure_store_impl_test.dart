import 'package:core_kit/core_kit.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'key_value_store_contract.dart';

/// The plugin's platform channel. Faked rather than mocked so the store is
/// exercised through the same call sequence it makes on device.
const MethodChannel _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> keychain;

  /// Set to make the next platform call throw, standing in for a keystore the
  /// OS has invalidated.
  Never Function(MethodCall call)? platformFailure;

  setUp(() {
    keychain = {};
    platformFailure = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      platformFailure?.call(call);

      final arguments = (call.arguments as Map?)?.cast<String, Object?>() ?? const {};
      final key = arguments['key'] as String?;

      switch (call.method) {
        case 'read':
          return keychain[key];
        case 'write':
          return keychain[key!] = arguments['value']! as String;
        case 'delete':
          return keychain.remove(key);
        case 'deleteAll':
          keychain.clear();
          return null;
        case 'containsKey':
          return keychain.containsKey(key);
        case 'readAll':
          return Map<String, String>.from(keychain);
        default:
          return null;
      }
    });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null),
  );

  runKeyValueStoreContract('SecureStoreImpl', () => const SecureStoreImpl(FlutterSecureStorage()));

  group('SecureStoreImpl extras', () {
    late SecureStore store;

    setUp(() => store = const SecureStoreImpl(FlutterSecureStorage()));

    test('a keystore that throws becomes a CacheFailure, not a crash', () async {
      // The real reason this class guards every call: a device restored from
      // backup, or an Android keystore invalidated by a new fingerprint, throws
      // here. Startup reads the refresh token — an uncaught throw is a boot loop.
      platformFailure = (_) => throw PlatformException(code: 'KeystoreException', message: 'key invalidated');

      final result = await store.readString('refresh_token');

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<CacheFailure>());
    });

    test('a failing write is reported rather than silently dropped', () async {
      platformFailure = (_) => throw PlatformException(code: 'IOException');

      expect((await store.writeString('refresh_token', 'secret')).isErr, isTrue);
    });

    test('the failure message does not carry the stored value', () async {
      // A CacheFailure ends up in logs. The key name is diagnostic; the token
      // is not, and must not ride along into a log line.
      platformFailure = (_) => throw PlatformException(code: 'IOException', message: 'disk full');

      final failure = (await store.writeString('refresh_token', 'super-secret-token')).failureOrNull;

      expect(failure, isA<CacheFailure>());
      expect((failure! as CacheFailure).debugMessage, isNot(contains('super-secret-token')));
    });

    test('booleans are stored as text, which is what the keychain accepts', () async {
      await store.writeBool('biometrics', value: true);

      // Asserted against the backing map rather than through readBool, because
      // the encoding is the part that differs from InMemoryStore. A repository
      // tested only against the fake would not notice.
      expect(keychain['biometrics'], 'true');
      expect((await store.readBool('biometrics')).valueOrNull, isTrue);
    });

    test('a non-numeric int reads as null instead of throwing', () async {
      await store.writeString('count', 'not-a-number');
      expect((await store.readInt('count')).valueOrNull, isNull);
    });

    test('defaultStorage keeps the token readable while the device is locked', () {
      // Background fetch and push handlers run before first unlock is over. If
      // this ever regresses to `unlocked`, refresh silently fails in the field
      // and only shows up as unexplained logouts.
      //
      // Read through `params`, the map the plugin actually sends over the
      // channel, because the options themselves keep their fields private.
      expect(SecureStoreImpl.defaultStorage.iOptions.params['accessibility'], 'first_unlock');
      expect(SecureStoreImpl.defaultStorage.aOptions.params['encryptedSharedPreferences'], 'true');
    });
  });
}
