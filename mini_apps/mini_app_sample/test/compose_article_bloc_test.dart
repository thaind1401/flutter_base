import 'dart:async';

import 'package:core_kit/core_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_sample/src/domain/article.dart';
import 'package:mini_app_sample/src/presentation/compose_article/compose_article_bloc.dart';

/// Hand-written rather than generated: small interface, and a fake reads as
/// documentation of what `ComposeArticleBloc` actually calls.
final class _FakeArticleRepository implements ArticleRepository {
  int createCalls = 0;
  Failure? failWith;

  /// Held open until the test completes it, so a `droppable()` race can be
  /// exercised deterministically instead of hoping two `add()` calls land
  /// close enough together.
  Completer<void>? gate;

  @override
  Future<Result<PagedList<Article>>> fetchPage(PageRequest request) async =>
      const Ok(PagedList(items: [], page: 1, hasMore: false, totalItems: 0));

  @override
  Future<Result<Article>> createArticle({
    required String title,
    required String summary,
    required ArticleCategory category,
    required DateTime publishedAt,
    required bool featured,
  }) async {
    createCalls++;
    await gate?.future;
    final failure = failWith;
    if (failure != null) return Err(failure);
    return Ok(
      Article(
        id: 'a1',
        title: title,
        summary: summary,
        publishedAt: publishedAt,
        category: category,
        featured: featured,
      ),
    );
  }
}

void main() {
  late _FakeArticleRepository repository;
  late ComposeArticleBloc bloc;

  setUp(() {
    repository = _FakeArticleRepository();
    bloc = ComposeArticleBloc(repository);
  });

  tearDown(() => bloc.close());

  test('starts empty, invalid, and not submitting', () {
    expect(bloc.state.title.value, '');
    expect(bloc.state.publishedAt, isNull);
    expect(bloc.state.category, ArticleCategory.news);
    expect(bloc.state.featured, isFalse);
    expect(bloc.state.isValid, isFalse);
    expect(bloc.state.canSubmit, isFalse);
  });

  test('each field event changes only that field', () async {
    // The point of the whole screen: five independent slices of one state. If
    // one setter reached into another field, this is where it would show up.
    bloc
      ..add(const ComposeTitleChanged('A real title'))
      ..add(const ComposeSummaryChanged('A summary long enough to pass validation'))
      ..add(const ComposeCategoryChanged(ArticleCategory.tutorial))
      ..add(ComposePublishedAtChanged(DateTime(2026, 6, 1)))
      ..add(const ComposeFeaturedChanged(true));

    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.title.value, 'A real title');
    expect(bloc.state.summary.value, 'A summary long enough to pass validation');
    expect(bloc.state.category, ArticleCategory.tutorial);
    expect(bloc.state.publishedAt, DateTime(2026, 6, 1));
    expect(bloc.state.featured, isTrue);
  });

  test('category and featured are always valid — no FormzInput needed', () async {
    // Ungated by design: a dropdown and a switch always hold a legal value,
    // unlike text, so wrapping them in FormzInput would add ceremony with
    // nothing to validate.
    bloc.add(const ComposeCategoryChanged(ArticleCategory.announcement));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.category, ArticleCategory.announcement);
  });

  test('canSubmit requires title, summary and a publish date together', () async {
    expect(bloc.state.canSubmit, isFalse);

    bloc.add(const ComposeTitleChanged('A real title'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.canSubmit, isFalse, reason: 'summary and date are still missing');

    bloc.add(const ComposeSummaryChanged('A summary long enough to pass validation'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.canSubmit, isFalse, reason: 'a publish date is still missing');

    bloc.add(ComposePublishedAtChanged(DateTime(2026, 6, 1)));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.canSubmit, isTrue);
  });

  test('submitting an invalid form reveals errors without calling the repository', () async {
    bloc.add(const ComposeSubmitted());
    await Future<void>.delayed(Duration.zero);

    expect(repository.createCalls, 0);
    // Pristine inputs show no error; submit must make them dirty so the
    // screen has something to display.
    expect(bloc.state.title.displayError, isNotNull);
    expect(bloc.state.summary.displayError, isNotNull);
  });

  test('a valid submit calls the repository and emits ComposeSucceeded', () async {
    final effects = <Object>[];
    final subscription = bloc.effects.listen(effects.add);
    addTearDown(subscription.cancel);

    bloc
      ..add(const ComposeTitleChanged('A real title'))
      ..add(const ComposeSummaryChanged('A summary long enough to pass validation'))
      ..add(ComposePublishedAtChanged(DateTime(2026, 6, 1)))
      ..add(const ComposeSubmitted());

    await Future<void>.delayed(Duration.zero);

    expect(repository.createCalls, 1);
    expect(effects, hasLength(1));
    expect(effects.single, isA<ComposeSucceeded>());
    expect((effects.single as ComposeSucceeded).article.title, 'A real title');
    expect(bloc.state.status, FormzSubmissionStatus.success);
  });

  test('a repository failure emits ComposeFailed and keeps the form filled in', () async {
    repository.failWith = const NetworkFailure();
    final effects = <Object>[];
    final subscription = bloc.effects.listen(effects.add);
    addTearDown(subscription.cancel);

    bloc
      ..add(const ComposeTitleChanged('A real title'))
      ..add(const ComposeSummaryChanged('A summary long enough to pass validation'))
      ..add(ComposePublishedAtChanged(DateTime(2026, 6, 1)))
      ..add(const ComposeSubmitted());

    await Future<void>.delayed(Duration.zero);

    expect(effects.single, isA<ComposeFailed>());
    expect(bloc.state.status, FormzSubmissionStatus.failure);
    // A failed submit must not clear what the user typed — retyping a whole
    // article after a network blip is the alternative.
    expect(bloc.state.title.value, 'A real title');
  });

  test('editing a field after a failed submit clears the failure', () async {
    repository.failWith = const NetworkFailure();
    bloc
      ..add(const ComposeTitleChanged('A real title'))
      ..add(const ComposeSummaryChanged('A summary long enough to pass validation'))
      ..add(ComposePublishedAtChanged(DateTime(2026, 6, 1)))
      ..add(const ComposeSubmitted());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.failure, isNotNull);

    bloc.add(const ComposeFeaturedChanged(true));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.failure, isNull);
  });

  test('a second submit while the first is in flight is dropped', () async {
    repository.gate = Completer<void>();
    bloc
      ..add(const ComposeTitleChanged('A real title'))
      ..add(const ComposeSummaryChanged('A summary long enough to pass validation'))
      ..add(ComposePublishedAtChanged(DateTime(2026, 6, 1)));
    await Future<void>.delayed(Duration.zero);

    bloc
      ..add(const ComposeSubmitted())
      ..add(const ComposeSubmitted());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.isSubmitting, isTrue);
    repository.gate!.complete();
    await Future<void>.delayed(Duration.zero);

    // Two taps, one call — the double-submit bug `droppable()` exists to
    // prevent, same as LoginBloc.
    expect(repository.createCalls, 1);
  });
}
