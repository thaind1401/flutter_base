import 'package:intl/intl.dart';

extension DateTimeX on DateTime {
  DateTime get startOfDay => DateTime(year, month, day);

  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  DateTime get startOfMonth => DateTime(year, month);

  DateTime get endOfMonth => DateTime(year, month + 1, 0, 23, 59, 59, 999);

  bool isSameDay(DateTime other) => year == other.year && month == other.month && day == other.day;

  bool get isToday => isSameDay(DateTime.now());

  bool get isWeekend => weekday == DateTime.saturday || weekday == DateTime.sunday;

  /// Formats with an explicit pattern. Locale is passed in rather than read
  /// from a global so that formatting is deterministic in tests.
  String format(String pattern, {String? locale}) => DateFormat(pattern, locale).format(this);

  /// Date only, no time zone suffix — what most backends expect for a date
  /// field and what `toIso8601String()` gets wrong by adding the time.
  String toIsoDate() => DateFormat('yyyy-MM-dd').format(this);
}

extension NullableDateTimeX on DateTime? {
  /// Tolerant parse for backend payloads that mix ISO strings, epoch millis and
  /// nulls in the same field.
  static DateTime? tryParseAny(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      if (value.trim().isEmpty) return null;
      final asInt = int.tryParse(value);
      if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
      return DateTime.tryParse(value);
    }
    return null;
  }
}
