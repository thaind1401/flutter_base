import 'package:core_arch/src/navigation/route_module.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigation for code that has no [BuildContext].
///
/// A push handler, a session expiry callback and a deep-link receiver all need
/// to navigate from outside the widget tree. Without this they reach for a
/// global navigator key, which is untestable and easy to use from a bloc where
/// a `context` was actually available. Here it is an injected interface with a
/// fake in tests.
///
/// Widgets should keep using `context.goNamed(...)` — this is for the rest.
abstract interface class AppNavigator {
  void goNamed(String name, {Map<String, String> pathParameters, Map<String, dynamic> queryParameters, Object? extra});

  Future<T?> pushNamed<T>(
    String name, {
    Map<String, String> pathParameters,
    Map<String, dynamic> queryParameters,
    Object? extra,
  });

  void go(String location, {Object? extra});

  void pop<T>([T? result]);

  bool canPop();

  /// Current location, for logging and for deciding whether a redirect is
  /// already where it wants to be.
  String get currentLocation;
}

/// [AppNavigator] over go_router.
final class GoRouterNavigator implements AppNavigator {
  const GoRouterNavigator(this._router);

  final GoRouter _router;

  @override
  void goNamed(
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? extra,
  }) => _router.goNamed(name, pathParameters: pathParameters, queryParameters: queryParameters, extra: extra);

  @override
  Future<T?> pushNamed<T>(
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? extra,
  }) => _router.pushNamed<T>(name, pathParameters: pathParameters, queryParameters: queryParameters, extra: extra);

  @override
  void go(String location, {Object? extra}) => _router.go(location, extra: extra);

  @override
  void pop<T>([T? result]) {
    // `pop` on an empty stack throws. Callers that fire on an async result
    // (a dialog dismissed while a request was in flight) would crash.
    if (_router.canPop()) _router.pop<T>(result);
  }

  @override
  bool canPop() => _router.canPop();

  @override
  String get currentLocation => _router.state.matchedLocation;
}

extension RouteSpecNavigationX on RouteSpec {
  void go(BuildContext context, {Map<String, String> pathParameters = const {}, Object? extra}) =>
      GoRouter.of(context).goNamed(name, pathParameters: pathParameters, extra: extra);

  Future<T?> push<T>(BuildContext context, {Map<String, String> pathParameters = const {}, Object? extra}) =>
      GoRouter.of(context).pushNamed<T>(name, pathParameters: pathParameters, extra: extra);
}
