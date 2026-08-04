import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// The one `MaterialApp` wrapper every widget test in this package uses.
///
/// Fourteen test files each declared their own `host()`, and nine of them wired
/// `CoreL10n.delegate` while five did not. That is not a tidiness problem: a
/// widget that starts reading `CoreL10n.of(context)` — which is what happened
/// when `AppButton`, `AppTextField` and `AppLoader` gained their accessibility
/// labels — throws in exactly the five hosts that forgot, and the failure
/// reports as "found 0 widgets with text 'Email'" rather than as a missing
/// delegate. The fix is one host, not five more copies of the same four lines.
///
/// [theme] is a parameter because the golden tests render the same widget in
/// both themes, and a light-only host would quietly make every dark golden a
/// screenshot of the light theme.
Widget testHost(
  Widget child, {
  ThemeData? theme,
  Locale locale = const Locale('en'),
  bool scaffold = true,
  Size? surfaceSize,
}) {
  final app = MaterialApp(
    theme: theme ?? AppTheme.light(),
    locale: locale,
    localizationsDelegates: const [
      CoreL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: CoreL10n.supportedLocales,
    debugShowCheckedModeBanner: false,
    // `scaffold: false` is for the widgets that build their own — `BaseScreen`
    // and anything wrapping `AppScaffold`. Nesting two `Scaffold`s changes
    // safe-area and keyboard-inset behaviour, which is precisely what those
    // tests are asserting.
    home: scaffold ? Scaffold(body: child) : child,
  );

  if (surfaceSize == null) return app;

  // Pins the logical size so a golden does not change meaning when the default
  // test surface does.
  return MediaQuery(
    data: MediaQueryData(size: surfaceSize),
    child: app,
  );
}
