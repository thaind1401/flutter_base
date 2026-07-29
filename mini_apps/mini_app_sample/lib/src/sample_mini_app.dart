import 'package:core_arch/core_arch.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:mini_app_contract/mini_app_contract.dart';
import 'package:mini_app_sample/src/data/in_memory_article_repository.dart';
import 'package:mini_app_sample/src/domain/article.dart';
import 'package:mini_app_sample/src/presentation/article_list_bloc.dart';
import 'package:mini_app_sample/src/presentation/article_list_screen.dart';
import 'package:mini_app_sample/src/presentation/compose_article/compose_article_bloc.dart';
import 'package:mini_app_sample/src/presentation/compose_article/compose_article_screen.dart';

/// The mini-app's single public class.
///
/// The host writes one line — `SampleMiniApp()` in its registry list — and gets
/// the routes, the menu entry and the dependency registration. It never imports
/// [ArticleListScreen], never sees [ArticleRepository], and does not know this
/// package uses bloc.
final class SampleMiniApp implements MiniApp {
  SampleMiniApp();

  static const RouteSpec articles = RouteSpec(name: 'sample.articles', path: '/mini/sample/articles');

  /// A root route rather than a shell one, same reasoning as login in
  /// `AuthRouteModule`: a compose form is a focused task, not a destination
  /// that belongs inside the bottom navigation.
  static const RouteSpec compose = RouteSpec(name: 'sample.compose', path: '/mini/sample/articles/new');

  MiniAppHost? _host;

  @override
  String get id => 'sample';

  @override
  void registerDependencies(GetIt getIt, MiniAppHost host) {
    _host = host;
    // Registered in an isolated instance name so two mini-apps can each have a
    // repository without colliding in the shared container.
    getIt
      ..registerLazySingleton<ArticleRepository>(InMemoryArticleRepository.new, instanceName: 'sample.articles')
      ..registerFactory<ArticleListBloc>(
        () => ArticleListBloc(getIt<ArticleRepository>(instanceName: 'sample.articles')),
      )
      ..registerFactory<ComposeArticleBloc>(
        () => ComposeArticleBloc(getIt<ArticleRepository>(instanceName: 'sample.articles')),
      );
  }

  @override
  List<RouteBase> shellRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) => const [];

  @override
  List<RouteBase> rootRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) => [
    GoRoute(
      name: articles.name,
      path: articles.path,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => BlocProvider<ArticleListBloc>(
        create: (_) => GetIt.I<ArticleListBloc>()..add(const ArticleListStarted()),
        child: const ArticleListScreen(),
      ),
    ),
    GoRoute(
      name: compose.name,
      path: compose.path,
      parentNavigatorKey: rootNavigatorKey,
      // A fresh bloc per visit, same reasoning as LoginBloc: reusing one would
      // carry the previous draft's text and error into the next form.
      builder: (context, state) => BlocProvider<ComposeArticleBloc>(
        create: (_) => GetIt.I<ComposeArticleBloc>(),
        child: const ComposeArticleScreen(),
      ),
    ),
  ];

  @override
  List<MiniAppEntryPoint> entryPoints(BuildContext context) => [
    MiniAppEntryPoint(
      id: id,
      title: 'Articles',
      description: 'Reference mini-app: paginated list',
      icon: Icons.article_outlined,
      placements: const {MiniAppPlacement.home, MiniAppPlacement.workspace},
      // Guarded by the host's own flag system, so this mini-app can be
      // dark-launched without the host knowing which key it reads.
      onOpen: (context) => articles.go(context),
    ),
  ];

  /// Example of using the host contract rather than importing the host.
  bool get isEnabled => _host?.isFeatureEnabled('mini_app.sample') ?? true;
}
