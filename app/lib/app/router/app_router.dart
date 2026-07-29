import 'package:app/app/router/guards/session_guard.dart';
import 'package:app/app/session/session_cubit.dart';
import 'package:app/app/shell/app_shell.dart';
import 'package:app/app/shell/home_screen.dart';
import 'package:app/app/shell/splash_screen.dart';
import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:mini_app_contract/mini_app_contract.dart';

/// Assembles the app's router from route modules and guards.
///
/// Compare with what this replaces: a single `app_routers.dart` with sixty
/// imports, one per screen, that every feature branch had to touch and that
/// made the host package depend on every feature's internals. Here the host
/// names *modules*, and a module is the only thing a feature exports.
final class AppRouter {
  AppRouter({
    required SessionCubit session,
    required MiniAppRegistry miniApps,
    required LoginBloc Function() loginBlocFactory,
    required ValueNotifier<ThemeMode> themeMode,
    required ValueChanged<ThemeMode> onThemeModeChanged,
    AppLogger logger = const NoopLogger(),
  }) {
    final listenable = SessionRefreshListenable(session);

    router = AppRouterBuilder(
      initialLocation: SplashScreen.spec.path,
      // Fires a redirect re-evaluation on sign-in and sign-out; without it a
      // signed-out user keeps looking at a protected screen.
      refreshListenable: listenable,
      logger: logger,
      guards: [
        SessionGuard(
          session,
          loginLocation: AuthRouteModule.login.path,
          homeLocation: HomeScreen.spec.path,
          splashLocation: SplashScreen.spec.path,
        ),
      ],
      shellBuilder: (context, state, child) => AppShell(child: child),
      modules: [
        _SplashRouteModule(),
        ShellRouteModule(registry: () => miniApps, themeMode: themeMode, onThemeModeChanged: onThemeModeChanged),
        AuthRouteModule(loginBlocFactory: loginBlocFactory, onAuthenticated: (context) => HomeScreen.spec.go(context)),
        miniApps,
      ],
      errorBuilder: (context, state) => Scaffold(
        body: AppErrorView(
          failure: NotFoundFailure(debugMessage: state.uri.toString()),
          onRetry: () => HomeScreen.spec.go(context),
        ),
      ),
    ).build();
  }

  late final GoRouter router;
}

final class _SplashRouteModule implements RouteModule {
  @override
  String get id => 'splash';

  @override
  List<RouteBase> shellRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) => const [];

  @override
  List<RouteBase> rootRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) => [
    GoRoute(
      name: SplashScreen.spec.name,
      path: SplashScreen.spec.path,
      parentNavigatorKey: rootNavigatorKey,
      // The guard resolves this away on the first frame; it exists so there is
      // a valid initial location while the session is still `unknown`.
      redirect: (context, state) => null,
      builder: (context, state) => const SplashScreen(),
    ),
  ];
}
