import 'dart:async';

import 'package:core_kit/core_kit.dart';
import 'package:core_network/core_network.dart';
import 'package:feature_auth/src/data/data_sources/token_refresh_api.dart';
import 'package:feature_auth/src/domain/session/session_store.dart';
import 'package:injectable/injectable.dart';

/// Adapter that lets `core_network` use the session without either side
/// depending on the other.
///
/// Kept separate from `SessionStoreImpl` on purpose. [SessionStore] is a domain
/// interface — "who is signed in" — and should not have `RequestOptions` in its
/// signature. [AuthSessionDelegate] is a transport port. One class implementing
/// both would drag Dio types into the domain and make the store impossible to
/// use in a non-HTTP context.
@LazySingleton(as: AuthSessionDelegate)
final class SessionAuthDelegate implements AuthSessionDelegate {
  const SessionAuthDelegate(this._sessionStore, this._refreshApi, {AppLogger logger = const NoopLogger()})
    : _logger = logger;

  /// Paths that go out unauthenticated and must never trigger a refresh.
  ///
  /// Getting this list wrong is the classic auth bug: omit `/auth/login` and a
  /// wrong password 401s, triggers a refresh, fails, and retries forever.
  static const Set<String> publicPathPrefixes = {'/auth/login', '/auth/refresh', '/auth/register', '/public/'};

  final SessionStore _sessionStore;
  final TokenRefreshApi _refreshApi;
  final AppLogger _logger;

  @override
  Future<String?> accessToken() async => (await _sessionStore.read()).valueOrNull?.accessToken;

  @override
  Future<bool> refreshSession() async {
    final session = (await _sessionStore.read()).valueOrNull;
    if (session == null) return false;

    final refreshed = await _refreshApi.refresh(session.refreshToken);
    return refreshed.fold(
      (next) {
        unawaited(_sessionStore.save(next));
        return true;
      },
      (failure) {
        _logger.warning('token refresh failed: ${failure.runtimeType}', tag: 'auth');
        return false;
      },
    );
  }

  @override
  Future<void> onSessionExpired() async {
    await _sessionStore.clear();
  }

  @override
  bool isPublicEndpoint(RequestOptions options) => publicPathPrefixes.any((prefix) => options.path.startsWith(prefix));
}
