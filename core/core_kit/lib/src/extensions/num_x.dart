import 'package:intl/intl.dart';

extension IntX on int {
  Duration get milliseconds => Duration(milliseconds: this);

  Duration get seconds => Duration(seconds: this);

  Duration get minutes => Duration(minutes: this);

  Duration get hours => Duration(hours: this);

  Duration get days => Duration(days: this);
}

extension NumX on num {
  /// Thousands-separated, no decimals. Locale is explicit for test determinism.
  String toCompactString({String? locale}) => NumberFormat.decimalPattern(locale).format(this);

  String toCurrency({String? locale, String? symbol, int decimalDigits = 0}) =>
      NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: decimalDigits).format(this);

  num clampRange(num min, num max) => this < min ? min : (this > max ? max : this);
}

extension DurationX on Duration {
  /// `01:05:09` / `05:09` — for timers and elapsed-time labels.
  String toClockString() {
    final h = inHours;
    final m = inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$m:$s' : '$m:$s';
  }
}
