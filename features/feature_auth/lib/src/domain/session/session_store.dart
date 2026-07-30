import 'dart:async';

import 'package:core_kit/core_kit.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_auth/src/domain/entities/auth_session.dart';
import 'package:meta/meta.dart';

/// Who is signed in, as far as the app is concerned.
enum SessionStatus {
  /// Startup has not decided yet — the splash stays up.
  unknown,
  authenticated,
  unauthenticated,
}

/// What [SessionStore.changes] carries: the status **and** who it belongs to.
///
/// A bare [SessionStatus] was not enough, and the gap was a live bug. `save()`
/// with a new profile at an unchanged `authenticated` status published nothing,
/// because the store deduplicated on the status alone — so a profile update
/// never reached a listener and the UI kept the old name. `SessionState`'s doc
/// comment in the host describes that exact symptom and fixes the half of it
/// visible in the widget; this fixes the half underneath, where the
/// notification was missing in the first place.
///
/// Equatable, so deduplication compares the whole snapshot rather than one
/// field of it.
@immutable
final class SessionSnapshot extends Equatable {
  const SessionSnapshot({required this.status, this.session});

  const SessionSnapshot.unknown() : this(status: SessionStatus.unknown);

  final SessionStatus status;
  final AuthSession? session;

  AuthUser? get user => session?.user;

  bool get isAuthenticated => status == SessionStatus.authenticated;

  @override
  List<Object?> get props => [status, session];
}

/// Owns the current session: memory copy, secure persistence, and the stream
/// the router listens to.
///
/// This is the seam between the auth feature and the rest of the app. The
/// router does not import a login screen and the transport does not import the
/// auth feature — both talk to this.
abstract interface class SessionStore {
  /// Current status; `unknown` until [restore] runs.
  SessionStatus get status;

  AuthSession? get current;

  /// [status] and [current] as one value — what `changes` publishes.
  ///
  /// Exists so a listener can establish its starting point without two reads
  /// that could disagree, and so `WatchSessionUseCase` can hand a subscriber the
  /// current snapshot before the first change arrives.
  SessionSnapshot get snapshot;

  /// Broadcast so both the router's `refreshListenable` and any feature that
  /// cares (analytics identity, push registration) can listen.
  ///
  /// Carries a [SessionSnapshot] rather than a bare status, so a listener can
  /// build its own state from the event without reaching back into this store —
  /// which is what lets `SessionCubit` depend on a use case instead of on
  /// storage.
  Stream<SessionSnapshot> get changes;

  /// Loads a persisted session at startup. Safe to call more than once.
  Future<Result<AuthSession?>> restore();

  Future<Result<AuthSession?>> read();

  Future<Result<Unit>> save(AuthSession session);

  Future<Result<Unit>> clear();

  /// Closes [changes]. Declared on the interface because the DI container calls
  /// it through this type when the container is reset.
  Future<void> dispose();
}
