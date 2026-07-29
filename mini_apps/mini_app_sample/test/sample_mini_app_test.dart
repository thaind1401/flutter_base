import 'package:core_kit/core_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mini_app_contract/mini_app_contract.dart';
import 'package:mini_app_sample/mini_app_sample.dart';
// The barrel exports SampleMiniApp and nothing else, on purpose — the host must
// not be able to reach these. A test inside the package is the one caller
// allowed past that line, and importing `src/` explicitly keeps the fact that
// it is doing so visible.
import 'package:mini_app_sample/src/data/in_memory_article_repository.dart';
import 'package:mini_app_sample/src/domain/article.dart';
import 'package:mini_app_sample/src/presentation/article_list_bloc.dart';
import 'package:mini_app_sample/src/presentation/compose_article/compose_article_bloc.dart';

/// Stands in for the app. Records what the mini-app asks of it, which is the
/// only channel a mini-app is allowed to use.
final class _RecordingHost implements MiniAppHost {
  _RecordingHost({this.enabledFlags = const {}});

  final Set<String> enabledFlags;
  final List<String> flagsChecked = [];
  final List<String> routesOpened = [];

  @override
  String? get currentUserId => 'u1';

  @override
  Locale get locale => const Locale('en');

  @override
  bool isFeatureEnabled(String key) {
    flagsChecked.add(key);
    return enabledFlags.contains(key);
  }

  @override
  void openHostRoute(String routeName, {Map<String, String> pathParameters = const {}}) => routesOpened.add(routeName);
}

void main() {
  late GetIt container;

  setUp(() => container = GetIt.asNewInstance());
  tearDown(() => container.reset());

  group('SampleMiniApp satisfies the contract', () {
    test('exposes a stable id and no shell routes', () {
      final miniApp = SampleMiniApp();

      expect(miniApp.id, 'sample');
      expect(miniApp.shellRoutes(), isEmpty);
    });

    test('its route path is namespaced so two mini-apps cannot collide', () {
      // Every mini-app owning a slice of /mini/<id>/ is what lets the host
      // compose them without a central route table to keep in sync.
      expect(SampleMiniApp.articles.path, startsWith('/mini/sample/'));
      expect(SampleMiniApp.articles.name, startsWith('sample.'));
      expect(SampleMiniApp.compose.path, startsWith('/mini/sample/'));
    });

    test('exposes a root route for the compose form as well as the list', () {
      // rootRoutes, not shellRoutes: same reasoning as login in AuthRouteModule
      // — a focused task, not a bottom-navigation destination.
      expect(SampleMiniApp().rootRoutes(), hasLength(2));
    });

    test('registerDependencies puts its repository behind an instance name', () {
      SampleMiniApp().registerDependencies(container, _RecordingHost());

      // Unnamed, a second mini-app registering its own ArticleRepository would
      // overwrite this one and the two would silently share data.
      expect(container.isRegistered<ArticleRepository>(instanceName: 'sample.articles'), isTrue);
      expect(container.isRegistered<ArticleRepository>(), isFalse);
    });

    test('its bloc resolves from the container after registration', () {
      SampleMiniApp().registerDependencies(container, _RecordingHost());

      final bloc = container<ArticleListBloc>();
      addTearDown(bloc.close);
      expect(bloc, isNotNull);

      // A factory, not a singleton: two screens must not share one bloc, or
      // closing the first tears down the second.
      final second = container<ArticleListBloc>();
      addTearDown(second.close);
      expect(second, isNot(same(bloc)));
    });

    testWidgets('its entry point appears on home and in the workspace', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox.shrink();
          },
        ),
      );

      final entry = SampleMiniApp().entryPoints(context).single;

      expect(entry.title, isNotEmpty);
      expect(entry.appearsIn(MiniAppPlacement.home), isTrue);
      expect(entry.appearsIn(MiniAppPlacement.workspace), isTrue);
      expect(entry.appearsIn(MiniAppPlacement.profile), isFalse);
    });

    test('it reads its flag through the host rather than importing one', () {
      // The whole point of MiniAppHost: a dark launch is the host's decision,
      // and the mini-app learns it without either package importing the other.
      final off = _RecordingHost();
      final miniApp = SampleMiniApp()..registerDependencies(container, off);

      expect(miniApp.isEnabled, isFalse);
      expect(off.flagsChecked, ['mini_app.sample']);

      final on = _RecordingHost(enabledFlags: const {'mini_app.sample'});
      expect((SampleMiniApp()..registerDependencies(GetIt.asNewInstance(), on)).isEnabled, isTrue);
    });

    test('it defaults to enabled before the host has been attached', () {
      // registerDependencies runs at startup, but `isEnabled` may be read by a
      // menu built earlier. Defaulting to off would hide the mini-app for one
      // frame on every cold start.
      expect(SampleMiniApp().isEnabled, isTrue);
    });

    test('the compose bloc shares the same repository instance as the list', () {
      SampleMiniApp().registerDependencies(container, _RecordingHost());

      final listBloc = container<ArticleListBloc>();
      final composeBloc = container<ComposeArticleBloc>();
      addTearDown(listBloc.close);
      addTearDown(composeBloc.close);

      // Both factories resolve `ArticleRepository` under the same instance
      // name. If they did not, an article created in the compose form would
      // land in a repository the list bloc never reads from.
      expect(container<ArticleRepository>(instanceName: 'sample.articles'), isNotNull);
    });

    test('compose bloc is a factory, not a singleton', () {
      SampleMiniApp().registerDependencies(container, _RecordingHost());

      final first = container<ComposeArticleBloc>();
      final second = container<ComposeArticleBloc>();
      addTearDown(first.close);
      addTearDown(second.close);

      // A fresh bloc per visit, same reasoning as LoginBloc: reusing one would
      // carry the previous draft into the next form.
      expect(second, isNot(same(first)));
    });
  });

  group('InMemoryArticleRepository', () {
    // No latency: the default 400ms exists to make the demo look like a real
    // network, and would make every test here wait for it.
    InMemoryArticleRepository repository({int totalItems = 47}) =>
        InMemoryArticleRepository(latency: Duration.zero, totalItems: totalItems);

    test('the first page reports more to come', () async {
      final page = (await repository().fetchPage(const PageRequest(page: 1, size: 20))).valueOrNull!;

      expect(page.items, hasLength(20));
      expect(page.hasMore, isTrue);
      expect(page.totalItems, 47);
    });

    test('the last page is short and closes the list', () async {
      final page = (await repository().fetchPage(const PageRequest(page: 3, size: 20))).valueOrNull!;

      // 47 items, 20 per page — the third page holds 7. A repository that
      // reported hasMore here would leave the list paging forever.
      expect(page.items, hasLength(7));
      expect(page.hasMore, isFalse);
    });

    test('reading past the end is empty rather than an error', () async {
      final page = (await repository().fetchPage(const PageRequest(page: 99, size: 20))).valueOrNull!;

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('pages do not overlap or skip', () async {
      final first = (await repository().fetchPage(const PageRequest(page: 1, size: 20))).valueOrNull!;
      final second = (await repository().fetchPage(const PageRequest(page: 2, size: 20))).valueOrNull!;

      final ids = <String>{
        ...first.items.map((Article article) => article.id),
        ...second.items.map((Article article) => article.id),
      };
      expect(ids, hasLength(40), reason: 'a duplicated id means the offset arithmetic is wrong');
    });

    test('failWith drives the error path', () async {
      final store = repository()..failWith = const NetworkFailure();

      expect((await store.fetchPage(const PageRequest(page: 1, size: 20))).isErr, isTrue);
    });

    test('failOncePage fails a page once and then succeeds', () async {
      // This is what the load-more retry footer is demonstrated against; if it
      // failed every time the demo would look broken instead of recoverable.
      final store = repository()..failOncePage = 2;

      expect((await store.fetchPage(const PageRequest(page: 2, size: 20))).isErr, isTrue);
      expect((await store.fetchPage(const PageRequest(page: 2, size: 20))).isOk, isTrue);
    });

    group('createArticle', () {
      test('the created article is what the next fetch sees first', () async {
        final store = repository();

        final created = await store.createArticle(
          title: 'Hand-written title',
          summary: 'Hand-written summary',
          category: ArticleCategory.tutorial,
          publishedAt: DateTime(2026, 6, 1),
          featured: true,
        );

        final page = (await store.fetchPage(const PageRequest(page: 1, size: 20))).valueOrNull!;

        // "Front of the list" is the whole point of a compose form — a screen
        // where submitting and never seeing the result again would look
        // broken even though the write technically succeeded.
        expect(page.items.first, created.valueOrNull);
        expect(page.totalItems, 48);
      });

      test('two created articles do not collide on id', () async {
        final store = repository();

        final first = await store.createArticle(
          title: 'a',
          summary: 'a',
          category: ArticleCategory.news,
          publishedAt: DateTime(2026),
          featured: false,
        );
        final second = await store.createArticle(
          title: 'b',
          summary: 'b',
          category: ArticleCategory.news,
          publishedAt: DateTime(2026),
          featured: false,
        );

        expect(first.valueOrNull!.id, isNot(second.valueOrNull!.id));
      });

      test('failWith blocks a create the same way it blocks a fetch', () async {
        final store = repository()..failWith = const NetworkFailure();

        final result = await store.createArticle(
          title: 'a',
          summary: 'a',
          category: ArticleCategory.news,
          publishedAt: DateTime(2026),
          featured: false,
        );

        expect(result.isErr, isTrue);
      });
    });
  });
}
