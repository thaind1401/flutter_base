import 'package:app/app/bootstrap.dart';
import 'package:app/app/di/injection.dart';
import 'package:app/app/router/app_router.dart';
import 'package:app/app/session/session_cubit.dart';
import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// The root widget.
///
/// Stateful only because it owns the router and the theme-mode notifier, both
/// of which must survive rebuilds. Rebuilding a `GoRouter` resets the
/// navigation stack, which is the classic "why did my app jump to home?" bug.
class App extends StatefulWidget {
  const App({super.key, required this.bootstrap});

  final BootstrapResult bootstrap;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final ValueNotifier<ThemeMode> _themeMode = ValueNotifier(ThemeMode.system);
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(
      session: widget.bootstrap.session,
      miniApps: widget.bootstrap.registry,
      loginBlocFactory: getIt.call<LoginBloc>,
      themeMode: _themeMode,
      onThemeModeChanged: (mode) => _themeMode.value = mode,
      logger: getIt<AppLogger>(),
    );
    // Completes the deferred navigator the mini-apps were handed at bootstrap.
    widget.bootstrap.navigatorBinder(GoRouterNavigator(_appRouter.router));
  }

  @override
  void dispose() {
    _themeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      session: widget.bootstrap.session,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _themeMode,
        builder: (context, themeMode, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: _appRouter.router,
          themeMode: themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          localizationsDelegates: const [
            CoreL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: CoreL10n.supportedLocales,
          // Mounted above the router so the blocking loader survives navigation
          // and cannot be popped away with the screen that started it.
          builder: (context, child) => LoadingOverlayHost(
            controller: getIt<LoadingOverlayController>(),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// App-wide providers. Kept to the few things every screen may read: the
/// session and the environment. Everything else is resolved from `getIt` where
/// it is needed, so this does not become a second, parallel DI container.
class MultiProvider extends StatelessWidget {
  const MultiProvider({super.key, required this.session, required this.child});

  final SessionCubit session;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SessionCubit>.value(
      value: session,
      child: RepositoryProvider<AppEnvironmentConfig>.value(value: getIt<AppEnvironmentConfig>(), child: child),
    );
  }
}
