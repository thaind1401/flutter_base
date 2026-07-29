import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Item = ({int id, String label});

PagedList<_Item> _page(List<int> ids, {int page = 1, bool hasMore = true}) =>
    PagedList<_Item>(items: [for (final id in ids) (id: id, label: 'item-$id')], page: page, hasMore: hasMore);

void main() {
  group('PagedViewState', () {
    test('starts idle and empty', () {
      const state = PagedViewState<_Item>();
      expect(state.isEmpty, isTrue);
      expect(state.canLoadMore, isFalse);
      expect(state.status, PagedStatus.idle);
    });

    test('refreshing keeps the loaded items on screen', () {
      // Clearing them would drop the user's scroll position mid pull-to-refresh.
      final loaded = const PagedViewState<_Item>().loaded(_page([1, 2, 3]));
      final refreshing = loaded.refreshing();
      expect(refreshing.items, hasLength(3));
      expect(refreshing.isRefreshing, isTrue);
      expect(refreshing.request.page, 1);
    });

    test('loadingMore advances the page number exactly once', () {
      final loaded = const PagedViewState<_Item>().loaded(_page([1, 2]));
      final loadingMore = loaded.loadingMore();
      expect(loadingMore.request.page, 2);
      expect(loadingMore.items, hasLength(2));
    });

    test('appended concatenates the next page', () {
      final state = const PagedViewState<_Item>().loaded(_page([1, 2])).loadingMore();
      final next = state.appended(_page([3, 4], page: 2));
      expect(next.items.map((i) => i.id), [1, 2, 3, 4]);
      expect(next.status, PagedStatus.ready);
    });

    test('appended with an identity drops rows the backend re-sent', () {
      // Paging over a table that is still being written to re-sends rows; a
      // duplicate key throws in a keyed list.
      final state = const PagedViewState<_Item>().loaded(_page([1, 2]));
      final next = state.appended(_page([2, 3], page: 2), identity: (item) => item.id);
      expect(next.items.map((i) => i.id), [1, 2, 3]);
    });

    test('canLoadMore is false while a load is in flight', () {
      final ready = const PagedViewState<_Item>().loaded(_page([1], hasMore: true));
      expect(ready.canLoadMore, isTrue);
      expect(ready.loadingMore().canLoadMore, isFalse);
      expect(ready.refreshing().canLoadMore, isFalse);
    });

    test('canLoadMore is false on the last page', () {
      final last = const PagedViewState<_Item>().loaded(_page([1], hasMore: false));
      expect(last.canLoadMore, isFalse);
    });

    test('failed keeps loaded items so the error renders as a footer', () {
      final state = const PagedViewState<_Item>().loaded(_page([1, 2])).loadingMore().failed(const NetworkFailure());
      expect(state.items, hasLength(2));
      expect(state.failure, isA<NetworkFailure>());
      expect(state.canLoadMore, isFalse);
    });

    test('a first-page failure is distinguishable by the list being empty', () {
      final state = const PagedViewState<_Item>().loadingFirstPage().failed(const ServerFailure());
      expect(state.isEmpty, isTrue);
      expect(state.failure, isA<ServerFailure>());
    });
  });

  group('ViewState', () {
    test('dataOrNull exposes stale data behind a failure', () {
      const failed = ViewFailed<int>(NetworkFailure(), lastData: 7);
      expect(failed.dataOrNull, 7);
      expect(failed.hasData, isTrue);
    });

    test('idle and loading are different states', () {
      expect(const ViewIdle<int>(), isNot(const ViewLoading<int>()));
      expect(const ViewLoading<int>().isLoading, isTrue);
    });

    test('refreshing is tracked on ViewData rather than replacing it', () {
      const data = ViewData<int>(1);
      expect(data.isRefreshing, isFalse);
      expect(data.refreshing().isRefreshing, isTrue);
      expect(data.refreshing().data, 1);
      expect(data.refreshing().settled().isRefreshing, isFalse);
    });

    test('equality is by value so bloc does not emit duplicates', () {
      expect(const ViewData<int>(1), const ViewData<int>(1));
      expect(const ViewData<int>(1), isNot(const ViewData<int>(2)));
    });
  });
}
