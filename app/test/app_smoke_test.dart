import 'dart:convert';

import 'package:app/app/app.dart';
import 'package:app/app/bootstrap.dart';
import 'package:app/app/di/injection.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The test that was missing.
//
// Every other gate in this repo — `analyze`, `test`, `check-deps` — passed while
// the app could not open: `core_ui` carried a `@lazySingleton` but had no
// micro-package module, so `getIt<LoadingOverlayController>()` in `App.build`
// threw on the first frame and the user saw a white screen.
//
// Nothing here asserts business behaviour. It runs the *real* bootstrap and
// builds the *real* widget tree, because the entire class of bug it exists to
// catch — a missing registration, a broken theme extension, a router that
// cannot resolve its initial location — is invisible to a unit test and only
// appears when something actually builds.
//
// No HTTP is stubbed. `core_network` deliberately does not export the Dio
// adapter, so a test that reaches the network here hangs on a real socket
// rather than failing. Keep every path in this file off the wire.

/// The keychain the app boots against. Seeded per test, so a suite can boot
/// signed out, signed in, or with a payload from an older build.
late Map<String, String> _keychain;

Future<Object?> _secureStorageStub(MethodCall call) async {
  final arguments = (call.arguments as Map?)?.cast<String, Object?>() ?? const {};
  final key = arguments['key'] as String?;

  return switch (call.method) {
    'readAll' => Map<String, String>.from(_keychain),
    'read' => _keychain[key],
    'write' => _keychain[key!] = arguments['value']! as String,
    'delete' => _keychain.remove(key),
    'containsKey' => _keychain.containsKey(key),
    _ => null,
  };
}

/// A persisted session in the shape `SessionStoreImpl` writes, under the key it
/// writes it to. Built from the real `toStorageJson` rather than a hand-written
/// literal, so a change to the stored shape cannot leave this fixture behind.
String _storedSession({DateTime? expiresAt}) => jsonEncode(
  AuthSession(
    accessToken: 'stored-access-token',
    refreshToken: 'stored-refresh-token',
    expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
    user: const AuthUser(id: 'u1', email: 'signed.in@example.com', displayName: 'Signed In'),
  ).toStorageJson(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _keychain = {};

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
  });

  tearDown(getIt.reset);

  testWidgets('the app boots and renders its first screen', (tester) async {
    final bootstrap = await Bootstrap.run();

    await tester.pumpWidget(App(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    // Any exception thrown while building would be recorded here rather than
    // surfacing as a failed matcher, so it is checked explicitly and first.
    expect(tester.takeException(), isNull);

    // No stored session, so the guard resolves splash to login. Asserting the
    // destination — not merely "something rendered" — is what proves the
    // router, the guards and the session all agreed on a location.
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('the overlay host is mounted above the router', (tester) async {
    // The specific regression: this widget resolves LoadingOverlayController
    // from getIt during MaterialApp.router's builder, on the first frame.
    final bootstrap = await Bootstrap.run();

    await tester.pumpWidget(App(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(LoadingOverlayHost), findsOneWidget);
  });

  testWidgets('a stored session lands on home without flashing login', (tester) async {
    _keychain['auth.session'] = _storedSession();

    final bootstrap = await Bootstrap.run();
    await tester.pumpWidget(App(bootstrap: bootstrap));

    // Checked on the first frame, before pumpAndSettle: the reason
    // `Bootstrap.run` awaits `session.restore()` is that a signed-in user must
    // never see login, not even for one frame. Settling first would hide
    // exactly that regression.
    await tester.pump();
    expect(find.text('Welcome back'), findsNothing, reason: 'the login screen flashed before the redirect resolved');

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Signed In'), findsOneWidget);
  });

  testWidgets('a session stored by an older build is discarded, not fatal', (tester) async {
    // What a shipped schema change looks like on a device that already has the
    // old payload. Landing on login is correct; crashing on every launch with
    // no way out but reinstalling is not.
    _keychain['auth.session'] = jsonEncode({'accessToken': 'only-this-field-survived'});

    final bootstrap = await Bootstrap.run();
    await tester.pumpWidget(App(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Welcome back'), findsOneWidget);

    // And the unreadable payload is cleared, so the next launch does not repeat
    // the parse.
    expect(_keychain.containsKey('auth.session'), isFalse);
  });

  testWidgets('an unparseable keychain entry does not stop the app opening', (tester) async {
    _keychain['auth.session'] = '{ this is not json';

    final bootstrap = await Bootstrap.run();
    await tester.pumpWidget(App(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('a mini-app opens from home with its own dependencies resolved', (tester) async {
    _keychain['auth.session'] = _storedSession();

    final bootstrap = await Bootstrap.run();
    await tester.pumpWidget(App(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    // This is the mini-app equivalent of the injectable generator's
    // "I cannot see this registration" warning, which mini-apps do not get:
    // they register at runtime through `registerDependencies(getIt, host)`
    // rather than through a micro-package module, so nothing at build time
    // notices a missing one. Opening the screen for real does.
    //
    // Deliberately driven through the entry point rather than by navigating to
    // the path directly — that exercises MiniAppRegistry.entryPointsFor, the
    // host's rendering of it, and onOpen, which is the whole install path.
    await tester.tap(find.text('Articles'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'a mini-app dependency was never registered');
    expect(find.textContaining('Sample article #1'), findsOneWidget);
  });

  testWidgets('losing the session mid-run redirects off the protected screen', (tester) async {
    _keychain['auth.session'] = _storedSession();

    final bootstrap = await Bootstrap.run();
    await tester.pumpWidget(App(bootstrap: bootstrap));
    await tester.pumpAndSettle();
    expect(find.text('Signed In'), findsOneWidget);

    // Drives the whole chain the guard depends on: the store publishes on
    // `changes`, SessionCubit re-emits, SessionRefreshListenable notifies, and
    // go_router re-evaluates its redirect. A break anywhere along it leaves a
    // signed-out user sitting on a protected screen, which no unit test here
    // would notice.
    //
    // Cleared through the store rather than by calling `session.signOut()`,
    // because sign-out calls the API and nothing in this file stubs HTTP — the
    // Dio adapter is transport detail that `core_network` deliberately does not
    // export, so a test that took that path would hang on a real socket. What
    // the API call itself does is covered in feature_auth.
    await getIt<SessionStore>().clear();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
