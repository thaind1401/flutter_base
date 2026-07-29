import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// What a list screen asks the data layer for.
@immutable
final class PageRequest extends Equatable {
  const PageRequest({this.page = 1, this.size = 20, this.query, this.sort});

  /// 1-based, matching the common Spring/Laravel convention. If a backend is
  /// 0-based, convert in its data source — not in the presentation layer.
  final int page;
  final int size;
  final String? query;
  final String? sort;

  bool get isFirstPage => page <= 1;

  PageRequest next() => copyWith(page: page + 1);

  PageRequest first() => copyWith(page: 1);

  PageRequest copyWith({int? page, int? size, String? query, String? sort}) => PageRequest(
    page: page ?? this.page,
    size: size ?? this.size,
    query: query ?? this.query,
    sort: sort ?? this.sort,
  );

  @override
  List<Object?> get props => [page, size, query, sort];
}

/// One page of results plus the cursor state a list screen needs to decide
/// whether to keep loading.
@immutable
final class PagedList<T> extends Equatable {
  const PagedList({required this.items, required this.page, required this.hasMore, this.totalItems});

  const PagedList.empty() : items = const [], page = 1, hasMore = false, totalItems = 0;

  final List<T> items;
  final int page;
  final bool hasMore;
  final int? totalItems;

  bool get isEmpty => items.isEmpty;

  /// Appends [next] onto this page. The list bloc uses this so the merge rule
  /// lives in one place instead of being re-derived per screen.
  PagedList<T> merge(PagedList<T> next) => PagedList<T>(
    items: [...items, ...next.items],
    page: next.page,
    hasMore: next.hasMore,
    totalItems: next.totalItems,
  );

  PagedList<R> map<R>(R Function(T item) transform) =>
      PagedList<R>(items: items.map(transform).toList(), page: page, hasMore: hasMore, totalItems: totalItems);

  @override
  List<Object?> get props => [items, page, hasMore, totalItems];
}
