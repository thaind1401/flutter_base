import 'dart:async';

import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
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
  /// Three use cases and no `SessionStore`, which is rule 3: a bloc depends on
  /// use cases only, never on storage. This class used to take the store and
  /// re-read `status` and `current` from it on every notification — the reason
  /// it could is that `changes` carried only a status, so the event was not
  /// enough on its own. Now it carries a whole `SessionSnapshot` and the
  /// re-read is gone with the dependency.
  SessionCubit(this._watchSession, this._startSession, this._signOut, {super.logger})
    : super(const SessionState.unknown()) {
    listenTo(_watchSession(const NoParams()), (result) {
      // The stream only ever carries Ok — the store publishes state it already
      // holds, so there is nothing left to fail. Handled rather than assumed so
      // a future store that can fail mid-stream does not silently do nothing.
      if (result case Ok(:final value)) {
        safeEmit(SessionState(status: value.status, user: value.user));
      }
    });
  }

  final WatchSessionUseCase _watchSession;
  final StartSessionUseCase _startSession;
  final SignOutUseCase _signOut;

  AuthUser? get user => state.user;

  bool get isAuthenticated => state.isAuthenticated;

  /// Called once during bootstrap, before the first frame, so the router's
  /// first redirect already knows whether there is a session — otherwise the
  /// app flashes the login screen for a signed-in user.
  ///
  /// No `safeEmit` afterwards: restoring publishes on `changes`, and the
  /// listener above turns that into state. Emitting here as well would be a
  /// second source of truth for the same transition.
  Future<void> restore() => _startSession(const NoParams());

  Future<void> signOut() => _signOut(const NoParams());
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
