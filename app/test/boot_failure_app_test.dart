import 'package:app/app/error/boot_failure_app.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The screen a user sees when `Bootstrap.run()` throws. What makes it worth a
// test is what it must *not* depend on: it renders after the container failed
// to compose, so anything it resolves from `getIt` is a second crash on top of
// the first one. Nothing here registers a single dependency — that absence is
// the assertion.

void main() {
  testWidgets('renders without a container behind it', (tester) async {
    await tester.pumpWidget(BootFailureApp(onRetry: () async {}));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('The app could not start'), findsOneWidget);
  });

  testWidgets('retry runs a second attempt and shows it is working', (tester) async {
    var attempts = 0;
    // Never completes, so the in-flight state is observable. A retry that
    // resolves instantly would let the button look idle through the whole
    // attempt, and the user taps it again.
    await tester.pumpWidget(
      BootFailureApp(
        onRetry: () {
          attempts++;
          return Future<void>.delayed(const Duration(seconds: 5));
        },
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    expect(attempts, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // A second tap while the first attempt is still running must not start
    // another bootstrap — two concurrent `configureDependencies()` calls over
    // one container is a duplicate-registration throw.
    await tester.tap(find.byType(AppButton), warnIfMissed: false);
    await tester.pump();
    expect(attempts, 1);

    await tester.pump(const Duration(seconds: 5));
    // The attempt failed too — a successful one would have replaced the root
    // widget — so the button is tappable again rather than stuck spinning.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('is localized, not hardcoded English', (tester) async {
    // `Localizations.of<T>` resolves by type and throws when the type is absent,
    // so a delegate this screen's `MaterialApp` forgot is a crash *on the crash
    // screen* — in one language only, with every other test still green.
    //
    // Driven through the platform locale rather than `Localizations.override`,
    // because this widget builds its own `MaterialApp` and an override wrapped
    // around it never reaches the scope that `MaterialApp` creates inside.
    tester.platformDispatcher.localesTestValue = const [Locale('vi')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(BootFailureApp(onRetry: () async {}));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Không thể khởi động ứng dụng'), findsOneWidget);
    // The retry label comes from `core_ui`'s ARB, not the app's — the direction
    // rule 15 allows, and a second package whose delegate has to be present.
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
