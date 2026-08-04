import 'package:app/app/l10n/generated/app_l10n.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// The single list of localization delegates the app installs.
///
/// Every package that ships an ARB generates its own class and its own
/// delegate, and `Localizations.of<T>` resolves **by type** — so a class whose
/// delegate is not in this list is simply absent from the tree, and
/// `AuthL10n.of(context)` throws the first time one of that package's screens
/// opens. Nothing about that failure is visible at compile time: the import
/// resolves, the analyzer is happy, and the gate stays green.
///
/// That is the same shape as the missing DI micro-package module that once
/// white-screened this app, so it gets the same two defences: the list lives in
/// exactly one place rather than being spelled out inside `MaterialApp`, and
/// `make check-l10n` fails if a package in `L10N_PACKAGES` has no delegate here.
///
/// Mini-app delegates are *not* here, because the host does not know which
/// mini-apps are installed at compile time — they arrive through
/// [MiniAppRegistry.localizationsDelegates] and are appended by `App`. ADR-0011.
abstract final class AppLocalizationsSetup {
  /// Order is not significant to resolution — each delegate answers for its own
  /// type — so these are grouped app, core, feature, framework for reading.
  static const List<LocalizationsDelegate<Object?>> delegates = [
    AppL10n.delegate,
    CoreL10n.delegate,
    AuthL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Declared by the host, not by `core_ui`.
  ///
  /// Which languages the app ships is a product decision about the app as a
  /// whole; taking it from a core package meant a design-system commit could
  /// silently add a locale that no feature had translated — and a feature whose
  /// delegate does not support the active locale is a crash, not a fallback.
  /// `make check-l10n` holds every l10n package to this exact set.
  static const List<Locale> supportedLocales = AppL10n.supportedLocales;
}
