import 'package:core_kit/core_kit.dart';
import 'package:mini_app_sample/src/domain/article.dart';

/// Stand-in data source so the template runs end-to-end with no backend.
///
/// Replace this with a Retrofit `@RestApi` data source plus a repository
/// extending `BaseRepository` — see `feature_auth` for that shape. The
/// interface above stays the same, which is the point: the screen, the bloc and
/// the use case do not change when the real API arrives.
final class InMemoryArticleRepository implements ArticleRepository {
  InMemoryArticleRepository({this.latency = const Duration(milliseconds: 400), int totalItems = 47})
    : _articles = [for (var index = 0; index < totalItems; index++) _generated(index)];

  final Duration latency;

  /// Newest first, same order `fetchPage` hands out — a real backing list
  /// rather than a formula, so [createArticle] has somewhere to put its
  /// result and the next `fetchPage` sees it.
  final List<Article> _articles;

  /// Set to simulate a failure and exercise the error and retry paths.
  Failure? failWith;

  /// Fails only the first attempt at this page — for demonstrating the
  /// load-more retry footer without breaking the whole list.
  int? failOncePage;

  final Set<int> _failedOnce = {};

  static Article _generated(int index) => Article(
    id: 'article-$index',
    title: 'Sample article #${index + 1}',
    summary: 'This row comes from InMemoryArticleRepository. Swap it for a real data source.',
    publishedAt: DateTime(2026, 1, 1).add(Duration(days: index)),
    category: ArticleCategory.values[index % ArticleCategory.values.length],
    featured: index % 5 == 0,
  );

  @override
  Future<Result<PagedList<Article>>> fetchPage(PageRequest request) async {
    await Future<void>.delayed(latency);

    final failure = failWith;
    if (failure != null) return Err(failure);

    if (failOncePage == request.page && _failedOnce.add(request.page)) {
      return const Err(NetworkFailure(debugMessage: 'simulated'));
    }

    final start = (request.page - 1) * request.size;
    if (start >= _articles.length) {
      return Ok(PagedList<Article>(items: const [], page: request.page, hasMore: false, totalItems: _articles.length));
    }

    final end = (start + request.size).clamp(0, _articles.length);
    return Ok(
      PagedList<Article>(
        items: _articles.sublist(start, end),
        page: request.page,
        hasMore: end < _articles.length,
        totalItems: _articles.length,
      ),
    );
  }

  @override
  Future<Result<Article>> createArticle({
    required String title,
    required String summary,
    required ArticleCategory category,
    required DateTime publishedAt,
    required bool featured,
  }) async {
    await Future<void>.delayed(latency);

    final failure = failWith;
    if (failure != null) return Err(failure);

    final article = Article(
      // Timestamp rather than a running index: the running index already
      // named `_articles.length` slots during seeding, and reusing it here
      // would collide with a seeded id the moment one article is created.
      id: 'article-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      summary: summary,
      publishedAt: publishedAt,
      category: category,
      featured: featured,
    );
    _articles.insert(0, article);
    return Ok(article);
  }
}
