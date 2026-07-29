import 'dart:async';

import 'package:core_kit/core_kit.dart';
import 'package:feature_auth/src/domain/entities/auth_session.dart';

/// Who is signed in, as far as the app is concerned.
enum SessionStatus {
  /// Startup has not decided yet — the splash stays up.
  unknown,
  authenticated,
  unauthenticated,
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

  /// Broadcast so both the router's `refreshListenable` and any feature that
  /// cares (analytics identity, push registration) can listen.
  Stream<SessionStatus> get changes;

  /// Loads a persisted session at startup. Safe to call more than once.
  Future<Result<AuthSession?>> restore();

  Future<Result<AuthSession?>> read();

  Future<Result<Unit>> save(AuthSession session);

  Future<Result<Unit>> clear();

  /// Closes [changes]. Declared on the interface because the DI container calls
  /// it through this type when the container is reset.
  Future<void> dispose();
}
