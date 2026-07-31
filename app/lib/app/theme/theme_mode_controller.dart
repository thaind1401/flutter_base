import 'dart:async';

import 'package:core_kit/core_kit.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

/// The app's theme preference, persisted.
///
/// This lives in `app` rather than in `core_ui` for an architectural reason
/// rather than a filing one: the preference has to be *stored*, and `core_ui`
/// may only depend on `core_kit` and `core_arch` (see `allowedDependencies` in
/// `tools/check_dependencies.dart`). A `ThemeMode` notifier inside `core_ui`
/// would either have to reach for `core_storage` — failing `make check-deps` —
/// or take an injected store interface it has no other use for. The composition
/// root is the one place that can see both the theme and the store, so the
/// wiring belongs here. `core_ui` keeps owning what a `ThemeMode` *means*
/// (`AppTheme.light()` / `AppTheme.dark()`); this owns which one is selected.
///
/// It was a bare `ValueNotifier(ThemeMode.system)` in `App`, so the choice
/// survived exactly until the process died.
@lazySingleton
final class ThemeModeController extends ValueNotifier<ThemeMode> {
  ThemeModeController(this._store, {AppLogger logger = const NoopLogger()}) : _logger = logger, super(ThemeMode.system);

  /// Namespaced, because [PreferenceStore] is shared by the whole app and an
  /// unprefixed `theme_mode` is the kind of key two packages collide on.
  static const String storageKey = 'ui.theme_mode';

  final PreferenceStore _store;
  final AppLogger _logger;

  /// Reads the stored choice. Called during bootstrap, **before the first
  /// frame**: restoring after the first frame means a user who picked dark
  /// watches the app flash light on every cold start.
  ///
  /// Never throws and never fails the boot. A preference is not worth blocking
  /// startup for — an unreadable value falls back to [ThemeMode.system], which
  /// is also what a first run gets.
  Future<void> restore() async {
    final stored = await _store.readString(storageKey);

    switch (stored) {
      case Ok(value: final name?):
        final mode = _parse(name);
        if (mode == null) {
          // A value written by a build that named the modes differently. Drop
          // it rather than carrying an unreadable key forever.
          _logger.warning('unrecognised stored theme mode "$name", falling back to system', tag: 'theme');
          unawaited(_store.remove(storageKey));
          return;
        }
        value = mode;
      case Ok():
        // Absent: first run. `ThemeMode.system` is already the initial value,
        // so there is deliberately nothing to do and nothing to log.
        break;
      case Err(:final failure):
        _logger.warning('could not read the stored theme mode', tag: 'theme', error: failure);
    }
  }

  /// Applies [mode] immediately, then persists it.
  ///
  /// The notifier is updated first on purpose: the toggle must feel instant,
  /// and a preference write that loses a race with a kill is a far smaller
  /// problem than a segmented button that lags behind the thumb. A failed write
  /// is logged, not surfaced — there is no useful action a user could take.
  Future<void> select(ThemeMode mode) async {
    if (mode == value) return;
    value = mode;

    final written = await _store.writeString(storageKey, mode.name);
    if (written case Err(:final failure)) {
      _logger.warning('could not persist the theme mode', tag: 'theme', error: failure);
    }
  }

  /// `ThemeMode.values.byName` throws on an unknown name, and the whole point
  /// here is to survive one written by a build that spelled them differently.
  static ThemeMode? _parse(String name) {
    for (final mode in ThemeMode.values) {
      if (mode.name == name) return mode;
    }
    return null;
  }
}
