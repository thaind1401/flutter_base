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
      expect(5.milliseconds, const Duration(milliseconds: 5));
      expect(5.seconds, const Duration(seconds: 5));
      expect(3.minutes, const Duration(minutes: 3));
      expect(2.hours, const Duration(hours: 2));
      expect(7.days, const Duration(days: 7));
    });
  });

  group('NumX', () {
    // The locale is passed explicitly everywhere here. `NumberFormat` falls
    // back to the ambient default otherwise, which differs between a developer
    // machine and CI and turns a formatting test into a coin flip.
    test('compact formatting groups thousands', () {
      expect(1234567.toCompactString(locale: 'en_US'), '1,234,567');
      expect(999.toCompactString(locale: 'en_US'), '999');
      expect(0.toCompactString(locale: 'en_US'), '0');
    });

    test('compact formatting follows the locale separator', () {
      // vi_VN groups with a dot. The app ships `vi`, so this is a real output,
      // not a hypothetical one.
      expect(1234567.toCompactString(locale: 'vi_VN'), '1.234.567');
    });

    test('currency defaults to whole units', () {
      // `decimalDigits: 0` by default because the app's primary currency has no
      // minor unit; asking for cents is opt-in.
      // vi_VN puts the symbol after the amount, en_US before it. Pinning both
      // placements is the point: hardcoding one in a widget is the bug this
      // extension exists to prevent.
      //
      // Asserted in two halves rather than as one literal because ICU separates
      // the amount from the symbol with a no-break space (U+00A0). Pasting that
      // invisible character into the source makes the expectation unreadable
      // and the next edit unreproducible.
      final dong = 50000.toCurrency(locale: 'vi_VN', symbol: '₫');
      expect(dong, startsWith('50.000'));
      expect(dong, endsWith('₫'));
      expect(1234.5.toCurrency(locale: 'en_US', symbol: r'$', decimalDigits: 2), r'$1,234.50');
    });

    test('clampRange bounds on both sides and passes the middle through', () {
      expect(5.clampRange(0, 10), 5);
      expect((-3).clampRange(0, 10), 0);
      expect(42.clampRange(0, 10), 10);
      // The boundaries themselves are inside the range, not clamped away.
      expect(0.clampRange(0, 10), 0);
      expect(10.clampRange(0, 10), 10);
      expect(2.5.clampRange(0, 1), 1);
    });
  });

  // `PagedList` and `PageRequest` moved to paged_list_test.dart — they are
  // pagination, not extensions, and they now carry the merge/cursor cases that do
  // not fit in a file about `String`, `DateTime` and `num`.
}
