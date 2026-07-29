import 'package:core_arch/core_arch.dart';
import 'package:feature_auth/src/presentation/login/login_bloc.dart';
import 'package:feature_auth/src/presentation/login/login_screen.dart';
import 'package:flutter/widgets.dart';

/// This feature's contribution to the router.
///
/// The host composes it into `AppRouterBuilder`; the host never imports
/// [LoginScreen]. Note the two injected collaborators — the bloc factory and
/// the post-login destination. Without them this package would have to know the
/// app's DI container and its home route, which is exactly the coupling that
/// makes a feature un-reusable in the next project.
final class AuthRouteModule implements RouteModule {
  const AuthRouteModule({required this.loginBlocFactory, required this.onAuthenticated});

  /// Usually `() => getIt<LoginBloc>()`.
  final LoginBloc Function() loginBlocFactory;

  /// Where to go once signed in — decided by the host, not by this feature.
  final void Function(BuildContext context) onAuthenticated;

  static const RouteSpec login = RouteSpec(name: 'login', path: '/login');

  @override
  String get id => 'auth';

  /// Login is full screen: it must not render inside the app shell's bottom
  /// navigation.
  @override
  List<RouteBase> shellRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) => const [];

  @override
  List<RouteBase> rootRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) => [
    GoRoute(
      name: login.name,
      path: login.path,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => BlocProvider<LoginBloc>(
        // A fresh bloc per visit: reusing one would carry the previous
        // attempt's error and a stale password into the next sign-in.
        create: (_) => loginBlocFactory(),
        child: LoginScreen(onAuthenticated: () => onAuthenticated(context)),
      ),
    ),
  ];
}
