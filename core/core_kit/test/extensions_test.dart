import 'package:core_kit/core_kit.dart';
import 'package:test/test.dart';

void main() {
  group('StringX', () {
    test('treats whitespace-only as blank', () {
      expect('   '.isBlank, isTrue);
      expect('  a '.isNotBlank, isTrue);
      expect('   '.orNull, isNull);
      expect(' a '.orNull, ' a ');
    });

    test('collapses runs of whitespace', () {
      // Pasted values and typed search terms arrive with stray tabs.
      expect('  hello \t  world  '.normalizedSpaces, 'hello world');
    });

    test('builds avatar initials from the first and last word', () {
      expect('Nguyen Van A'.initials, 'NA');
      expect('Madonna'.initials, 'M');
      expect(''.initials, '');
      expect('   '.initials, '');
    });

    test('truncates only when longer than the limit', () {
      expect('short'.truncate(10), 'short');
      expect('a very long title'.truncate(6), 'a very…');
    });

    test('nullable helpers', () {
      const String? nothing = null;
      expect(nothing.isNullOrBlank, isTrue);
      expect('  '.isNullOrBlank, isTrue);
      expect('x'.isNotNullOrBlank, isTrue);
      expect(nothing.orEmpty(), '');
    });
  });

  group('IterableX', () {
    const items = [1, 2, 3, 2, 1];

    test('firstWhereOrNull returns null instead of throwing', () {
      expect(items.firstWhereOrNull((e) => e > 2), 3);
      expect(items.firstWhereOrNull((e) => e > 99), isNull);
    });

    test('distinctBy keeps the first occurrence', () {
      // Backends paginating over a moving table re-send rows; a duplicate key
      // crashes a keyed list.
      expect(items.distinctBy((e) => e), [1, 2, 3]);
    });

    test('groupBy buckets by key', () {
      expect(items.groupBy((e) => e.isEven), {
        false: [1, 3, 1],
        true: [2, 2],
      });
    });

    test('indexed pairs each element with its position', () {
      expect(['a', 'b'].indexed.map((e) => '${e.index}${e.value}'), ['0a', '1b']);
    });

    test('nullable helpers', () {
      const List<int>? nothing = null;
      expect(nothing.isNullOrEmpty, isTrue);
      expect(<int>[].isNullOrEmpty, isTrue);
      expect(nothing.orEmpty(), isEmpty);
    });
  });

  group('DateTimeX', () {
    final moment = DateTime(2026, 3, 15, 14, 30);

    test('day and month boundaries', () {
      expect(moment.startOfDay, DateTime(2026, 3, 15));
      expect(moment.endOfDay, DateTime(2026, 3, 15, 23, 59, 59, 999));
      expect(moment.startOfMonth, DateTime(2026, 3));
      expect(moment.endOfMonth.day, 31);
    });

    test('isSameDay ignores the time', () {
      expect(moment.isSameDay(DateTime(2026, 3, 15, 1)), isTrue);
      expect(moment.isSameDay(DateTime(2026, 3, 16)), isFalse);
    });

    test('toIsoDate omits the time a backend date field would reject', () {
      expect(moment.toIsoDate(), '2026-03-15');
    });

    test('tryParseAny accepts the shapes backends actually send', () {
      expect(NullableDateTimeX.tryParseAny(null), isNull);
      expect(NullableDateTimeX.tryParseAny(''), isNull);
      expect(NullableDateTimeX.tryParseAny('nonsense'), isNull);
      expect(NullableDateTimeX.tryParseAny('2026-03-15T00:00:00Z')?.year, 2026);
      expect(NullableDateTimeX.tryParseAny(1773532800000), isA<DateTime>());
      expect(NullableDateTimeX.tryParseAny(moment), moment);
    });
  });

  group('DurationX', () {
    test('clock formatting drops the hour when it is zero', () {
      expect(const Duration(minutes: 5, seconds: 9).toClockString(), '05:09');
      expect(const Duration(hours: 1, minutes: 5, seconds: 9).toClockString(), '01:05:09');
    });
  });

  group('IntX', () {
    test('reads as durations', () {
      expect(5.seconds, const Duration(seconds: 5));
      expect(2.hours, const Duration(hours: 2));
    });
  });

  group('PagedList', () {
    PagedList<int> page(List<int> items, {int page = 1, bool hasMore = true}) =>
        PagedList<int>(items: items, page: page, hasMore: hasMore, totalItems: 10);

    test('empty is empty', () {
      expect(const PagedList<int>.empty().isEmpty, isTrue);
      expect(const PagedList<int>.empty().hasMore, isFalse);
    });

    test('merge appends and adopts the newer cursor', () {
      final merged = page([1, 2]).merge(page([3, 4], page: 2, hasMore: false));
      expect(merged.items, [1, 2, 3, 4]);
      expect(merged.page, 2);
      expect(merged.hasMore, isFalse);
    });

    test('map transforms items and keeps the cursor', () {
      final mapped = page([1, 2]).map((e) => 'n$e');
      expect(mapped.items, ['n1', 'n2']);
      expect(mapped.hasMore, isTrue);
    });
  });

  group('PageRequest', () {
    test('next advances and first resets', () {
      const request = PageRequest(query: 'abc');
      expect(request.isFirstPage, isTrue);
      expect(request.next().page, 2);
      // The query survives paging — losing it silently returns the wrong rows.
      expect(request.next().query, 'abc');
      expect(request.next().next().first().page, 1);
    });
  });
}
