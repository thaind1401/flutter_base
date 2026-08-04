import 'package:app/app/l10n/app_localizations.dart';
import 'package:app/app/session/session_cubit.dart';
import 'package:app/app/shell/settings_screen.dart';
import 'package:app/app/theme/theme_mode_controller.dart';
import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/null_session.dart';

// The screen was at 1 of 40 lines covered — effectively untested — while owning
// two things that are quiet when they break: the destructive sign-out path, and
// a banner that must never render in production because it prints the backend
// URL on screen.

const _config = AppEnvironmentConfig(environment: AppEnvironment.stg, baseUrl: 'https://stg.example.com');

const _prodConfig = AppEnvironmentConfig(environment: AppEnvironment.prod, baseUrl: 'https://api.example.com');

/// Counts sign-outs, because the state cannot report them here.
///
/// The first version of this file asserted `session.state.status` was not
/// `unauthenticated` after cancelling. That passes whether or not the cancel
/// worked: `NullSessionStore.changes` is an empty stream, so the cubit's state
/// stays `unknown` no matter what happens to the store. Counting the call is
/// the only thing that distinguishes "the dialog stopped it" from "the dialog
/// was decorative".
final class _CountingAuthRepository implements AuthRepository {
  int signOutCalls = 0;

  @override
  Future<Result<Unit>> signOut() async {
    signOutCalls++;
    return const Ok(unit);
  }

  @override
  Future<Result<AuthSession>> signIn({required String email, required String password}) async =>
      const Err(UnexpectedFailure(debugMessage: 'not used in this test'));

  @override
  Future<Result<AuthUser>> currentUser() async => const Err(UnexpectedFailure());
}

Future<void> _pump(
  WidgetTester tester, {
  required ThemeModeController themeMode,
  required SessionCubit session,
  AppEnvironmentConfig config = _config,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizationsSetup.delegates,
      supportedLocales: AppLocalizationsSetup.supportedLocales,
      home: BlocProvider<SessionCubit>.value(
        value: session,
        child: RepositoryProvider<AppEnvironmentConfig>.value(
          value: config,
          child: SettingsScreen(themeMode: themeMode),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late ThemeModeController themeMode;
  late SessionCubit session;
  late _CountingAuthRepository authRepository;

  setUp(() {
    themeMode = ThemeModeController(InMemoryStore());
    authRepository = _CountingAuthRepository();
    session = SessionCubit(
      nullWatchSessionUseCase(),
      nullStartSessionUseCase(),
      // The real use case over a counting repository, matching how the other
      // fakes in this suite exercise production classes rather than replace them.
      SignOutUseCase(authRepository, NullSessionStore()),
    );
  });

  tearDown(() async {
    await session.close();
    themeMode.dispose();
  });

  group('theme selection', () {
    testWidgets('picking a mode applies it and persists it', (tester) async {
      final store = InMemoryStore();
      final controller = ThemeModeController(store);
      addTearDown(controller.dispose);

      await _pump(tester, themeMode: controller, session: session);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(controller.value, ThemeMode.dark);
      // The write is fire-and-forget from the UI's point of view, so the value
      // reaching the store is the only thing that proves the choice survives a
      // cold start rather than living in a notifier until the process dies.
      expect(await store.readString(ThemeModeController.storageKey), const Ok<String?>('dark'));
    });

    testWidgets('shows the stored mode as selected, not always system', (tester) async {
      final controller = ThemeModeController(InMemoryStore())..value = ThemeMode.light;
      addTearDown(controller.dispose);

      await _pump(tester, themeMode: controller, session: session);

      final button = tester.widget<SegmentedButton<ThemeMode>>(find.byType(SegmentedButton<ThemeMode>));
      expect(button.selected, {ThemeMode.light});
    });
  });

  group('sign out', () {
    testWidgets('asks first, and cancelling does not sign out', (tester) async {
      await _pump(tester, themeMode: themeMode, session: session);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // The whole point of the confirmation. A sign-out that happens anyway is
      // invisible in review — the dialog is still there, it just does not
      // decide anything.
      expect(authRepository.signOutCalls, 0);
    });

    testWidgets('dismissing by tapping outside does not sign out either', (tester) async {
      await _pump(tester, themeMode: themeMode, session: session);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      // `confirm` resolves false on a barrier tap rather than null, which is
      // what keeps a destructive action from running on a dismissal.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsNothing);
      expect(authRepository.signOutCalls, 0);
    });

    testWidgets('confirming runs the sign out', (tester) async {
      await _pump(tester, themeMode: themeMode, session: session);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      // The confirm button carries the same label as the trigger, so it is
      // located inside the dialog rather than by text alone.
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Sign out')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      // The positive case, which is what makes the two negative cases above
      // mean something: the path does work when confirmed.
      expect(authRepository.signOutCalls, 1);
    });
  });

  group('environment banner', () {
    testWidgets('names the flavor and the base URL outside production', (tester) async {
      await _pump(tester, themeMode: themeMode, session: session);

      expect(find.text('Environment: stg'), findsOneWidget);
      expect(find.text('https://stg.example.com'), findsOneWidget);
    });

    testWidgets('renders nothing at all in production', (tester) async {
      // Not cosmetic: the banner prints the backend URL on screen. Shipping it
      // to real users leaks infrastructure and looks like a debug build.
      await _pump(tester, themeMode: themeMode, session: session, config: _prodConfig);

      expect(find.textContaining('Environment:'), findsNothing);
      expect(find.text('https://api.example.com'), findsNothing);
    });
  });
}
