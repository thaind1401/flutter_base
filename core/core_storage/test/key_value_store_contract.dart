import 'package:core_kit/core_kit.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// The behaviour every [KeyValueStore] owes its callers, run against all three
/// implementations.
///
/// A per-implementation test suite would let the fake drift from the real
/// thing, and that drift is invisible in exactly the worst way: a repository
/// test passes against [InMemoryStore] and the same code fails on device
/// against [SecureStore]. Writing the promises once and running them three
/// times is what makes "InMemoryStore is a faithful fake" a checked property
/// instead of a comment.
///
/// Anything asserted here is part of the interface. If an implementation cannot
/// satisfy it, that is a bug in the implementation — not a reason to soften the
/// contract.
void runKeyValueStoreContract(String name, KeyValueStore Function() create) {
  group('$name — KeyValueStore contract', () {
    late KeyValueStore store;

    setUp(() => store = create());

    test('reading an absent key yields null, not a failure', () async {
      expect((await store.readString('nope')).valueOrNull, isNull);
      expect((await store.readBool('nope')).valueOrNull, isNull);
      expect((await store.readInt('nope')).valueOrNull, isNull);
      expect((await store.readJson('nope')).valueOrNull, isNull);
      // A missing key is a normal state, not an error. Callers branch on the
      // value; if this returned Err they would have to branch on both.
      expect((await store.readString('nope')).isOk, isTrue);
    });

    test('strings round trip', () async {
      expect((await store.writeString('k', 'value')).isOk, isTrue);
      expect((await store.readString('k')).valueOrNull, 'value');
    });

    test('an empty string is a stored value, not an absent one', () async {
      await store.writeString('k', '');
      expect((await store.readString('k')).valueOrNull, '');
      expect((await store.containsKey('k')).valueOrNull, isTrue);
    });

    test('booleans round trip in both states', () async {
      await store.writeBool('t', value: true);
      await store.writeBool('f', value: false);
      expect((await store.readBool('t')).valueOrNull, isTrue);
      // The false case is the one that breaks when an implementation conflates
      // "stored false" with "absent".
      expect((await store.readBool('f')).valueOrNull, isFalse);
    });

    test('integers round trip, including zero and negatives', () async {
      await store.writeInt('zero', 0);
      await store.writeInt('neg', -42);
      expect((await store.readInt('zero')).valueOrNull, 0);
      expect((await store.readInt('neg')).valueOrNull, -42);
    });

    test('json round trips with nested values intact', () async {
      const payload = <String, Object?>{
        'id': 'u1',
        'count': 3,
        'flag': true,
        'nested': {'a': 1},
        'list': [1, 2, 3],
        'absent': null,
      };
      expect((await store.writeJson('session', payload)).isOk, isTrue);
      expect((await store.readJson('session')).valueOrNull, payload);
    });

    test('unparseable json is reported, not swallowed as null', () async {
      // This is what a model change without a migration looks like on a device
      // that already has the old payload. Returning null would silently log the
      // user out; returning a failure lets the caller clear the key knowingly.
      await store.writeString('session', '{not valid json');
      final result = await store.readJson('session');
      expect(result.isErr, isTrue, reason: 'corrupt json must surface as a failure');
      expect(result.failureOrNull, isA<CacheFailure>());
    });

    test('blank text reads as absent json rather than a parse failure', () async {
      await store.writeString('session', '   ');
      final result = await store.readJson('session');
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('containsKey tracks writes and removals', () async {
      expect((await store.containsKey('k')).valueOrNull, isFalse);
      await store.writeString('k', 'v');
      expect((await store.containsKey('k')).valueOrNull, isTrue);
      await store.remove('k');
      expect((await store.containsKey('k')).valueOrNull, isFalse);
      expect((await store.readString('k')).valueOrNull, isNull);
    });

    test('removing a key that was never written is not an error', () async {
      expect((await store.remove('never-there')).isOk, isTrue);
    });

    test('clear wipes everything the store owns', () async {
      await store.writeString('a', '1');
      await store.writeInt('b', 2);
      await store.writeJson('c', const {'d': 4});

      expect((await store.clear()).isOk, isTrue);

      // Logout depends on this. A key surviving here is a session leaking into
      // the next user of the device.
      expect((await store.containsKey('a')).valueOrNull, isFalse);
      expect((await store.containsKey('b')).valueOrNull, isFalse);
      expect((await store.containsKey('c')).valueOrNull, isFalse);
    });

    test('a later write replaces the earlier value', () async {
      await store.writeString('k', 'first');
      await store.writeString('k', 'second');
      expect((await store.readString('k')).valueOrNull, 'second');
    });
  });
}
