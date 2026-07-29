import 'package:core_kit/core_kit.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'key_value_store_contract.dart';

void main() {
  runKeyValueStoreContract('InMemoryStore', InMemoryStore.new);

  group('InMemoryStore extras', () {
    test('a seed is readable immediately and is copied, not aliased', () async {
      final seed = <String, Object?>{'k': 'v'};
      final store = InMemoryStore(seed);

      expect((await store.readString('k')).valueOrNull, 'v');

      // Mutating the caller's map after construction must not reach into the
      // store, or a test that seeds once and mutates later gets a store that
      // changes underneath it.
      seed['k'] = 'mutated';
      expect((await store.readString('k')).valueOrNull, 'v');
    });

    test('snapshot exposes the contents and refuses writes', () async {
      final store = InMemoryStore();
      await store.writeString('k', 'v');

      expect(store.snapshot, {'k': 'v'});
      expect(() => store.snapshot['k'] = 'x', throwsUnsupportedError);
    });

    test('failWith turns every operation into that failure', () async {
      final store = InMemoryStore()..failWith = const CacheFailure(debugMessage: 'keystore locked');

      // The point of this hook: the CacheFailure branches in callers are
      // otherwise unreachable, so they go untested and rot.
      expect((await store.readString('k')).failureOrNull, isA<CacheFailure>());
      expect((await store.writeString('k', 'v')).failureOrNull, isA<CacheFailure>());
      expect((await store.readJson('k')).failureOrNull, isA<CacheFailure>());
      expect((await store.containsKey('k')).failureOrNull, isA<CacheFailure>());
      expect((await store.remove('k')).failureOrNull, isA<CacheFailure>());
      expect((await store.clear()).failureOrNull, isA<CacheFailure>());
    });

    test('clearing failWith restores normal operation', () async {
      final store = InMemoryStore()..failWith = const CacheFailure();
      expect((await store.writeString('k', 'v')).isErr, isTrue);

      store.failWith = null;
      expect((await store.writeString('k', 'v')).isOk, isTrue);
      expect((await store.readString('k')).valueOrNull, 'v');
    });

    test('a value stored as json is readable as json after a rewrite', () async {
      final store = InMemoryStore();
      await store.writeJson('k', const {'a': 1});
      await store.writeJson('k', const {'b': 2});
      expect((await store.readJson('k')).valueOrNull, const {'b': 2});
    });
  });
}
