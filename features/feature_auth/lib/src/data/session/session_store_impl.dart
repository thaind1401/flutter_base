import 'dart:async';

import 'package:core_kit/core_kit.dart';
import 'package:core_storage/core_storage.dart';
import 'package:feature_auth/src/domain/entities/auth_session.dart';
import 'package:feature_auth/src/domain/session/session_store.dart';
import 'package:injectable/injectable.dart';

/// The session, held in memory and persisted to the platform keychain.
///
/// The transport-facing half lives in `SessionAuthDelegate`; this class knows
/// nothing about HTTP.
@LazySingleton(as: SessionStore)
final class SessionStoreImpl implements SessionStore {
  SessionStoreImpl(this._secureStore, {AppLogger logger = const NoopLogger()}) : _logger = logger;

  static const String _sessionKey = 'auth.session';

  final SecureStore _secureStore;
  final AppLogger _logger;

  final StreamController<SessionSnapshot> _changes = StreamController<SessionSnapshot>.broadcast();

  AuthSession? _current;
  SessionStatus _status = SessionStatus.unknown;

  @override
  SessionStatus get status => _status;

  @override
  AuthSession? get current => _current;

  @override
  Stream<SessionSnapshot> get changes => _changes.stream;

  SessionSnapshot _snapshot = const SessionSnapshot.unknown();

  @override
  SessionSnapshot get snapshot => _snapshot;

  @override
  Future<Result<AuthSession?>> restore() async {
    final result = await read();
    _publish(result.valueOrNull == null ? SessionStatus.unauthenticated : SessionStatus.authenticated);
    return result;
  }

  @override
  Future<Result<AuthSession?>> read() async {
    if (_current != null) return Ok(_current);

    final stored = await _secureStore.readJson(_sessionKey);
    return stored.flatMapAsync((json) async {
      final session = AuthSession.fromStorageJson(json);
      if (json != null && session == null) {
        // Stored under an older schema. Dropping it beats failing to parse it
        // on every launch forever.
        _logger.warning('discarding unreadable stored session', tag: 'auth');
        await _secureStore.remove(_sessionKey);
      }
      _current = session;
      return Ok<AuthSession?>(session);
    });
  }

  @override
  Future<Result<Unit>> save(AuthSession session) async {
    _current = session;
    _publish(SessionStatus.authenticated);
    return _secureStore.writeJson(_sessionKey, session.toStorageJson());
  }

  @override
  Future<Result<Unit>> clear() async {
    _current = null;
    _publish(SessionStatus.unauthenticated);
    return _secureStore.remove(_sessionKey);
  }

  /// Deduplicates on the whole snapshot, not on the status.
  ///
  /// Comparing statuses alone silently dropped a profile update: `save()` with a
  /// different user at an unchanged `authenticated` status returned here without
  /// publishing, so no listener ever learned the user had changed. Saving the
  /// *same* session twice still publishes once, which is what the original
  /// deduplication was for.
  void _publish(SessionStatus next) {
    final snapshot = SessionSnapshot(status: next, session: _current);
    if (_snapshot == snapshot) return;
    _snapshot = snapshot;
    _status = next;
    if (!_changes.isClosed) _changes.add(snapshot);
  }

  @override
  @disposeMethod
  Future<void> dispose() => _changes.close();
}
