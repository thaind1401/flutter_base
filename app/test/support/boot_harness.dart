import 'dart:convert';

import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The platform stubs `Bootstrap.run()` needs to complete in a widget test.
///
/// Extracted so that more than one suite can boot the real app without copying
/// three channel mocks. Nothing here stubs HTTP: `core_network` deliberately
/// withholds the Dio adapter from its main barrel, so a test that reaches the
/// network hangs on a real socket rather than failing. Keep every path off the
/// wire.

/// The keychain the app boots against. Seeded per test, so a suite can boot
/// signed out, signed in, or with a payload from an older build.
late Map<String, String> keychain;

/// Installs the mocks and resets the keychain. Call from `setUp`.
void installPlatformMocks() {
  SharedPreferences.setMockInitialValues({});
  keychain = {};

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    _secureStorageStub,
  );

  // Connectivity is probed during bootstrap without being awaited. Left
  // unmocked it raises MissingPluginException as an unhandled async error,
  // which fails the test for a reason that has nothing to do with the app.
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (call) async => call.method == 'check' ? <String>['wifi'] : null,
  );
  messenger.setMockStreamHandler(
    const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
    MockStreamHandler.inline(onListen: (arguments, events) => events.success(<String>['wifi'])),
  );
}

Future<Object?> _secureStorageStub(MethodCall call) async {
  final arguments = (call.arguments as Map?)?.cast<String, Object?>() ?? const {};
  final key = arguments['key'] as String?;

  return switch (call.method) {
    'readAll' => Map<String, String>.from(keychain),
    'read' => keychain[key],
    'write' => keychain[key!] = arguments['value']! as String,
    'delete' => keychain.remove(key),
    'containsKey' => keychain.containsKey(key),
    _ => null,
  };
}

/// A persisted session in the shape `SessionStoreImpl` writes, under the key it
/// writes it to. Built from the real `toStorageJson` rather than a hand-written
/// literal, so a change to the stored shape cannot leave this fixture behind.
String storedSession({DateTime? expiresAt}) => jsonEncode(
  AuthSession(
    accessToken: 'stored-access-token',
    refreshToken: 'stored-refresh-token',
    expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
    user: const AuthUser(id: 'u1', email: 'signed.in@example.com', displayName: 'Signed In'),
  ).toStorageJson(),
);
