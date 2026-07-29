import 'package:core_kit/core_kit.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Deliberately plain, not a `FormzInput`: every value is valid, so there is
/// nothing to validate — a dropdown's state does not need the machinery a text
/// field's does.
enum ArticleCategory { news, tutorial, announcement }

@immutable
final class Article extends Equatable {
  const Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.publishedAt,
    this.category = ArticleCategory.news,
    this.featured = false,
  });

  final String id;
  final String title;
  final String summary;
  final DateTime publishedAt;
  final ArticleCategory category;
  final bool featured;

  @override
  List<Object?> get props => [id, title, summary, publishedAt, category, featured];
}

/// The mini-app's own repository interface. It does not reuse a host
/// repository, and the host cannot see this type.
abstract interface class ArticleRepository {
  Future<Result<PagedList<Article>>> fetchPage(PageRequest request);

  /// Adds an article and returns it, so the caller can navigate with the
  /// server-assigned id rather than a locally-guessed one.
  Future<Result<Article>> createArticle({
    required String title,
    required String summary,
    required ArticleCategory category,
    required DateTime publishedAt,
    required bool featured,
  });
}
