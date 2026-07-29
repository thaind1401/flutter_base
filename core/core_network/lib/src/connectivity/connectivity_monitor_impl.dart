import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core_kit/core_kit.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart' as di;

/// Reachability probe. Injected so tests never touch the network.
typedef ReachabilityProbe = Future<bool> Function();

/// Deliberately not self-registered. Its inputs — the environment config and
/// the logger — are app-wide primitives owned by the composition root, so the
/// registration lives in `app/lib/app/di/app_module.dart` alongside
/// `ApiClient`, for exactly the same reason.
final class ConnectivityMonitorImpl implements ConnectivityMonitor {
  /// Full constructor, used by tests: the platform channel, the probe and both
  /// timings are injectable so a test never touches the network or the clock.
  ConnectivityMonitorImpl(
    AppEnvironmentConfig config, {
    Connectivity? connectivity,
    ReachabilityProbe? probe,
    AppLogger logger = const NoopLogger(),
    this.offlineDebounce = const Duration(milliseconds: 1200),
    this.probeCooldown = const Duration(seconds: 5),
  }) : _connectivity = connectivity ?? Connectivity(),
       _logger = logger,
       _probe = probe ?? _defaultProbe(config);

  /// The constructor the composition root uses: production defaults, no
  /// test-only knobs.
  ConnectivityMonitorImpl.resolve(AppEnvironmentConfig config, AppLogger logger) : this(config, logger: logger);

  /// Delay before an offline result is published.
  ///
  /// Handing off between wifi and cellular drops the interface for a few
  /// hundred milliseconds. Publishing immediately makes the banner flicker on
  /// every walk out of the office, which trains users to ignore it.
  final Duration offlineDebounce;

  /// Floor on how often a probe may run, so a burst of failing requests turns
  /// into one probe rather than twenty.
  final Duration probeCooldown;

  final Connectivity _connectivity;
  final AppLogger _logger;
  final ReachabilityProbe _probe;

  final StreamController<ConnectivityStatus> _changes = StreamController<ConnectivityStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _offlineTimer;
  DateTime? _lastProbe;
  Future<ConnectivityStatus>? _inFlightProbe;

  ConnectivityStatus _status = ConnectivityStatus.unknown;

  /// A bare client: no auth, no retry, no logging. A probe must not refresh a
  /// token, and it must not be retried by the very interceptor that is asking
  /// whether the network is up.
  static ReachabilityProbe _defaultProbe(AppEnvironmentConfig config) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        // Short on purpose: this answers "is the network up", and a 30-second
        // wait to draw a banner is useless.
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        // Any HTTP answer proves reachability — even 404 or 401. Only a
        // transport failure counts as offline.
        validateStatus: (_) => true,
      ),
    );
    return () async {
      try {
        await dio.head<void>('/');
        return true;
      } on DioException catch (error) {
        return switch (error.type) {
          DioExceptionType.connectionError ||
          DioExceptionType.connectionTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.sendTimeout => false,
          // A bad certificate or an unparseable body still means the server
          // answered; the network is up and something else is wrong.
          _ => true,
        };
      } catch (_) {
        return false;
      }
    };
  }

  @override
  ConnectivityStatus get status => _status;

  @override
  bool get isOffline => _status == ConnectivityStatus.offline;

  @override
  Stream<ConnectivityStatus> get changes => _changes.stream;

  @override
  Future<void> start() async {
    _subscription ??= _connectivity.onConnectivityChanged.listen(_onInterfaceChanged);
    await check();
  }

  Future<void> _onInterfaceChanged(List<ConnectivityResult> results) async {
    final hasInterface = results.any((result) => result != ConnectivityResult.none);

    if (!hasInterface) {
      // The OS is authoritative about *no* interface — no probe can help.
      _scheduleOffline();
      return;
    }

    // An interface came back. It may still be a captive portal, so confirm
    // before telling the user they are online.
    await check(force: true);
  }

  @override
  Future<ConnectivityStatus> check({bool force = false}) async {
    final pending = _inFlightProbe;
    if (pending != null) return pending;

    final since = _lastProbe;
    if (!force && since != null && DateTime.now().difference(since) < probeCooldown) {
      return _status;
    }

    final future = _runProbe();
    _inFlightProbe = future;
    try {
      return await future;
    } finally {
      _inFlightProbe = null;
    }
  }

  Future<ConnectivityStatus> _runProbe() async {
    _lastProbe = DateTime.now();

    final results = await _connectivity.checkConnectivity();
    if (!results.any((result) => result != ConnectivityResult.none)) {
      _scheduleOffline();
      return ConnectivityStatus.offline;
    }

    final reachable = await _probe();
    if (reachable) {
      _publishNow(ConnectivityStatus.online);
      return ConnectivityStatus.online;
    }
    _scheduleOffline();
    return ConnectivityStatus.offline;
  }

  @override
  void reportUnreachable() {
    // One failed request is not proof: the endpoint may be down while the
    // network is fine. Confirm with a probe before blaming the connection.
    if (_status == ConnectivityStatus.offline) return;
    unawaited(check());
  }

  @override
  void reportReachable() {
    // A response is proof. Cancel any pending offline transition immediately.
    _offlineTimer?.cancel();
    _offlineTimer = null;
    _publishNow(ConnectivityStatus.online);
  }

  /// Publishes offline only if it is still true after [offlineDebounce].
  void _scheduleOffline() {
    if (_status == ConnectivityStatus.offline) return;
    _offlineTimer?.cancel();
    _offlineTimer = Timer(offlineDebounce, () => _publishNow(ConnectivityStatus.offline));
  }

  void _publishNow(ConnectivityStatus next) {
    // Any definitive result supersedes a pending one. Cancelling only on the
    // offline path left a scheduled offline transition alive after the network
    // came back, so a wifi-to-cellular handoff raised the banner a second later
    // — precisely the flicker the debounce exists to prevent.
    _offlineTimer?.cancel();
    _offlineTimer = null;

    if (_status == next) return;
    _status = next;
    _logger.info('connectivity → ${next.name}', tag: 'network');
    if (!_changes.isClosed) _changes.add(next);
  }

  @override
  @di.disposeMethod
  Future<void> dispose() async {
    _offlineTimer?.cancel();
    await _subscription?.cancel();
    await _changes.close();
  }
}
