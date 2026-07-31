import 'package:core_kit/core_kit.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

/// `Debouncer` owns a `Timer`, and the class comment says why that matters: an
/// undisposed one fires into a closed bloc and throws `Bad state: Cannot emit
/// after close`. That is a crash in production and it depends entirely on
/// timing, so it is exactly the thing to pin with a fake clock rather than with
/// real delays.
///
/// `fake_async` rather than `await Future.delayed`: real sleeps make the suite
/// slow *and* flaky, and they cannot prove that nothing fired — only that
/// nothing had fired yet.
void main() {
  group('Debouncer', () {
    test('runs the action once the quiet window passes', () {
      fakeAsync((async) {
        final debouncer = Debouncer(duration: const Duration(milliseconds: 300));
        var calls = 0;

        debouncer(() => calls++);
        expect(calls, 0, reason: 'the whole point is not to fire immediately');

        async.elapse(const Duration(milliseconds: 300));
        expect(calls, 1);

        debouncer.dispose();
      });
    });

    test('a burst of calls collapses into the last one', () {
      // The search-as-you-type case. Five keystrokes must produce one request,
      // and it must be the one carrying the final query.
      fakeAsync((async) {
        final debouncer = Debouncer(duration: const Duration(milliseconds: 300));
        final seen = <String>[];

        for (final query in ['f', 'fl', 'flu', 'flut', 'flutter']) {
          debouncer(() => seen.add(query));
          async.elapse(const Duration(milliseconds: 50));
        }
        async.elapse(const Duration(milliseconds: 300));

        expect(seen, ['flutter']);

        debouncer.dispose();
      });
    });

    test('isPending reports whether a timer is armed', () {
      fakeAsync((async) {
        final debouncer = Debouncer(duration: const Duration(milliseconds: 100));

        expect(debouncer.isPending, isFalse);
        debouncer(() {});
        expect(debouncer.isPending, isTrue);

        async.elapse(const Duration(milliseconds: 100));
        expect(debouncer.isPending, isFalse, reason: 'a fired timer is no longer pending');

        debouncer.dispose();
      });
    });

    test('cancel drops the pending action without running it', () {
      fakeAsync((async) {
        final debouncer = Debouncer(duration: const Duration(milliseconds: 100));
        var calls = 0;

        debouncer(() => calls++);
        debouncer.cancel();
        async.elapse(const Duration(milliseconds: 500));

        expect(calls, 0);
        expect(debouncer.isPending, isFalse);
      });
    });

    test('flush runs a pending action immediately', () {
      // A "search" button pressed while a keystroke debounce is still in
      // flight: the user asked for it now, so the wait is over.
      fakeAsync((async) {
        final debouncer = Debouncer(duration: const Duration(seconds: 5));
        var calls = 0;

        debouncer(() {});
        debouncer.flush(() => calls++);

        expect(calls, 1);
        expect(debouncer.isPending, isFalse);

        // And the original timer is gone, so nothing fires again later.
        async.elapse(const Duration(seconds: 10));
        expect(calls, 1);
      });
    });

    test('flush does nothing when nothing is pending', () {
      fakeAsync((async) {
        final debouncer = Debouncer();
        var calls = 0;

        debouncer.flush(() => calls++);

        expect(calls, 0, reason: 'flushing an idle debouncer must not invent a call');
      });
    });

    test('dispose stops a pending action from ever firing', () {
      // The documented failure: a timer that outlives its bloc emits into a
      // closed one and throws. Nothing about the widget tree notices, so this
      // is the only place it is caught.
      fakeAsync((async) {
        final debouncer = Debouncer(duration: const Duration(milliseconds: 300));
        var calls = 0;

        debouncer(() => calls++);
        debouncer.dispose();
        async.elapse(const Duration(seconds: 1));

        expect(calls, 0);
      });
    });
  });

  group('Throttler', () {
    test('the first call runs and reports true', () {
      final throttler = Throttler(duration: const Duration(milliseconds: 800));
      var calls = 0;

      expect(throttler(() => calls++), isTrue);
      expect(calls, 1);
    });

    test('a call inside the window is dropped and reports false', () {
      // The double-tap-submit case: the second tap must not reach the network,
      // and the caller needs to know it was dropped so it does not show a
      // spinner for a request that never went out.
      final throttler = Throttler(duration: const Duration(seconds: 10));
      var calls = 0;

      throttler(() => calls++);

      expect(throttler(() => calls++), isFalse);
      expect(calls, 1);
    });

    test('a call after the window runs again', () {
      // `Throttler` reads `DateTime.now()` rather than using a `Timer`, so a
      // fake clock does not reach it — a zero window is the honest way to test
      // the elapsed branch without sleeping.
      final throttler = Throttler(duration: Duration.zero);
      var calls = 0;

      throttler(() => calls++);
      throttler(() => calls++);

      expect(calls, 2);
    });

    test('reset re-arms it immediately', () {
      final throttler = Throttler(duration: const Duration(hours: 1));
      var calls = 0;

      throttler(() => calls++);
      expect(throttler(() => calls++), isFalse);

      throttler.reset();

      expect(throttler(() => calls++), isTrue);
      expect(calls, 2);
    });
  });
}
