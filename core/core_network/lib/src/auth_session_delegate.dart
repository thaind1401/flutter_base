import 'package:dio/dio.dart';

/// What the transport needs from whoever owns the session.
///
/// This is the dependency inversion that keeps the layering honest: the network
/// package must attach a token and react to a 401, but it must not know what a
/// user is, where tokens are stored, or how a refresh call is shaped. The auth
/// feature implements this interface, and `core_network` never depends on it.
///
/// Without the inversion the only options are a network package that imports
/// the auth feature (a cycle), or a service locator lookup at request time
/// (untestable). This is neither.
abstract interface class AuthSessionDelegate {
  /// The bearer token to attach, or null when the user is not signed in.
  Future<String?> accessToken();

  /// Attempts to exchange the refresh token for a new access token.
  ///
  /// Returns true when a subsequent retry should succeed. Implementations must
  /// **not** call any endpoint through the authenticated client, or a failing
  /// refresh recurses until the stack overflows — use a bare Dio instance.
  Future<bool> refreshSession();

  /// The refresh failed or there was nothing to refresh. The implementation
  /// clears local state; the host app listens and routes back to login.
  Future<void> onSessionExpired();

  /// Requests that must go out without a token and must never trigger a
  /// refresh — login, refresh itself, public config. Returning false for these
  /// causes an infinite refresh loop on a bad password.
  bool isPublicEndpoint(RequestOptions options);
}

/// Default for apps (and tests) with no authentication wired up yet.
final class NoAuthSessionDelegate implements AuthSessionDelegate {
  const NoAuthSessionDelegate();

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<bool> refreshSession() async => false;

  @override
  Future<void> onSessionExpired() async {}

  @override
  bool isPublicEndpoint(RequestOptions options) => true;
}

/// Extra headers every request carries: device id, app version, locale.
///
/// Inverted for the same reason as [AuthSessionDelegate] — collecting them
/// needs platform plugins that have no business being a dependency of the
/// transport layer.
abstract interface class RequestContextProvider {
  /// Called per request. Implementations must cache; this is on the hot path.
  Future<Map<String, String>> headers();
}

final class EmptyRequestContextProvider implements RequestContextProvider {
  const EmptyRequestContextProvider();

  @override
  Future<Map<String, String>> headers() async => const {};
}
