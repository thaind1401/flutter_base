import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:mini_app_contract/src/mini_app.dart';

/// Holds the installed mini-apps and presents them to the host as one
/// [RouteModule] and one list of entry points.
///
/// Adding a mini-app is then a single line in the composition root. Removing
/// one is deleting that line — no route file to edit, no menu to prune, no
/// dangling import left behind.
final class MiniAppRegistry implements RouteModule {
  MiniAppRegistry(List<MiniApp> miniApps, {AppLogger logger = const NoopLogger()})
    : _miniApps = List.unmodifiable(miniApps),
      _logger = logger {
    _assertUniqueIds();
  }

  final List<MiniApp> _miniApps;
  final AppLogger _logger;

  List<MiniApp> get miniApps => _miniApps;

  @override
  String get id => 'mini_apps';

  void registerDependencies(GetIt getIt, MiniAppHost host) {
    for (final miniApp in _miniApps) {
      _logger.debug('registering mini-app ${miniApp.id}', tag: 'mini_apps');
      miniApp.registerDependencies(getIt, host);
    }
  }

  @override
  List<RouteBase> rootRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) => [
    for (final miniApp in _miniApps) ...miniApp.rootRoutes(rootNavigatorKey: rootNavigatorKey),
  ];

  @override
  List<RouteBase> shellRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) => [
    for (final miniApp in _miniApps) ...miniApp.shellRoutes(rootNavigatorKey: rootNavigatorKey),
  ];

  /// Entry points for one placement, in registration order.
  List<MiniAppEntryPoint> entryPointsFor(BuildContext context, MiniAppPlacement placement) => [
    for (final miniApp in _miniApps) ...miniApp.entryPoints(context).where((entry) => entry.appearsIn(placement)),
  ];

  void _assertUniqueIds() {
    assert(() {
      final seen = <String>{};
      for (final miniApp in _miniApps) {
        if (!seen.add(miniApp.id)) {
          throw StateError('Duplicate mini-app id "${miniApp.id}".');
        }
      }
      return true;
    }());
  }
}
