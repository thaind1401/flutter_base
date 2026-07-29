import 'package:core_arch/src/navigation/route_module.dart';
import 'package:core_kit/core_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Assembles the app's [GoRouter] from independent [RouteModule]s and an
/// ordered list of [RouteGuard]s.
///
/// The host app owns *which* modules and guards exist; this owns *how* they
/// combine. Adding a feature is then a one-line change in the composition root
/// instead of an edit to a file that imports every screen.
final class AppRouterBuilder {
  const AppRouterBuilder({
    required this.modules,
    required this.initialLocation,
    this.guards = const [],
    this.shellBuilder,
    this.refreshListenable,
    this.errorBuilder,
    this.observers = const [],
    this.logger = const NoopLogger(),
    this.debugLogDiagnostics = false,
  });

  final List<RouteModule> modules;
  final String initialLocation;

  /// Evaluated in order; the first guard returning a location wins.
  final List<RouteGuard> guards;

  /// Wraps [RouteModule.shellRoutes] in the persistent chrome (bottom bar,
  /// drawer). Null means the app has no shell and every route is top level.
  final Widget Function(BuildContext context, GoRouterState state, Widget child)? shellBuilder;

  /// Something that notifies when a redirect decision could change — typically
  /// the session cubit. Without it, a sign-out leaves the user on a protected
  /// page until they navigate.
  final Listenable? refreshListenable;

  final Widget Function(BuildContext context, GoRouterState state)? errorBuilder;
  final List<NavigatorObserver> observers;
  final AppLogger logger;
  final bool debugLogDiagnostics;

  GoRouter build({GlobalKey<NavigatorState>? navigatorKey}) {
    final rootKey = navigatorKey ?? GlobalKey<NavigatorState>(debugLabel: 'root');

    final shellRoutes = [for (final module in modules) ...module.shellRoutes(rootNavigatorKey: rootKey)];
    final rootRoutes = [for (final module in modules) ...module.rootRoutes(rootNavigatorKey: rootKey)];

    _assertUniquePaths([...shellRoutes, ...rootRoutes]);

    return GoRouter(
      navigatorKey: rootKey,
      initialLocation: initialLocation,
      refreshListenable: refreshListenable,
      observers: observers,
      debugLogDiagnostics: debugLogDiagnostics,
      errorBuilder: errorBuilder,
      redirect: _runGuards,
      routes: [
        if (shellRoutes.isNotEmpty && shellBuilder != null)
          ShellRoute(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'shell'),
            builder: shellBuilder,
            routes: shellRoutes,
          )
        else
          ...shellRoutes,
        ...rootRoutes,
      ],
    );
  }

  String? _runGuards(BuildContext context, GoRouterState state) {
    for (final guard in guards) {
      final destination = guard.redirect(context, state);
      if (destination != null && destination != state.matchedLocation) {
        logger.debug('${guard.runtimeType} redirected ${state.matchedLocation} -> $destination', tag: 'router');
        return destination;
      }
    }
    return null;
  }

  /// Two modules registering the same path is a silent bug — go_router picks
  /// the first and the other feature's screen is simply unreachable. Assert in
  /// debug so it is found the first time the app starts.
  void _assertUniquePaths(List<RouteBase> routes) {
    assert(() {
      final seen = <String>{};
      void walk(List<RouteBase> list) {
        for (final route in list) {
          if (route is GoRoute && !seen.add(route.path)) {
            throw StateError('Duplicate route path "${route.path}" registered by two RouteModules.');
          }
          walk(route.routes);
        }
      }

      walk(routes);
      return true;
    }());
  }
}
