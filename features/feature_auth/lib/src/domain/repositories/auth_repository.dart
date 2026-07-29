import 'package:core_kit/core_kit.dart';
import 'package:feature_auth/src/domain/entities/auth_session.dart';

/// What the domain needs from the outside world to authenticate.
///
/// Declared in `domain/`, implemented in `data/`. The use cases depend on this
/// interface, so swapping REST for OAuth, or the whole backend, changes one
/// file in `data/` and nothing above it.
/// Refresh is deliberately absent. It lives on `TokenRefreshApi`, which builds
/// its own bare `Dio`: routing it through here would make the graph a cycle
/// (repository -> Dio -> ApiClient -> AuthSessionDelegate -> SessionStore ->
/// repository) and would send the refresh call through the very interceptor
/// that is asking for it. This interface previously declared `refresh` anyway,
/// and the implementation answered every call with a hardcoded `Err` — a method
/// that exists to be un-callable is worse than no method, because the compiler
/// stops warning and the reader has to find the comment.
abstract interface class AuthRepository {
  Future<Result<AuthSession>> signIn({required String email, required String password});

  /// Best-effort server-side revoke. A failure here still clears local state —
  /// the user asked to sign out and must end up signed out either way.
  Future<Result<Unit>> signOut();

  Future<Result<AuthUser>> currentUser();
}
