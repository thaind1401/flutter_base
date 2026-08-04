import 'dart:io';

import 'package:app/app/di/device_request_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

// This ran on every outbound request and had one line of nineteen covered.
//
// What is worth guarding is the caching, not the header strings: the class
// exists because `onRequest` fires per call, and the comment on it says that
// reaching a platform channel there "can deadlock during startup". A refactor
// that drops the `??=` leaves every header still correct and every other test
// still green, which is precisely the shape of change nobody catches by reading.
//
// The Android and iOS branches are not reachable here — `flutter test` runs on
// the host, so `Platform.isAndroid` and `Platform.isIOS` are both false and the
// desktop fallback is what executes. Covering those needs `make integration` on
// a real device, and pretending otherwise by stubbing `Platform` would test the
// stub.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'flutter_base',
      packageName: 'com.example.flutterbase',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
  });

  test('collects once and reuses the result', () async {
    final context = DeviceRequestContext();

    final first = await context.headers();
    final second = await context.headers();

    // Identity, not equality: two equal maps would also be produced by
    // collecting twice, which is the thing this class exists to avoid.
    expect(identical(first, second), isTrue, reason: 'headers were collected a second time');
  });

  test('carries the app version as name+build', () async {
    final headers = await DeviceRequestContext().headers();

    // Backends split on the `+`, so the shape matters more than the values.
    expect(headers['X-App-Version'], '1.2.3+45');
  });

  test('sends every header the API expects, with nothing blank', () async {
    final headers = await DeviceRequestContext().headers();

    expect(
      headers.keys,
      containsAll(<String>['X-Device-Id', 'X-Device-Model', 'X-Device-Os', 'X-App-Version', 'X-Platform']),
    );
    // A header present but empty is worse than absent: it looks supplied.
    expect(headers.values.every((value) => value.isNotEmpty), isTrue);
  });

  test('reports the host platform rather than guessing mobile', () async {
    final headers = await DeviceRequestContext().headers();

    expect(headers['X-Platform'], Platform.operatingSystem);
  });

  test('sends a language tag the backend can parse', () async {
    final headers = await DeviceRequestContext().headers();

    // `Accept-Language` is a BCP 47 tag — `en-US`, not `en_US`. The underscore
    // form is what `Locale.toString()` produces and it is not valid here.
    expect(headers['Accept-Language'], isNot(contains('_')));
  });
}
