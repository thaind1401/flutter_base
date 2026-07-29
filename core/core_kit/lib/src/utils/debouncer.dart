import 'dart:async';

/// Delays an action until [duration] has passed without another call.
///
/// Owned by whatever creates it and **must** be disposed — an undisposed timer
/// fires into a closed bloc and throws `Bad state: Cannot emit after close`.
final class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 300)});

  final Duration duration;
  Timer? _timer;

  bool get isPending => _timer?.isActive ?? false;

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Drops a pending action without running it.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Runs a pending action immediately — for a "search" button pressed while a
  /// keystroke debounce is still in flight.
  void flush(void Function() action) {
    if (isPending) {
      cancel();
      action();
    }
  }

  void dispose() => cancel();
}

/// Runs at most once per [duration]; extra calls in the window are dropped.
/// Use for things that must fire immediately but not repeatedly, like a
/// submit button or a pull-to-refresh.
final class Throttler {
  Throttler({this.duration = const Duration(milliseconds: 800)});

  final Duration duration;
  DateTime? _lastRun;

  bool call(void Function() action) {
    final now = DateTime.now();
    if (_lastRun != null && now.difference(_lastRun!) < duration) return false;
    _lastRun = now;
    action();
    return true;
  }

  void reset() => _lastRun = null;
}
