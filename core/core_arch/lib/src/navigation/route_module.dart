import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A named path plus the helpers to reach it.
///
/// Screens expose one `static const` [RouteSpec]; nothing else in the codebase
/// writes a raw path string. That keeps a rename to a single edit and makes
/// "who navigates here?" a find-usages instead of a grep for a string literal.
@immutable
final class RouteSpec {
  const RouteSpec({required this.name, required this.path});

  /// Unique across the whole app. Navigation goes by name, so a path can change
  /// without touching call sites.
  final String name;

  /// go_router pattern — absolute for a top-level route, relative for a child.
  final String path;

  @override
  String toString() => 'RouteSpec($name -> $path)';
}

/// One feature package's contribution to the router.
///
/// This is what replaces a single `app_routers.dart` importing every screen in
/// the app. That file grew to sixty imports, made the host package depend on
/// every feature, and turned the router into a merge-conflict magnet. Now each
/// feature owns its routes and the host only composes a list.
abstract interface class RouteModule {
  /// Stable identifier, used in logs and to keep ordering deterministic.
  String get id;

  /// Routes rendered above the shell (full-screen: login, modals, viewers).
  List<RouteBase> rootRoutes({GlobalKey<NavigatorState>? rootNavigatorKey});

  /// Routes rendered inside the persistent shell (bottom-navigation branches).
  ///
  /// Most features contribute to exactly one of the two lists and return
  /// `const []` here. It is required rather than defaulted so that adding a
  /// feature forces an explicit decision about where its screens live.
  List<RouteBase> shellRoutes({GlobalKey<NavigatorState>? rootNavigatorKey});
}

/// A single, testable navigation policy.
///
/// Guards compose in order and the first non-null answer wins, so
/// "unauthenticated users go to login" and "users who have not accepted terms
/// go to consent" are separate objects with separate tests, rather than one
/// growing `redirect` closure inside the router.
abstract interface class RouteGuard {
  /// Return a location to redirect to, or null to allow.
  String? redirect(BuildContext context, GoRouterState state);
}
