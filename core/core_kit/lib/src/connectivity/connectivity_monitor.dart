import 'dart:async';

/// Whether the app can actually reach the backend.
///
/// Note what this is *not*: it is not "the device has a wifi or cellular
/// interface". That is what the OS reports, and it is wrong often enough to
/// matter — hotel captive portals, corporate wifi that needs a VPN, and a
/// cellular connection with no data allowance all report "connected" while
/// every request fails.
enum ConnectivityStatus {
  /// Interface up **and** the backend answered.
  online,

  /// No interface, or an interface that cannot reach the backend.
  offline,

  /// Startup, before the first check resolves. The banner stays hidden — a
  /// cold start must not flash "no connection" before it knows.
  unknown,
}

/// The app's single source of truth for connectivity.
///
/// Two inputs feed it:
///   1. the OS interface stream, which is instant but only says an interface
///      exists;
///   2. hints from the transport — a request that failed to connect, or one
///      that succeeded. Real traffic is the most reliable reachability signal
///      there is, and it costs nothing extra.
///
/// A probe is only made when those two disagree, so the common case adds no
/// requests at all.
abstract interface class ConnectivityMonitor {
  ConnectivityStatus get status;

  bool get isOffline;

  /// Broadcast: the banner, a retry-on-reconnect listener, and analytics can
  /// all subscribe.
  Stream<ConnectivityStatus> get changes;

  /// Begins watching. Called once during bootstrap.
  Future<void> start();

  /// Forces a check now — for a manual "retry" button.
  Future<ConnectivityStatus> check();

  /// Transport hint: a request could not open a connection.
  ///
  /// Deliberately not taken at face value. One failed request can mean a single
  /// bad endpoint, so this schedules a probe rather than declaring the device
  /// offline.
  void reportUnreachable();

  /// Transport hint: a request completed. This *is* taken at face value —
  /// a response is proof of reachability.
  void reportReachable();

  Future<void> dispose();
}

/// No-op implementation, for tests and for apps that have not wired
/// connectivity yet. Always reports [ConnectivityStatus.online] so nothing
/// blocks.
final class NoopConnectivityMonitor implements ConnectivityMonitor {
  const NoopConnectivityMonitor();

  @override
  ConnectivityStatus get status => ConnectivityStatus.online;

  @override
  bool get isOffline => false;

  @override
  Stream<ConnectivityStatus> get changes => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<ConnectivityStatus> check() async => ConnectivityStatus.online;

  @override
  void reportUnreachable() {}

  @override
  void reportReachable() {}

  @override
  Future<void> dispose() async {}
}
