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

  final StreamController<SessionStatus> _changes = StreamController<SessionStatus>.broadcast();

  AuthSession? _current;
  SessionStatus _status = SessionStatus.unknown;

  @override
  SessionStatus get status => _status;

  @override
  AuthSession? get current => _current;

  @override
  Stream<SessionStatus> get changes => _changes.stream;

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

  void _publish(SessionStatus next) {
    if (_status == next) return;
    _status = next;
    if (!_changes.isClosed) _changes.add(next);
  }

  @override
  @disposeMethod
  Future<void> dispose() => _changes.close();
}
