import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:meta/meta.dart';
import 'package:mini_app_sample/src/domain/article.dart';

sealed class ComposeArticleEvent {
  const ComposeArticleEvent();
}

final class ComposeTitleChanged extends ComposeArticleEvent {
  const ComposeTitleChanged(this.value);

  final String value;
}

final class ComposeSummaryChanged extends ComposeArticleEvent {
  const ComposeSummaryChanged(this.value);

  final String value;
}

final class ComposeCategoryChanged extends ComposeArticleEvent {
  const ComposeCategoryChanged(this.value);

  final ArticleCategory value;
}

final class ComposePublishedAtChanged extends ComposeArticleEvent {
  const ComposePublishedAtChanged(this.value);

  final DateTime value;
}

final class ComposeFeaturedChanged extends ComposeArticleEvent {
  const ComposeFeaturedChanged(this.value);

  final bool value;
}

final class ComposeSubmitted extends ComposeArticleEvent {
  const ComposeSubmitted();
}

/// Five independent fields plus submission status, in one flat state.
///
/// This is the reference for ADR-0008 with more than two fields: each setter
/// event touches exactly one property, `props` lists all seven, and the screen
/// (`compose_article_screen.dart`) gives each field its own `BlocSelector` so a
/// date picked in [publishedAt] never rebuilds the title field.
@immutable
final class ComposeArticleState extends Equatable {
  const ComposeArticleState({
    this.title = const RequiredText.pure(minLength: 3, maxLength: 120),
    this.summary = const RequiredText.pure(minLength: 10, maxLength: 500),
    this.category = ArticleCategory.news,
    this.publishedAt,
    this.featured = false,
    this.status = FormzSubmissionStatus.initial,
    this.failure,
  });

  final RequiredText title;
  final RequiredText summary;
  final ArticleCategory category;

  /// Null until the user picks one — unlike [category], which always has a
  /// value, so this is the one field that needs its own validity check
  /// alongside the two `FormzInput`s.
  final DateTime? publishedAt;

  final bool featured;
  final FormzSubmissionStatus status;

  /// Kept so the screen can render an inline banner; a new attempt clears it
  /// (see [copyWith]) rather than carrying a stale error into the next try.
  final Failure? failure;

  bool get isValid => Formz.validate([title, summary]) && publishedAt != null;

  bool get isSubmitting => status == FormzSubmissionStatus.inProgress;

  bool get canSubmit => isValid && !isSubmitting;

  ComposeArticleState copyWith({
    RequiredText? title,
    RequiredText? summary,
    ArticleCategory? category,
    DateTime? publishedAt,
    bool? featured,
    FormzSubmissionStatus? status,
    Failure? failure,
  }) => ComposeArticleState(
    title: title ?? this.title,
    summary: summary ?? this.summary,
    category: category ?? this.category,
    publishedAt: publishedAt ?? this.publishedAt,
    featured: featured ?? this.featured,
    status: status ?? this.status,
    // Explicitly not `failure ?? this.failure`, same as LoginState: a new
    // attempt must clear the previous error rather than inherit it.
    failure: failure,
  );

  @override
  List<Object?> get props => [title, summary, category, publishedAt, featured, status, failure];
}

/// One-shot outcomes. Delivered over the effect stream, never stored in state.
sealed class ComposeArticleEffect {
  const ComposeArticleEffect();
}

final class ComposeSucceeded extends ComposeArticleEffect {
  const ComposeSucceeded(this.article);

  final Article article;
}

final class ComposeFailed extends ComposeArticleEffect {
  const ComposeFailed(this.failure);

  final Failure failure;
}

/// Depends on `ArticleRepository` directly rather than a use case, matching
/// `ArticleListBloc` in this same package: `mini_app_sample` has no use-case
/// layer, unlike `feature_auth`. Introducing one here for a single bloc would
/// make this package inconsistent with itself rather than more correct.
final class ComposeArticleBloc extends BaseBloc<ComposeArticleEvent, ComposeArticleState> {
  ComposeArticleBloc(this._repository) : super(const ComposeArticleState()) {
    on<ComposeTitleChanged>(_onTitleChanged);
    on<ComposeSummaryChanged>(_onSummaryChanged);
    on<ComposeCategoryChanged>(_onCategoryChanged);
    on<ComposePublishedAtChanged>(_onPublishedAtChanged);
    on<ComposeFeaturedChanged>(_onFeaturedChanged);
    // A second tap while the create call is in flight must not fire twice.
    on<ComposeSubmitted>(_onSubmitted, transformer: droppable());
  }

  final ArticleRepository _repository;

  void _onTitleChanged(ComposeTitleChanged event, Emitter<ComposeArticleState> emit) => emit(
    state.copyWith(
      title: RequiredText.dirty(event.value, minLength: 3, maxLength: 120),
      status: FormzSubmissionStatus.initial,
    ),
  );

  void _onSummaryChanged(ComposeSummaryChanged event, Emitter<ComposeArticleState> emit) => emit(
    state.copyWith(
      summary: RequiredText.dirty(event.value, minLength: 10, maxLength: 500),
      status: FormzSubmissionStatus.initial,
    ),
  );

  void _onCategoryChanged(ComposeCategoryChanged event, Emitter<ComposeArticleState> emit) =>
      emit(state.copyWith(category: event.value, status: FormzSubmissionStatus.initial));

  void _onPublishedAtChanged(ComposePublishedAtChanged event, Emitter<ComposeArticleState> emit) =>
      emit(state.copyWith(publishedAt: event.value, status: FormzSubmissionStatus.initial));

  void _onFeaturedChanged(ComposeFeaturedChanged event, Emitter<ComposeArticleState> emit) =>
      emit(state.copyWith(featured: event.value, status: FormzSubmissionStatus.initial));

  Future<void> _onSubmitted(ComposeSubmitted event, Emitter<ComposeArticleState> emit) async {
    if (!state.isValid) {
      // Re-emitting the text inputs as dirty makes a pristine field reveal its
      // error when the user submits without having touched it. publishedAt has
      // no "dirty" concept — its own field renders the error directly off
      // `isValid` instead.
      emit(
        state.copyWith(
          title: RequiredText.dirty(state.title.value, minLength: 3, maxLength: 120),
          summary: RequiredText.dirty(state.summary.value, minLength: 10, maxLength: 500),
          status: FormzSubmissionStatus.failure,
        ),
      );
      return;
    }

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    final result = await _repository.createArticle(
      title: state.title.value,
      summary: state.summary.value,
      category: state.category,
      publishedAt: state.publishedAt!,
      featured: state.featured,
    );

    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: FormzSubmissionStatus.success));
        emitEffect(ComposeSucceeded(value));
      case Err(:final failure):
        emit(state.copyWith(status: FormzSubmissionStatus.failure, failure: failure));
        emitEffect(ComposeFailed(failure));
    }
  }
}
