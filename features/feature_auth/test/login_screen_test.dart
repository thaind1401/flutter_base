import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/src/presentation/login/login_bloc.dart';
import 'package:feature_auth/src/presentation/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_auth.dart';

/// The reference screen, and therefore the shape every other screen is copied
/// from. Two things here are worth a test rather than a comment.
///
/// **Rebuild scope (rule 11 / ADR-0008).** Each field has its own
/// `BlocSelector`, so a keystroke in the password field must not rebuild the
/// email field. Nothing about that is visible on screen when it regresses — the
/// app just gets slower and, in a bigger form, starts dropping keystrokes. A
/// rebuild counter is the only way to see it.
///
/// **Effects, not state flags (rule 4).** Success navigates and failure toasts,
/// both delivered once. A state flag would re-fire on every rebuild.
void main() {
  late FakeAuthRepository repository;
  late FakeSessionStore store;

  setUp(() {
    repository = FakeAuthRepository();
    store = FakeSessionStore();
  });

  tearDown(() => store.dispose());

  LoginBloc bloc() => LoginBloc(SignInUseCase(repository, store));

  Widget host({VoidCallback? onAuthenticated, LoginBloc? instance}) => MaterialApp(
    theme: AppTheme.light(),
    // feature_auth does not depend on flutter_localizations, and does not need
    // to: `MaterialApp` supplies DefaultMaterialLocalizations for `en` itself.
    localizationsDelegates: const [CoreL10n.delegate],
    supportedLocales: CoreL10n.supportedLocales,
    home: BlocProvider<LoginBloc>(
      create: (_) => instance ?? bloc(),
      child: LoginScreen(onAuthenticated: onAuthenticated),
    ),
  );

  group('rendering', () {
    testWidgets('shows the form', (tester) async {
      await tester.pumpWidget(host());

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Sign in'), findsOneWidget);
    });

    testWidgets('opens with no errors and a disabled submit', (tester) async {
      // `displayError` is null while an input is pristine, so an untouched form
      // must not open covered in red — and the button must not invite a submit
      // that would immediately fail.
      await tester.pumpWidget(host());

      expect(find.text('Enter a valid email address'), findsNothing);
      expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);
    });

    testWidgets('has no app bar, because login has nowhere to go back to', (tester) async {
      await tester.pumpWidget(host());

      expect(find.byType(AppBar), findsNothing);
    });
  });

  group('validation', () {
    testWidgets('an invalid email shows its error once the field is dirty', (tester) async {
      await tester.pumpWidget(host());

      await tester.enterText(find.byType(AppTextField).first, 'not-an-email');
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('submit enables only when both inputs are valid', (tester) async {
      await tester.pumpWidget(host());

      await tester.enterText(find.byType(AppTextField).first, 'a@b.com');
      await tester.pump();
      expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNull, reason: 'password is still empty');

      await tester.enterText(find.byType(AppTextField).last, 'Passw0rd!');
      await tester.pump();
      expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNotNull);
    });
  });

  group('rebuild scope', () {
    testWidgets('typing in one field does not rebuild the other', (tester) async {
      // ADR-0008, asserted. Each counter wraps the *builder* of one selector, so
      // it counts exactly what that selector decided to rebuild.
      //
      // The bloc is owned by a `BlocProvider(create:)` and reached through the
      // tree rather than constructed here and closed by the test. `await
      // bloc.close()` inside a `testWidgets` body never returns: `BaseBloc.close`
      // awaits `_effects.close()` and then `super.close()`, and those complete on
      // machinery the fake-async clock only advances when something pumps — so
      // the await sits there and takes the whole suite down with it. Letting the
      // provider close it during teardown is both correct ownership and the only
      // shape that terminates. `fakes/fake_auth.dart` documents the same trap for
      // `StreamController.close`.
      final rebuilds = <String, int>{'email': 0, 'password': 0};

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: const [CoreL10n.delegate],
          supportedLocales: CoreL10n.supportedLocales,
          home: BlocProvider<LoginBloc>(
            create: (_) => bloc(),
            child: Scaffold(
              body: Column(
                children: [
                  BlocSelector<LoginBloc, LoginState, Email>(
                    selector: (state) => state.email,
                    builder: (context, email) {
                      rebuilds['email'] = rebuilds['email']! + 1;
                      return const SizedBox.shrink();
                    },
                  ),
                  BlocSelector<LoginBloc, LoginState, Password>(
                    selector: (state) => state.password,
                    builder: (context, password) {
                      rebuilds['password'] = rebuilds['password']! + 1;
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final baseline = Map<String, int>.from(rebuilds);

      tester.element(find.byType(Column)).read<LoginBloc>().add(const LoginEmailChanged('a@b.com'));
      await tester.pump();

      expect(rebuilds['email'], baseline['email']! + 1);
      expect(
        rebuilds['password'],
        baseline['password'],
        reason: 'a change to the email slice must not rebuild the password slice',
      );
    });
  });

  group('effects', () {
    testWidgets('a successful sign-in calls onAuthenticated exactly once', (tester) async {
      var navigations = 0;
      await tester.pumpWidget(host(onAuthenticated: () => navigations++));

      await tester.enterText(find.byType(AppTextField).first, 'a@b.com');
      await tester.enterText(find.byType(AppTextField).last, 'Passw0rd!');
      await tester.pump();
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(navigations, 1);
    });

    testWidgets('the callback does not re-fire on a later rebuild', (tester) async {
      // Rule 4's actual payoff. A `didSucceed` flag on the state would navigate
      // again on the next rebuild; an effect is consumed once.
      var navigations = 0;
      await tester.pumpWidget(host(onAuthenticated: () => navigations++));

      await tester.enterText(find.byType(AppTextField).first, 'a@b.com');
      await tester.enterText(find.byType(AppTextField).last, 'Passw0rd!');
      await tester.pump();
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      await tester.pump();
      await tester.pump();

      expect(navigations, 1);
    });

    testWidgets('a failed sign-in shows a toast and stays on the screen', (tester) async {
      repository.failWith = const UnauthorizedFailure(debugMessage: 'wrong password');
      var navigations = 0;
      await tester.pumpWidget(host(onAuthenticated: () => navigations++));

      await tester.enterText(find.byType(AppTextField).first, 'a@b.com');
      await tester.enterText(find.byType(AppTextField).last, 'Passw0rd!');
      await tester.pump();
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(navigations, 0);
      // The copy comes from `FailurePresenter`, keyed off the failure *type* —
      // never from `debugMessage`, which is for logs. A toast shows the
      // presenter's `description`; the `title` is for the full-page error view.
      expect(find.text('Please sign in again to continue.'), findsOneWidget);
      expect(find.text('wrong password'), findsNothing, reason: 'debugMessage must never reach the user');
    });

    testWidgets('a second tap while in flight does not submit twice', (tester) async {
      // `droppable()` on the submit handler plus `AppButton`'s loading guard.
      // Two sign-in requests from one impatient double tap is the bug.
      repository.delay = const Duration(milliseconds: 200);
      await tester.pumpWidget(host());

      await tester.enterText(find.byType(AppTextField).first, 'a@b.com');
      await tester.enterText(find.byType(AppTextField).last, 'Passw0rd!');
      await tester.pump();

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(repository.signInCalls, 1);
    });
  });

  group('AuthRouteModule', () {
    test('contributes login as a root route, not a shell route', () {
      // Login must not render inside the app shell's bottom navigation.
      final module = AuthRouteModule(loginBlocFactory: bloc, onAuthenticated: (_) {});

      expect(module.id, 'auth');
      expect(module.shellRoutes(), isEmpty);
      expect(module.rootRoutes(), hasLength(1));
      expect(AuthRouteModule.login.path, '/login');
    });

    testWidgets('builds a fresh bloc per visit', (tester) async {
      // Reusing one would carry the previous attempt's error and a stale
      // password into the next sign-in.
      var built = 0;
      final module = AuthRouteModule(
        loginBlocFactory: () {
          built++;
          return bloc();
        },
        onAuthenticated: (_) {},
      );

      final route = module.rootRoutes().single as GoRoute;
      final router = GoRouter(initialLocation: '/login', routes: [route]);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          localizationsDelegates: const [CoreL10n.delegate],
          supportedLocales: CoreL10n.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(built, 1);
    });
  });
}
