import 'package:app/app/l10n/generated/app_l10n.dart';
import 'package:app/app/l10n/l10n_context_x.dart';
import 'package:app/app/shell/home_screen.dart';
import 'package:app/app/shell/settings_screen.dart';
import 'package:app/app/theme/theme_mode_controller.dart';
import 'package:core_arch/core_arch.dart';
import 'package:flutter/material.dart';
import 'package:mini_app_contract/mini_app_contract.dart';

/// Persistent chrome around the shell routes.
///
/// The tab list lives here rather than in each feature: which tabs an app has,
/// and in what order, is a product decision about the app as a whole. A feature
/// contributes a *route*; the host decides whether it gets a tab.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  /// The label is a function of the localizations rather than a string, because
  /// this list is `const` and a `const` cannot hold a translation: resolving copy
  /// needs a `BuildContext`, which does not exist yet here. Keeping the accessor
  /// next to the location and the icon is what stops the labels from drifting
  /// out of order relative to the tabs, which is what a parallel list of strings
  /// would eventually do.
  static const List<({String location, IconData icon, String Function(AppL10n) label})> tabs = [
    (location: '/home', icon: Icons.home_outlined, label: _homeLabel),
    (location: '/settings', icon: Icons.settings_outlined, label: _settingsLabel),
  ];

  static String _homeLabel(AppL10n l10n) => l10n.tabHome;

  static String _settingsLabel(AppL10n l10n) => l10n.tabSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final location = GoRouterState.of(context).matchedLocation;
    // `indexWhere` on a prefix so a nested route (/home/detail) keeps its tab
    // highlighted instead of falling back to the first one.
    final index = tabs.indexWhere((tab) => location.startsWith(tab.location));

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (next) => context.go(tabs[next].location),
        destinations: [for (final tab in tabs) NavigationDestination(icon: Icon(tab.icon), label: tab.label(l10n))],
      ),
    );
  }
}

/// The host's own routes.
///
/// The host is a [RouteModule] like any feature — it has no privileged path
/// into the router. That symmetry is what lets a screen move from the host into
/// a feature package later without the router changing.
final class ShellRouteModule implements RouteModule {
  const ShellRouteModule({required this.registry, required this.themeMode});

  final MiniAppRegistryRef registry;

  /// One object rather than the `ValueNotifier` + `ValueChanged` pair this used
  /// to take. The pair was two halves of the same thing threaded separately
  /// through three constructors, and nothing stopped a caller wiring the
  /// callback to a different notifier than the one the screen listened to.
  final ThemeModeController themeMode;

  @override
  String get id => 'shell';

  @override
  List<RouteBase> rootRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) => const [];

  @override
  List<RouteBase> shellRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) => [
    GoRoute(
      name: HomeScreen.spec.name,
      path: HomeScreen.spec.path,
      builder: (context, state) => HomeScreen(registry: registry()),
    ),
    GoRoute(
      name: SettingsScreen.spec.name,
      path: SettingsScreen.spec.path,
      builder: (context, state) => SettingsScreen(themeMode: themeMode),
    ),
  ];
}

/// Deferred lookup of the registry, so the route module can be constructed
/// before the container is ready.
typedef MiniAppRegistryRef = MiniAppRegistry Function();
