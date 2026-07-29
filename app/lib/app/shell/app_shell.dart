import 'package:app/app/shell/home_screen.dart';
import 'package:app/app/shell/settings_screen.dart';
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

  static const List<({String location, IconData icon, String label})> tabs = [
    (location: '/home', icon: Icons.home_outlined, label: 'Home'),
    (location: '/settings', icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    // `indexWhere` on a prefix so a nested route (/home/detail) keeps its tab
    // highlighted instead of falling back to the first one.
    final index = tabs.indexWhere((tab) => location.startsWith(tab.location));

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (next) => context.go(tabs[next].location),
        destinations: [for (final tab in tabs) NavigationDestination(icon: Icon(tab.icon), label: tab.label)],
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
  const ShellRouteModule({required this.registry, required this.themeMode, required this.onThemeModeChanged});

  final MiniAppRegistryRef registry;
  final ValueNotifier<ThemeMode> themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

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
      builder: (context, state) => SettingsScreen(themeMode: themeMode, onThemeModeChanged: onThemeModeChanged),
    ),
  ];
}

/// Deferred lookup of the registry, so the route module can be constructed
/// before the container is ready.
typedef MiniAppRegistryRef = MiniAppRegistry Function();
