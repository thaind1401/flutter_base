import 'package:app/app/session/session_cubit.dart';
import 'package:core_arch/core_arch.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/widgets.dart';

/// Sends signed-out users to login and signed-in users away from it.
///
/// A guard object, not a `redirect` closure inside the router: it is one rule
/// that can be unit-tested, and a second policy (terms accepted, onboarding
/// done, force update) is added as another object rather than as another `if`
/// in a closure nobody dares to touch.
///
/// The decision lives in [resolve], which takes plain values. [redirect] only
/// unpacks go_router's types. That split is what makes the rule testable
/// without a widget tree, a router or a container — writing the test against
/// `redirect` would mean fabricating a `GoRouterState`, which is enough
/// friction that the test usually does not get written.
final class SessionGuard implements RouteGuard {
  const SessionGuard(
    this._session, {
    required this.loginLocation,
    required this.homeLocation,
    required this.splashLocation,
    this.publicRoutes = const {},
  });

  final SessionCubit _session;
  final String loginLocation;
  final String homeLocation;

  /// The holding screen shown while the session is still `unknown`.
  final String splashLocation;

  /// Reachable without a session — legal pages, password reset.
  final Set<String> publicRoutes;

  @override
  String? redirect(BuildContext context, GoRouterState state) =>
      resolve(location: state.matchedLocation, status: _session.state.status);

  @visibleForTesting
  String? resolve({required String location, required SessionStatus status}) {
    // Startup has not resolved the session yet. Redirecting now would race the
    // restore and land a signed-in user on login for a frame.
    if (status == SessionStatus.unknown) return null;

    final isAuthenticated = status == SessionStatus.authenticated;

    // Once resolved, splash has no reason to stay on screen.
    if (location == splashLocation) return isAuthenticated ? homeLocation : loginLocation;

    final isPublic = publicRoutes.contains(location) || location == loginLocation;

    if (!isAuthenticated && !isPublic) return loginLocation;
    if (isAuthenticated && location == loginLocation) return homeLocation;
    return null;
  }
}
