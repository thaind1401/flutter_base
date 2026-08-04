import 'package:app/app/app.dart';
import 'package:app/app/bootstrap.dart';
import 'package:app/app/di/injection.dart';
import 'package:app/app/l10n/app_localizations.dart';
import 'package:app/app/l10n/generated/app_l10n.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/boot_harness.dart';

// Localization is split per package (ADR-0011), and the way that breaks is not
// a wrong string — it is a crash.
//
// `Localizations.of<T>` resolves **by type**. A delegate that is absent, or
// present but answering `isSupported: false` for the active locale, means the
// type is simply not in the tree and the generated `of(context)` throws. There
// is no fallback to English. So the failure is: one package, one language, one
// screen, dead — while `analyze`, `test` and `golden` are all green.
//
// `make check-l10n` catches this statically from the ARB files and the Makefile.
// This suite is the other half: it proves the invariant holds in a real widget
// tree built by the real bootstrap, because the static check can only see what
// the files say, not what `MaterialApp` actually installed.
//
// Goldens cannot cover any of this. `flutter test` ships no font, so text there
// renders as boxes — a golden of a Vietnamese screen is identical to a golden of
// an English one.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(installPlatformMocks);

  tearDown(getIt.reset);

  group('delegate coverage', () {
    test('every delegate supports every locale the app declares', () {
      // The whole invariant in four lines. A package that ships one fewer .arb
      // than the app declares locales fails here, naming both.
      for (final locale in AppLocalizationsSetup.supportedLocales) {
        for (final delegate in AppLocalizationsSetup.delegates) {
          expect(
            delegate.isSupported(locale),
            isTrue,
            reason:
                '${delegate.runtimeType} does not support $locale, so its type is absent from the '
                'tree and of(context) throws for every user in that language',
          );
        }
      }
    });

    test('the app declares the locales its own ARB defines', () {
      // Guards against `supportedLocales` being wired back to a core package.
      // Which languages ship is a decision about the app; when core_ui held it,
      // a design-system commit could add a locale no feature had translated —
      // and an untranslated locale here is a crash, not English text.
      expect(AppLocalizationsSetup.supportedLocales, AppL10n.supportedLocales);
      expect(AppLocalizationsSetup.supportedLocales, contains(const Locale('vi')));
    });
  });

  group('a real tree under a non-default locale', () {
    testWidgets('resolves the feature package own copy', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('vi')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      final bootstrap = await Bootstrap.run();
      await tester.pumpWidget(App(bootstrap: bootstrap));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // From feature_auth's own auth_vi.arb — not core_ui's, not the host's.
      expect(find.text('Chào mừng trở lại'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
    });

    testWidgets('resolves the host own copy in the shell chrome', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('vi')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      keychain['auth.session'] = storedSession();

      final bootstrap = await Bootstrap.run();
      await tester.pumpWidget(App(bootstrap: bootstrap));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The tab labels come from AppL10n, and they are built from a `const` list
      // whose labels are functions rather than strings — the shape that lets a
      // const tab list carry translated copy at all.
      expect(find.text('Trang chủ'), findsWidgets);
      expect(find.text('Cài đặt'), findsOneWidget);
    });

    testWidgets('resolves the design system shared copy from a feature screen', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('vi')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      final bootstrap = await Bootstrap.run();
      await tester.pumpWidget(App(bootstrap: bootstrap));
      await tester.pumpAndSettle();

      // Borrowing downward: a context inside the login screen — a feature
      // package — resolving core_ui's copy. This is the direction that is
      // allowed, and the one `make check-deps` already arbitrates because
      // reading CoreL10n requires importing package:core_ui.
      final context = tester.element(find.byType(LoadingOverlayHost));
      expect(CoreL10n.of(context).commonCancel, 'Huỷ');
      expect(AuthL10n.of(context).loginSubmit, 'Đăng nhập');
      expect(AppL10n.of(context).tabSettings, 'Cài đặt');
    });
  });

  testWidgets('falls back to the template language for an unsupported locale', (tester) async {
    // A locale nobody ships. `MaterialApp` resolves it against supportedLocales
    // and settles on the first entry rather than leaving the delegates unloaded,
    // so this must render rather than throw.
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final bootstrap = await Bootstrap.run();
    await tester.pumpWidget(App(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
