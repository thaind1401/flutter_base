import 'package:core_arch/core_arch.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

/// Where a mini-app's entry point may appear.
enum MiniAppPlacement { home, workspace, profile, more }

/// An entry point the host renders in a menu or on a dashboard.
@immutable
final class MiniAppEntryPoint {
  const MiniAppEntryPoint({
    required this.id,
    required this.title,
    required this.icon,
    required this.onOpen,
    this.description,
    this.placements = const {MiniAppPlacement.workspace},
    this.badgeCount,
  });

  final String id;
  final String title;
  final String? description;

  /// An [IconData], not an asset path: the mini-app owns its own assets and the
  /// host cannot resolve a path into another package's bundle without also
  /// knowing that package.
  final IconData icon;

  final void Function(BuildContext context) onOpen;
  final Set<MiniAppPlacement> placements;
  final int? badgeCount;

  bool appearsIn(MiniAppPlacement placement) => placements.contains(placement);
}

/// What a mini-app needs *from* the host.
///
/// This is the half that the previous generation was missing. Without it, a
/// mini-app that needs the signed-in user, the current locale, or a way to open
/// a host screen has to import the host's `AppState` — and then it is not a
/// mini-app any more, it is a folder.
abstract interface class MiniAppHost {
  /// Stable id of the signed-in user, or null. Not the user entity: the mini-app
  /// must not depend on the host's domain model, and an id is all it needs to
  /// scope its own data.
  String? get currentUserId;

  Locale get locale;

  /// Navigate to a host route by name. The mini-app knows the name; it does not
  /// know the widget.
  void openHostRoute(String routeName, {Map<String, String> pathParameters});

  /// Feature flags and remote config, so a mini-app can be dark-launched
  /// without the host knowing which flags it reads.
  bool isFeatureEnabled(String key);
}

/// What a mini-app offers *to* the host.
///
/// A mini-app is a package that implements this and nothing else is required of
/// it. It contributes routes and entry points, and registers its own
/// dependencies into the container the host passes in.
abstract interface class MiniApp implements RouteModule {
  /// Unique, stable — used in analytics and to detect a duplicate registration.
  @override
  String get id;

  /// Registers this mini-app's own dependencies. Called once at startup, before
  /// the router is built.
  void registerDependencies(GetIt getIt, MiniAppHost host);

  /// Menu entries the host renders. Called at build time so titles can be
  /// localized and badges can be live.
  List<MiniAppEntryPoint> entryPoints(BuildContext context);
}
