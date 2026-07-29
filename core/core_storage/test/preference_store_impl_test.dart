import 'package:core_storage/core_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'key_value_store_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  // Declared here rather than inside the contract so the contract stays free of
  // any one backend's setup. Outer setUps run first, so `prefs` is ready by the
  // time the contract builds its store.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  runKeyValueStoreContract('PreferenceStoreImpl', () => PreferenceStoreImpl(prefs));

  group('PreferenceStoreImpl extras', () {
    test('reads values that were already on disk before the app started', () async {
      // getInstance() caches, so the mock values have to be in place before it
      // is called — which is also true of the real plugin on a cold start.
      SharedPreferences.setMockInitialValues({'flutter.existing': 'from-disk'});
      final store = PreferenceStoreImpl(await SharedPreferences.getInstance());

      expect((await store.readString('existing')).valueOrNull, 'from-disk');
    });

    test('clear does not resurrect values on the next read', () async {
      final store = PreferenceStoreImpl(prefs);
      await store.writeString('k', 'v');
      await store.clear();

      expect((await store.readString('k')).valueOrNull, isNull);
      expect(prefs.getString('k'), isNull);
    });
  });
}
