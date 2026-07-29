import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoadingOverlayController', () {
    late LoadingOverlayController controller;

    setUp(() => controller = LoadingOverlayController());
    tearDown(() => controller.dispose());

    test('starts hidden', () {
      expect(controller.state.value.isVisible, isFalse);
      expect(controller.state.value.status, LoadingOverlayStatus.hidden);
    });

    test('show then hide is symmetric', () {
      controller.show('Saving');
      expect(controller.state.value.status, LoadingOverlayStatus.loading);
      expect(controller.state.value.message, 'Saving');

      controller.hide();
      expect(controller.state.value.isVisible, isFalse);
    });

    test('the first of two concurrent operations does not dismiss the overlay', () {
      // The whole reason for the depth counter. Two requests in flight, the
      // fast one returns first — without nesting the user watches the loader
      // vanish while the slow one is still running.
      controller
        ..show()
        ..show()
        ..hide();
      expect(controller.state.value.isVisible, isTrue);

      controller.hide();
      expect(controller.state.value.isVisible, isFalse);
    });

    test('an unbalanced hide cannot drive the depth negative', () {
      // If it could, the next show() would need as many hides as there were
      // stray ones before the overlay came down — a stuck modal barrier, which
      // is exactly the showDialog failure this class exists to avoid.
      controller
        ..hide()
        ..hide()
        ..hide()
        ..show();

      expect(controller.state.value.isVisible, isTrue);
      controller.hide();
      expect(controller.state.value.isVisible, isFalse);
    });

    test('reset dismisses regardless of depth', () {
      controller
        ..show()
        ..show()
        ..show()
        ..reset();
      expect(controller.state.value.isVisible, isFalse);
    });

    testWidgets('a success flash clears itself after its duration', (tester) async {
      controller.showSuccess(message: 'Saved', duration: const Duration(milliseconds: 100));
      expect(controller.state.value.status, LoadingOverlayStatus.success);

      await tester.pump(const Duration(milliseconds: 120));
      expect(controller.state.value.isVisible, isFalse);
    });

    testWidgets('a later show cancels a pending auto-hide', (tester) async {
      // Otherwise the timer from the flash fires mid-operation and takes the
      // new loader down with it.
      controller.showSuccess(duration: const Duration(milliseconds: 100));
      controller.show('next operation');

      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.state.value.status, LoadingOverlayStatus.loading);
      expect(controller.state.value.message, 'next operation');
    });

    test('wrap hides the overlay even when the action throws', () async {
      await expectLater(controller.wrap<void>(() async => throw StateError('boom')), throwsStateError);
      expect(controller.state.value.isVisible, isFalse);
    });

    test('wrap returns the action result', () async {
      expect(await controller.wrap(() async => 42), 42);
      expect(controller.state.value.isVisible, isFalse);
    });
  });

  group('LoadingOverlayHost', () {
    late LoadingOverlayController controller;

    setUp(() => controller = LoadingOverlayController());
    tearDown(() => controller.dispose());

    // MaterialApp's own route machinery mounts a non-absorbing AbsorbPointer,
    // so matching the type alone would pass whether or not the overlay is up.
    // The absorbing flag is the property that decides whether a tap reaches the
    // screen behind, which is the thing under test.
    final blocking = find.byWidgetPredicate(
      (widget) => widget is AbsorbPointer && widget.absorbing,
      description: 'an AbsorbPointer that is actually absorbing',
    );

    Widget host() => MaterialApp(
      theme: AppTheme.light(),
      home: LoadingOverlayHost(
        controller: controller,
        child: const Scaffold(body: Text('screen content')),
      ),
    );

    testWidgets('renders nothing over the child while hidden', (tester) async {
      await tester.pumpWidget(host());

      expect(find.text('screen content'), findsOneWidget);
      expect(blocking, findsNothing);
    });

    testWidgets('blocks input while loading', (tester) async {
      await tester.pumpWidget(host());
      controller.show('Working');
      await tester.pump();

      // A blocking loader that still lets a double tap through is not blocking
      // anything — the duplicate submit is the bug it exists to prevent.
      expect(blocking, findsOneWidget);
      expect(find.text('Working'), findsOneWidget);
    });

    testWidgets('the child stays mounted underneath, keeping its state', (tester) async {
      await tester.pumpWidget(host());
      controller.show();
      await tester.pump();

      expect(find.text('screen content'), findsOneWidget);
    });

    testWidgets('the failure flash shows an error icon', (tester) async {
      await tester.pumpWidget(host());
      controller.showFailure(message: 'Could not save');
      await tester.pump();

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Could not save'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    });
  });
}
