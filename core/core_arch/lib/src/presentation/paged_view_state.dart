import 'package:core_kit/core_kit.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

enum PagedStatus { idle, loading, refreshing, loadingMore, ready, failed }

/// State for an infinite list.
///
/// Unlike [ViewState] this is **not** sealed, and that is deliberate: a paged
/// list is genuinely in several conditions at once — it can hold 40 items,
/// be loading page 3, and have failed on page 2 — so a closed set of states
/// would just be an enum crossed with itself. The invariant that matters
/// (never lose loaded items while loading more) is enforced by the transition
/// methods below rather than by the type.
@immutable
final class PagedViewState<T> extends Equatable {
  const PagedViewState({
    this.page = const PagedList.empty(),
    this.status = PagedStatus.idle,
    this.failure,
    this.request = const PageRequest(),
  });

  final PagedList<T> page;
  final PagedStatus status;

  /// Set for both a first-page failure (list is empty) and a load-more failure
  /// (items are still on screen). The widget decides which to render by also
  /// checking [isEmpty].
  final Failure? failure;

  /// The query/sort/size in effect, so a retry repeats the same request.
  final PageRequest request;

  List<T> get items => page.items;

  bool get isEmpty => page.items.isEmpty;

  bool get isFirstLoad => status == PagedStatus.loading && isEmpty;

  bool get isLoadingMore => status == PagedStatus.loadingMore;

  bool get isRefreshing => status == PagedStatus.refreshing;

  /// Guards the scroll listener: no load-more while one is in flight, after the
  /// last page, or while a previous load-more is still showing its error.
  bool get canLoadMore => page.hasMore && status == PagedStatus.ready;

  PagedViewState<T> loadingFirstPage({PageRequest? request}) => PagedViewState<T>(
    page: const PagedList.empty(),
    status: PagedStatus.loading,
    request: request ?? this.request.first(),
  );

  /// Keeps the current items visible while the refresh runs — clearing them
  /// makes the list jump and loses the user's scroll position.
  PagedViewState<T> refreshing() =>
      PagedViewState<T>(page: page, status: PagedStatus.refreshing, request: request.first());

  PagedViewState<T> loadingMore() =>
      PagedViewState<T>(page: page, status: PagedStatus.loadingMore, request: request.next());

  /// Replaces the list (first load or refresh).
  PagedViewState<T> loaded(PagedList<T> value) =>
      PagedViewState<T>(page: value, status: PagedStatus.ready, request: request);

  /// Appends the next page, dropping ids already present — backends paginate
  /// over a moving table and re-send rows, which duplicates keys and crashes a
  /// keyed list.
  PagedViewState<T> appended(PagedList<T> next, {Object Function(T item)? identity}) {
    final merged = page.merge(next);
    final deduped = identity == null
        ? merged
        : PagedList<T>(
            items: merged.items.distinctBy(identity),
            page: merged.page,
            hasMore: merged.hasMore,
            totalItems: merged.totalItems,
          );
    return PagedViewState<T>(page: deduped, status: PagedStatus.ready, request: request);
  }

  /// Keeps whatever is loaded so a load-more error shows as a retry footer
  /// rather than wiping the list.
  PagedViewState<T> failed(Failure value) =>
      PagedViewState<T>(page: page, status: PagedStatus.failed, failure: value, request: request);

  @override
  List<Object?> get props => [page, status, failure, request];

  @override
  bool get stringify => true;
}
