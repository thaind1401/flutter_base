import 'package:app/app/bootstrap.dart';
import 'package:app/app/di/injection.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/boot_harness.dart';

// `runDeferredStartup` is where analytics, crash reporting, push registration
// and remote config go, and it had no test — the per-file floor found
// `bootstrap.dart` at 48.8% and this was the reachable part of the gap.
//
// The rest of that gap is `_LateNavigator`'s forwarding methods, and they stay
// uncovered on purpose: nothing reaches them until a mini-app navigates, and
// this base ships none. Writing a test that pokes them through a fake host
// would raise the number and prove nothing about the path a real mini-app
// takes. ADR-0007 has the condition for adding one; the coverage follows it.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(installPlatformMocks);
  tearDown(getIt.reset);

  test('deferred startup completes rather than throwing into the post-frame callback', () async {
    await Bootstrap.run();

    // `main` runs this inside `addPostFrameCallback` with `unawaited`, so an
    // exception escaping it is an uncaught async error on an app the user is
    // already looking at. The try/catch inside is the whole contract, and the
    // first thing anyone adds here is a push registration that fails offline.
    await expectLater(Bootstrap.runDeferredStartup(), completes);
  });

  test('it needs the container, so it cannot be moved ahead of bootstrap', () async {
    // Resolving `AppLogger` is the first thing it does. Calling it before
    // `configureDependencies()` is the ordering mistake a refactor of `main`
    // would make, and it fails loudly rather than logging into the void.
    await expectLater(Bootstrap.runDeferredStartup(), throwsA(anything));
  });
}
