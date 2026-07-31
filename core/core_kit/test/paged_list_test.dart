import 'package:core_kit/core_kit.dart';
import 'package:test/test.dart';

/// `PagedList.merge` exists so the append rule lives in one place instead of
/// being re-derived on every list screen. That makes it the single point where
/// a paging bug becomes an app-wide paging bug: taking `hasMore` from the wrong
/// side strands the user at page two forever, and taking `page` from the wrong
/// side makes the next request re-fetch what is already on screen.
void main() {
  group('PageRequest', () {
    test('defaults to the first page of twenty', () {
      const request = PageRequest();

      expect(request.page, 1);
      expect(request.size, 20);
      expect(request.isFirstPage, isTrue);
    });

    test('next advances one page and keeps the rest of the query', () {
      // The filter and the sort must survive paging, or page two of a search is
      // page two of everything.
      const request = PageRequest(page: 2, size: 50, query: 'flutter', sort: 'name,asc');

      final next = request.next();

      expect(next.page, 3);
      expect(next.size, 50);
      expect(next.query, 'flutter');
      expect(next.sort, 'name,asc');
      expect(next.isFirstPage, isFalse);
    });

    test('first resets the page and keeps the query', () {
      // What pull-to-refresh sends: same filters, back to the top.
      const request = PageRequest(page: 7, query: 'flutter');

      final first = request.first();

      expect(first.page, 1);
      expect(first.query, 'flutter');
      expect(first.isFirstPage, isTrue);
    });

    test('isFirstPage tolerates a zero-based backend leaking through', () {
      expect(const PageRequest(page: 0).isFirstPage, isTrue);
    });

    test('value equality covers every field', () {
      const a = PageRequest(page: 2, size: 20, query: 'q', sort: 's');

      expect(a, const PageRequest(page: 2, size: 20, query: 'q', sort: 's'));
      expect(a, isNot(const PageRequest(page: 3, size: 20, query: 'q', sort: 's')));
      expect(a, isNot(const PageRequest(page: 2, size: 10, query: 'q', sort: 's')));
      expect(a, isNot(const PageRequest(page: 2, size: 20, query: 'other', sort: 's')));
      expect(a, isNot(const PageRequest(page: 2, size: 20, query: 'q', sort: 'other')));
    });
  });

  group('PagedList', () {
    test('the empty page is empty and claims nothing more', () {
      const page = PagedList<String>.empty();

      expect(page.items, isEmpty);
      expect(page.isEmpty, isTrue);
      expect(page.page, 1);
      expect(page.hasMore, isFalse);
      expect(page.totalItems, 0);
    });

    test('merge appends and adopts the incoming cursor', () {
      const first = PagedList<String>(items: ['a', 'b'], page: 1, hasMore: true, totalItems: 4);
      const second = PagedList<String>(items: ['c', 'd'], page: 2, hasMore: false, totalItems: 4);

      final merged = first.merge(second);

      expect(merged.items, ['a', 'b', 'c', 'd']);
      // Both come from the *incoming* page. Keeping the old `page` makes the
      // next request re-fetch what is already on screen; keeping the old
      // `hasMore` leaves an infinite scroll asking for a page that is not there.
      expect(merged.page, 2);
      expect(merged.hasMore, isFalse);
      expect(merged.totalItems, 4);
    });

    test('merging an empty last page ends the list without losing items', () {
      // The common tail case: a backend that answers the page after the last
      // one with an empty array rather than a 404.
      const loaded = PagedList<String>(items: ['a'], page: 1, hasMore: true);

      final merged = loaded.merge(const PagedList<String>(items: [], page: 2, hasMore: false));

      expect(merged.items, ['a']);
      expect(merged.hasMore, isFalse);
    });

    test('merge does not mutate either operand', () {
      const first = PagedList<String>(items: ['a'], page: 1, hasMore: true);
      const second = PagedList<String>(items: ['b'], page: 2, hasMore: false);

      first.merge(second);

      expect(first.items, ['a']);
      expect(second.items, ['b']);
    });

    test('map transforms items and carries the cursor across', () {
      // Used at the data boundary to turn DTOs into entities; dropping the
      // cursor there would silently end pagination at page one.
      const dtos = PagedList<int>(items: [1, 2, 3], page: 2, hasMore: true, totalItems: 9);

      final entities = dtos.map((item) => 'item-$item');

      expect(entities.items, ['item-1', 'item-2', 'item-3']);
      expect(entities.page, 2);
      expect(entities.hasMore, isTrue);
      expect(entities.totalItems, 9);
    });

    test('value equality covers every field', () {
      const a = PagedList<String>(items: ['a'], page: 1, hasMore: true, totalItems: 2);

      expect(a, const PagedList<String>(items: ['a'], page: 1, hasMore: true, totalItems: 2));
      expect(a, isNot(const PagedList<String>(items: ['b'], page: 1, hasMore: true, totalItems: 2)));
      expect(a, isNot(const PagedList<String>(items: ['a'], page: 2, hasMore: true, totalItems: 2)));
      expect(a, isNot(const PagedList<String>(items: ['a'], page: 1, hasMore: false, totalItems: 2)));
      expect(a, isNot(const PagedList<String>(items: ['a'], page: 1, hasMore: true, totalItems: 3)));
    });
  });
}
