import 'package:core_kit/core_kit.dart';
import 'package:core_storage/core_storage.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/src/data/session/session_store_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryStore storage;
  late SessionStoreImpl store;

  /// A fixed expiry, not `DateTime.now()`: the store now deduplicates on the
  /// whole session, so a clock-derived field would make two "identical" saves
  /// differ by microseconds and the deduplication test would pass for the wrong
  /// reason. Far enough ahead that nothing here reads as expired.
  AuthSession session({String displayName = 'Tester'}) => AuthSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresAt: DateTime.utc(2099),
    user: AuthUser(id: 'u1', email: 'a@b.com', displayName: displayName),
  );

  setUp(() {
    // InMemoryStore satisfies SecureStore, so no keychain channel is involved.
    storage = InMemoryStore();
    store = SessionStoreImpl(storage);
  });

  tearDown(() => store.dispose());

  test('starts unknown so the router does not redirect before restore', () {
    expect(store.status, SessionStatus.unknown);
    expect(store.current, isNull);
  });

  test('restore on a fresh install reports unauthenticated, not an error', () async {
    final result = await store.restore();
    expect(result, const Ok<AuthSession?>(null));
    expect(store.status, SessionStatus.unauthenticated);
  });

  test('save persists and publishes authenticated', () async {
    final published = <SessionSnapshot>[];
    final subscription = store.changes.listen(published.add);

    await store.save(session());
    await Future<void>.delayed(Duration.zero);

    expect(store.status, SessionStatus.authenticated);
    expect(store.current?.user.id, 'u1');
    expect(published.map((s) => s.status), [SessionStatus.authenticated]);
    await subscription.cancel();
  });

  test('a saved session survives a new store over the same storage', () async {
    await store.save(session());

    final reopened = SessionStoreImpl(storage);
    final restored = await reopened.restore();

    expect(restored.valueOrNull?.accessToken, 'access');
    expect(reopened.status, SessionStatus.authenticated);
    await reopened.dispose();
  });

  test('clear wipes memory, storage and status', () async {
    await store.save(session());
    await store.clear();

    expect(store.current, isNull);
    expect(store.status, SessionStatus.unauthenticated);
    expect((await SessionStoreImpl(storage).read()).valueOrNull, isNull);
  });

  test('discards a payload from an older schema instead of failing every launch', () async {
    await storage.writeJson('auth.session', {'accessToken': 'orphan'});

    final result = await store.restore();

    expect(result.valueOrNull, isNull);
    expect(store.status, SessionStatus.unauthenticated);
    // And the bad payload is gone, so the next launch does not repeat the work.
    expect((await storage.readJson('auth.session')).valueOrNull, isNull);
  });

  test('propagates a storage failure rather than pretending there is no session', () async {
    // A locked keystore is not the same as "no session"; the caller decides.
    storage.failWith = const CacheFailure(debugMessage: 'keystore locked');
    final result = await store.read();
    expect(result.failureOrNull, isA<CacheFailure>());
  });

  test('does not republish an identical session', () async {
    final published = <SessionSnapshot>[];
    final subscription = store.changes.listen(published.add);

    await store.save(session());
    await store.save(session());
    await Future<void>.delayed(Duration.zero);

    expect(published, hasLength(1));
    await subscription.cancel();
  });

  test('publishes a profile change that leaves the status alone', () async {
    // The bug this exists for: deduplication used to compare statuses, so
    // saving a different user while already `authenticated` published nothing
    // and no listener ever learned the profile had changed. `SessionState`'s
    // doc comment in the host describes the symptom — a name that never
    // updates — and fixes the widget half; this is the half underneath.
    final published = <SessionSnapshot>[];
    final subscription = store.changes.listen(published.add);

    await store.save(session());
    await store.save(session(displayName: 'Renamed'));
    await Future<void>.delayed(Duration.zero);

    expect(published, hasLength(2), reason: 'a new profile at a steady status must publish');
    expect(published.map((s) => s.status), [SessionStatus.authenticated, SessionStatus.authenticated]);
    expect(published.last.user?.displayName, 'Renamed');
    await subscription.cancel();
  });
}
