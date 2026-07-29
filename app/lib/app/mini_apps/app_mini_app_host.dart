import 'package:app/app/session/session_cubit.dart';
import 'package:core_arch/core_arch.dart';
import 'package:flutter/widgets.dart';
import 'package:mini_app_contract/mini_app_contract.dart';

/// The host's side of the mini-app contract.
///
/// Everything a mini-app is allowed to know about the app lives here, and it is
/// deliberately thin: an anonymous user id, a locale, a way to navigate by
/// route name, and feature flags. A mini-app that needs more should be asking
/// for a wider contract in `mini_app_contract`, reviewed on its merits — not
/// reaching into the host.
final class AppMiniAppHost implements MiniAppHost {
  const AppMiniAppHost({
    required this.session,
    required this.navigator,
    required this.featureFlags,
    required this.locale,
  });

  final SessionCubit session;
  final AppNavigator navigator;

  /// Replace with remote config in a real project.
  final Map<String, bool> featureFlags;

  @override
  final Locale locale;

  @override
  String? get currentUserId => session.user?.id;

  @override
  void openHostRoute(String routeName, {Map<String, String> pathParameters = const {}}) =>
      navigator.goNamed(routeName, pathParameters: pathParameters);

  @override
  bool isFeatureEnabled(String key) => featureFlags[key] ?? true;
}

/// Registry of installed mini-apps.
///
/// This list is the *entire* cost of adding a mini-app: one line here, plus the
/// dependency in `pubspec.yaml`. No route file to edit, no menu to update, no
/// DI entries to add.
List<MiniApp> installedMiniApps() => [
  // SampleMiniApp() is added by the composition root so this file has no
  // dependency on any particular mini-app package.
];
