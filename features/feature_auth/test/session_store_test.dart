import 'package:core_kit/core_kit.dart';
import 'package:core_storage/core_storage.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/src/data/session/session_store_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryStore storage;
  late SessionStoreImpl store;

  AuthSession session() => AuthSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    user: const AuthUser(id: 'u1', email: 'a@b.com', displayName: 'Tester'),
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
    final published = <SessionStatus>[];
    final subscription = store.changes.listen(published.add);

    await store.save(session());
    await Future<void>.delayed(Duration.zero);

    expect(store.status, SessionStatus.authenticated);
    expect(store.current?.user.id, 'u1');
    expect(published, [SessionStatus.authenticated]);
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

  test('does not publish a status it is already in', () async {
    final published = <SessionStatus>[];
    final subscription = store.changes.listen(published.add);

    await store.save(session());
    await store.save(session());
    await Future<void>.delayed(Duration.zero);

    expect(published, [SessionStatus.authenticated]);
    await subscription.cancel();
  });
}
