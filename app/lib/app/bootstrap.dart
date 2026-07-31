import 'dart:async';

import 'package:app/app/di/injection.dart';
import 'package:app/app/mini_apps/app_mini_app_host.dart';
import 'package:app/app/session/session_cubit.dart';
import 'package:app/app/theme/theme_mode_controller.dart';
import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:mini_app_contract/mini_app_contract.dart';

/// Everything that must happen before the first frame, and nothing else.
///
/// The split is the point. Work that blocks startup is listed here explicitly;
/// anything else — analytics, push registration, remote config — belongs in
/// [runDeferredStartup] and runs after the first frame. That is what keeps
/// cold start from creeping up by 200ms per SDK somebody adds.
///
/// `core_arch` once carried a `BootstrapStep` / `BootstrapRunner` pair
/// generalising exactly this, with a `blocksFirstFrame` flag per step. It was
/// deleted unused. A step's `run(GetIt)` returned `Future<void>`, so it could
/// not produce the [BootstrapResult] this function exists to build — adopting
/// it would have meant pushing the registry and the session through the
/// container just to satisfy the shape. Startup here is a short sequence with
/// real data flow, not a list of independent side effects. Keep it a plain
/// function; if a third phase is ever needed, add it here.
final class Bootstrap {
  const Bootstrap._();

  static Future<BootstrapResult> run() async {
    WidgetsFlutterBinding.ensureInitialized();

    await configureDependencies();

    final logger = getIt<AppLogger>();
    final session = getIt<SessionCubit>();

    // Not awaited: the first probe costs a round trip, and a cold start on a
    // slow network must not wait for it to draw the first frame. The banner
    // stays hidden until the check resolves.
    unawaited(getIt<ConnectivityMonitor>().start());

    // Dev-only: seeds a session before the router's first redirect runs, so
    // `SessionGuard` sees an authenticated user and the login screen is never
    // shown. Gated by `DEV_AUTH_BYPASS` in `env_config/dev/dart_defines.json`.
    if (getIt<AppEnvironmentConfig>().devAuthBypass) {
      await getIt<SessionStore>().save(AuthSession.devBypass());
    }

    // Blocking on purpose: the router's first redirect must already know
    // whether a session exists, or a signed-in user sees the login screen flash.
    await session.restore();

    // Same reasoning, one frame earlier: restoring the theme after the first
    // frame means a user who chose dark watches the app flash light on every
    // cold start. It is a single `SharedPreferences` read against an instance
    // the container has already resolved, so it costs no round trip.
    final themeMode = getIt<ThemeModeController>();
    await themeMode.restore();

    final navigator = _LateNavigator();
    final host = AppMiniAppHost(
      session: session,
      navigator: navigator,
      locale: WidgetsBinding.instance.platformDispatcher.locale,
      featureFlags: const {},
    );

    // The only place a mini-app package is named. Adding one is a line here
    // plus a pubspec dependency — that is the whole installation cost, and the
    // reason this list is empty rather than the mechanism being deleted.
    //
    // Empty on purpose: this base ships no mini-app. The contract, the registry
    // and the host adapter stay, so a package built against
    // `mini_app_contract` drops in here without any of them being rebuilt
    // first. ADR-0007 has the condition under which that is worth doing.
    final registry = MiniAppRegistry(const [], logger: logger)..registerDependencies(getIt, host);

    logger.info('bootstrap complete for ${getIt<AppEnvironmentConfig>().environment.name}', tag: 'startup');
    return BootstrapResult(
      registry: registry,
      session: session,
      themeMode: themeMode,
      connectivity: getIt<ConnectivityMonitor>(),
      navigatorBinder: navigator.bind,
    );
  }

  /// Runs after the first frame. Failures here are logged, never fatal — a push
  /// registration that fails offline must not stop the app from opening.
  static Future<void> runDeferredStartup() async {
    final logger = getIt<AppLogger>();
    try {
      // Register analytics, crash reporting, push tokens and remote config here.
      logger.debug('deferred startup complete', tag: 'startup');
    } catch (error, stack) {
      logger.error('deferred startup failed', tag: 'startup', error: error, stackTrace: stack);
    }
  }
}

@immutable
final class BootstrapResult {
  const BootstrapResult({
    required this.registry,
    required this.session,
    required this.themeMode,
    required this.connectivity,
    required this.navigatorBinder,
  });

  final MiniAppRegistry registry;
  final SessionCubit session;

  /// Already restored when this is handed to `App`, so the first frame paints
  /// in the theme the user chose rather than switching into it.
  final ThemeModeController themeMode;

  final ConnectivityMonitor connectivity;

  /// Called once the router exists, to complete the deferred navigator.
  final void Function(AppNavigator navigator) navigatorBinder;
}

/// Resolves the chicken-and-egg between the router and the mini-apps.
///
/// Mini-apps are registered before the router is built (their routes are an
/// input to it), but they need an [AppNavigator] that only exists afterwards.
/// This forwards to the real navigator once it is bound, and asserts loudly if
/// something navigates before that — which would be a startup-order bug.
final class _LateNavigator implements AppNavigator {
  AppNavigator? _delegate;

  void bind(AppNavigator navigator) => _delegate = navigator;

  AppNavigator get _target {
    final delegate = _delegate;
    assert(delegate != null, 'AppNavigator used before the router was built.');
    return delegate!;
  }

  @override
  void goNamed(
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? extra,
  }) => _target.goNamed(name, pathParameters: pathParameters, queryParameters: queryParameters, extra: extra);

  @override
  Future<T?> pushNamed<T>(
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? extra,
  }) => _target.pushNamed<T>(name, pathParameters: pathParameters, queryParameters: queryParameters, extra: extra);

  @override
  void go(String location, {Object? extra}) => _target.go(location, extra: extra);

  @override
  void pop<T>([T? result]) => _target.pop<T>(result);

  @override
  bool canPop() => _target.canPop();

  @override
  String get currentLocation => _target.currentLocation;
}
