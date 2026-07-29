import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:mini_app_sample/src/domain/article.dart';

sealed class ArticleListEvent {
  const ArticleListEvent();
}

final class ArticleListStarted extends ArticleListEvent {
  const ArticleListStarted();
}

final class ArticleListRefreshed extends ArticleListEvent {
  const ArticleListRefreshed();
}

final class ArticleListLoadMore extends ArticleListEvent {
  const ArticleListLoadMore();
}

/// Reference pagination bloc.
///
/// The three transformers are the interesting part and are each load-bearing:
///   * `restartable()` on refresh — a second pull cancels the first, so two
///     overlapping refreshes cannot land out of order and show page 1 twice;
///   * `droppable()` on load-more — the scroll listener fires repeatedly while
///     the user keeps scrolling, and every extra event would fetch the same
///     page again;
///   * the default (`concurrent`) is wrong for both, which is why neither is
///     left unspecified.
final class ArticleListBloc extends BaseBloc<ArticleListEvent, PagedViewState<Article>> {
  ArticleListBloc(this._repository) : super(const PagedViewState<Article>()) {
    on<ArticleListStarted>(_onStarted, transformer: droppable());
    on<ArticleListRefreshed>(_onRefreshed, transformer: restartable());
    on<ArticleListLoadMore>(_onLoadMore, transformer: droppable());
  }

  final ArticleRepository _repository;

  Future<void> _onStarted(ArticleListStarted event, Emitter<PagedViewState<Article>> emit) async {
    if (state.items.isNotEmpty) return;
    emit(state.loadingFirstPage());
    await _fetch(emit, state.request.first(), append: false);
  }

  Future<void> _onRefreshed(ArticleListRefreshed event, Emitter<PagedViewState<Article>> emit) async {
    emit(state.refreshing());
    await _fetch(emit, state.request.first(), append: false);
  }

  Future<void> _onLoadMore(ArticleListLoadMore event, Emitter<PagedViewState<Article>> emit) async {
    if (!state.canLoadMore) return;
    emit(state.loadingMore());
    await _fetch(emit, state.request, append: true);
  }

  Future<void> _fetch(Emitter<PagedViewState<Article>> emit, PageRequest request, {required bool append}) async {
    final result = await _repository.fetchPage(request);
    if (isClosed) return;

    switch (result) {
      case Ok(:final value):
        emit(append ? state.appended(value, identity: (article) => article.id) : state.loaded(value));
      case Err(:final failure):
        emit(state.failed(failure));
    }
  }
}
