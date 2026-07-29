import 'dart:async';

import 'package:core_arch/core_arch.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Everything a widget renders from the session.
///
/// The user belongs in the state, not behind a getter on the cubit. This used
/// to be a bare [SessionStatus], and `HomeScreen` rebuilt on status while
/// reading `cubit.user` out of band — so a profile change that left the status
/// at `authenticated` never reached the screen. A field the view displays but
/// the state does not carry is a stale-UI bug waiting for the right timing.
@immutable
final class SessionState extends Equatable {
  const SessionState({required this.status, this.user});

  const SessionState.unknown() : this(status: SessionStatus.unknown);

  final SessionStatus status;
  final AuthUser? user;

  bool get isAuthenticated => status == SessionStatus.authenticated;

  @override
  List<Object?> get props => [status, user];
}

/// Bridges [SessionStore] to the widget tree and to the router.
///
/// `GoRouter` takes a `refreshListenable` and re-evaluates its redirects when
/// it fires; without one, signing out leaves the user sitting on a protected
/// screen until they happen to navigate. That adapter is
/// [SessionRefreshListenable] below, deliberately a separate object — this
/// class is a cubit and nothing else.
@lazySingleton
final class SessionCubit extends BaseCubit<SessionState> {
  SessionCubit(this._sessionStore, this._signOut, {super.logger}) : super(_read(_sessionStore)) {
    listenTo(_sessionStore.changes, (_) => safeEmit(_read(_sessionStore)));
  }

  final SessionStore _sessionStore;
  final SignOutUseCase _signOut;

  /// Snapshots the store into a value. Every emit goes through this, so status
  /// and user can never disagree about which session they describe.
  static SessionState _read(SessionStore store) => SessionState(status: store.status, user: store.current?.user);

  AuthUser? get user => state.user;

  bool get isAuthenticated => state.isAuthenticated;

  /// Called once during bootstrap, before the first frame, so the router's
  /// first redirect already knows whether there is a session — otherwise the
  /// app flashes the login screen for a signed-in user.
  Future<void> restore() async {
    await _sessionStore.restore();
    safeEmit(_read(_sessionStore));
  }

  Future<void> signOut() async {
    await _signOut(const NoParams());
    safeEmit(_read(_sessionStore));
  }
}

/// Adapts the cubit's stream to the `Listenable` go_router wants.
///
/// Kept separate so the cubit does not have to be a `ChangeNotifier` as well —
/// mixing the two notification models in one class is how "the router did not
/// refresh" bugs start.
final class SessionRefreshListenable extends ChangeNotifier {
  SessionRefreshListenable(this._cubit) {
    _subscription = _cubit.stream.listen((_) => notifyListeners());
  }

  final SessionCubit _cubit;
  late final StreamSubscription<SessionState> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
