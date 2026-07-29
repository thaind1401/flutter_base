import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the platform channel: a test drives the interface state
/// directly instead of toggling a device's wifi.
final class _FakeConnectivity implements Connectivity {
  final StreamController<List<ConnectivityResult>> _controller = StreamController<List<ConnectivityResult>>.broadcast();

  List<ConnectivityResult> current = [ConnectivityResult.wifi];

  void emit(List<ConnectivityResult> results) {
    current = results;
    _controller.add(results);
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;

  Future<void> close() => _controller.close();
}

void main() {
  const config = AppEnvironmentConfig(environment: AppEnvironment.dev, baseUrl: 'https://api.test');

  late _FakeConnectivity connectivity;
  var probeResult = true;
  var probeCalls = 0;

  ConnectivityMonitorImpl build({
    Duration debounce = const Duration(milliseconds: 20),
    Duration cooldown = Duration.zero,
  }) => ConnectivityMonitorImpl(
    config,
    connectivity: connectivity,
    probe: () async {
      probeCalls++;
      return probeResult;
    },
    offlineDebounce: debounce,
    probeCooldown: cooldown,
  );

  setUp(() {
    connectivity = _FakeConnectivity();
    probeResult = true;
    probeCalls = 0;
  });

  tearDown(() => connectivity.close());

  test('starts unknown so a cold start does not flash "no connection"', () {
    final monitor = build();
    expect(monitor.status, ConnectivityStatus.unknown);
    expect(monitor.isOffline, isFalse);
  });

  test('start resolves to online when the probe succeeds', () async {
    final monitor = build();
    await monitor.start();
    expect(monitor.status, ConnectivityStatus.online);
    await monitor.dispose();
  });

  test('reports offline when there is no interface at all', () async {
    connectivity.current = [ConnectivityResult.none];
    final monitor = build();

    await monitor.start();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(monitor.status, ConnectivityStatus.offline);
    // No point probing when the OS says there is no interface.
    expect(probeCalls, 0);
    await monitor.dispose();
  });

  test('treats an interface that cannot reach the backend as offline', () async {
    // The captive-portal case: hotel wifi is "connected" and nothing works.
    probeResult = false;
    final monitor = build();

    await monitor.start();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(monitor.status, ConnectivityStatus.offline);
    expect(probeCalls, 1);
    await monitor.dispose();
  });

  test('debounces a brief interface drop so the banner does not flicker', () async {
    // Walking out of wifi onto cellular drops the interface for a moment.
    final monitor = build(debounce: const Duration(milliseconds: 80));
    await monitor.start();
    expect(monitor.status, ConnectivityStatus.online);

    connectivity.emit([ConnectivityResult.none]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(monitor.status, ConnectivityStatus.online, reason: 'still inside the debounce window');

    connectivity.emit([ConnectivityResult.mobile]);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(monitor.status, ConnectivityStatus.online);
    await monitor.dispose();
  });

  test('publishes offline when the drop outlasts the debounce', () async {
    final monitor = build(debounce: const Duration(milliseconds: 30));
    await monitor.start();

    connectivity.emit([ConnectivityResult.none]);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(monitor.status, ConnectivityStatus.offline);
    await monitor.dispose();
  });

  test('confirms with a probe before declaring the connection restored', () async {
    probeResult = false;
    final monitor = build(debounce: const Duration(milliseconds: 10));
    await monitor.start();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(monitor.status, ConnectivityStatus.offline);

    // The interface returns, but the portal is still in the way.
    connectivity.emit([ConnectivityResult.wifi]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(monitor.status, ConnectivityStatus.offline);

    probeResult = true;
    connectivity.emit([ConnectivityResult.wifi]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(monitor.status, ConnectivityStatus.online);

    await monitor.dispose();
  });

  group('transport hints', () {
    test('a successful response marks online immediately, with no probe', () async {
      probeResult = false;
      final monitor = build(debounce: const Duration(milliseconds: 10));
      await monitor.start();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(monitor.status, ConnectivityStatus.offline);

      final before = probeCalls;
      monitor.reportReachable();

      expect(monitor.status, ConnectivityStatus.online);
      expect(probeCalls, before, reason: 'a response is proof; no probe needed');
      await monitor.dispose();
    });

    test('a failed request triggers a probe rather than trusting one failure', () async {
      // One endpoint being down does not mean the device is offline.
      final monitor = build();
      await monitor.start();
      final before = probeCalls;

      monitor.reportUnreachable();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(probeCalls, greaterThan(before));
      expect(monitor.status, ConnectivityStatus.online, reason: 'the probe still succeeded');
      await monitor.dispose();
    });

    test('a burst of failures collapses into one probe', () async {
      final monitor = build(cooldown: const Duration(seconds: 5));
      await monitor.start();
      final before = probeCalls;

      for (var i = 0; i < 20; i++) {
        monitor.reportUnreachable();
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(probeCalls - before, lessThanOrEqualTo(1));
      await monitor.dispose();
    });
  });

  test('emits each status change once', () async {
    final monitor = build(debounce: const Duration(milliseconds: 10));
    final seen = <ConnectivityStatus>[];
    final subscription = monitor.changes.listen(seen.add);

    await monitor.start();
    monitor.reportReachable();
    monitor.reportReachable();

    connectivity.emit([ConnectivityResult.none]);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(seen, [ConnectivityStatus.online, ConnectivityStatus.offline]);
    await subscription.cancel();
    await monitor.dispose();
  });

  test('a manual check bypasses the cooldown', () async {
    final monitor = build(cooldown: const Duration(seconds: 30));
    await monitor.start();
    final before = probeCalls;

    // What the banner's retry button does — the user just fixed their wifi and
    // must not have to wait 30 seconds.
    await monitor.check(force: true);

    expect(probeCalls, before + 1);
    await monitor.dispose();
  });
}
