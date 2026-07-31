import 'package:app/app/theme/theme_mode_controller.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `InMemoryStore` implements `PreferenceStore` and carries a `failWith` switch,
/// so both the happy path and the unreachable-store path are exercised without
/// a plugin mock or a `TestWidgetsFlutterBinding`.
void main() {
  late InMemoryStore store;
  late ThemeModeController controller;

  setUp(() {
    store = InMemoryStore();
    controller = ThemeModeController(store);
  });

  tearDown(() => controller.dispose());

  group('restore', () {
    test('a first run stays on system without writing anything', () async {
      await controller.restore();

      expect(controller.value, ThemeMode.system);
      // The absent-key branch must not persist the default. Writing it would
      // turn "never chose" into "explicitly chose system", which is a different
      // thing the moment a future build changes what the default is.
      expect(store.snapshot, isEmpty);
    });

    test('a stored choice is applied', () async {
      await store.writeString(ThemeModeController.storageKey, 'dark');

      await controller.restore();

      expect(controller.value, ThemeMode.dark);
    });

    test('a value no build recognises falls back to system and is dropped', () async {
      // The shape a rename would leave behind: a key written by a build that
      // spelled the modes differently. `ThemeMode.values.byName` would throw
      // here, which is the reason `restore` does not use it.
      await store.writeString(ThemeModeController.storageKey, 'midnight');

      await controller.restore();

      expect(controller.value, ThemeMode.system);
      expect(store.snapshot, isNot(contains(ThemeModeController.storageKey)));
    });

    test('an unreadable store does not throw and does not block the boot', () async {
      store.failWith = const CacheFailure(debugMessage: 'keystore locked');

      await expectLater(controller.restore(), completes);
      expect(controller.value, ThemeMode.system);
    });
  });

  group('select', () {
    test('applies the mode and persists it', () async {
      await controller.select(ThemeMode.dark);

      expect(controller.value, ThemeMode.dark);
      expect(store.snapshot[ThemeModeController.storageKey], 'dark');
    });

    test('notifies listeners exactly once per real change', () async {
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.select(ThemeMode.dark);
      // Re-selecting the current mode is what a segmented button does when the
      // user taps the segment that is already on. It must not churn the theme
      // or write the same value again.
      await controller.select(ThemeMode.dark);

      expect(notifications, 1);
    });

    test('the mode still applies when the write fails', () async {
      store.failWith = const CacheFailure(debugMessage: 'disk full');

      await controller.select(ThemeMode.light);

      // The user's tap is honoured for this run even though nothing was stored.
      // Refusing to switch because persistence failed would be the worse trade.
      expect(controller.value, ThemeMode.light);
    });

    test('a restored controller round-trips through a second controller', () async {
      await controller.select(ThemeMode.light);

      final reopened = ThemeModeController(store);
      addTearDown(reopened.dispose);
      await reopened.restore();

      expect(reopened.value, ThemeMode.light);
    });
  });
}
