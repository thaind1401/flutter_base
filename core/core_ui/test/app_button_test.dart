import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reason every button routes through this widget is the double-submit bug:
/// tap, wait, tap again, two leave requests. `isLoading` disabling the button is
/// the guarantee, so it is what gets tested hardest here.

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  );

  testWidgets('renders its label and fires onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(AppButton(label: 'Save', onPressed: () => taps++)));

    expect(find.text('Save'), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    expect(taps, 1);
  });

  group('loading disables the button', () {
    testWidgets('a loading button swaps its label for a spinner', (tester) async {
      await tester.pumpWidget(host(AppButton(label: 'Save', isLoading: true, onPressed: () {})));

      expect(find.text('Save'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('a loading button ignores taps even with a callback', (tester) async {
      // This is the whole point of the widget. If it regresses, every submit
      // button in the app can be double-tapped into two requests.
      var taps = 0;
      await tester.pumpWidget(host(AppButton(label: 'Save', isLoading: true, onPressed: () => taps++)));

      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      await tester.pump();

      expect(taps, 0);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });
  });

  testWidgets('a null onPressed disables the button', (tester) async {
    await tester.pumpWidget(host(const AppButton(label: 'Save')));

    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });

  group('variants', () {
    testWidgets('each variant builds and keeps its label', (tester) async {
      for (final variant in AppButtonVariant.values) {
        await tester.pumpWidget(host(AppButton(label: variant.name, variant: variant, onPressed: () {})));
        await tester.pump();

        expect(find.text(variant.name), findsOneWidget, reason: '${variant.name} must render');
      }
    });

    testWidgets('the named constructors select the right variant', (tester) async {
      // Intent-named constructors are the documented reason the enum exists;
      // if they drift, "the destructive button" quietly becomes the primary one.
      await tester.pumpWidget(host(AppButton.danger(label: 'Delete', onPressed: () {})));
      expect(tester.widget<AppButton>(find.byType(AppButton)).variant, AppButtonVariant.danger);

      await tester.pumpWidget(host(AppButton.secondary(label: 'Cancel', onPressed: () {})));
      expect(tester.widget<AppButton>(find.byType(AppButton)).variant, AppButtonVariant.secondary);
    });

    testWidgets('danger and primary do not share a background', (tester) async {
      Color backgroundOf(WidgetTester tester) {
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        return button.style!.backgroundColor!.resolve({})!;
      }

      await tester.pumpWidget(host(AppButton(label: 'x', onPressed: () {})));
      final primary = backgroundOf(tester);

      await tester.pumpWidget(host(AppButton.danger(label: 'x', onPressed: () {})));

      expect(backgroundOf(tester), isNot(primary));
    });
  });

  group('sizes', () {
    /// The painted surface, not the widget box. Material pads the box out to
    /// the 48px minimum tap target, so measuring `FilledButton` reports 48 for
    /// a small button and makes it look identical to a medium one.
    double paintedHeight(WidgetTester tester) =>
        tester.getSize(find.descendant(of: find.byType(FilledButton), matching: find.byType(Material)).first).height;

    testWidgets('each size paints at its own height', (tester) async {
      final heights = <AppButtonSize, double>{};
      for (final size in AppButtonSize.values) {
        await tester.pumpWidget(host(AppButton(label: 'x', size: size, onPressed: () {})));
        await tester.pump();
        heights[size] = paintedHeight(tester);
      }

      expect(heights.values.toSet(), hasLength(AppButtonSize.values.length));
      expect(heights[AppButtonSize.small]!, lessThan(heights[AppButtonSize.medium]!));
      expect(heights[AppButtonSize.medium]!, lessThan(heights[AppButtonSize.large]!));
    });

    testWidgets('a small button still offers a full-size tap target', (tester) async {
      // 36px painted, 48px touchable. Shrinking the visual button must not
      // shrink the thing a finger has to hit.
      await tester.pumpWidget(host(AppButton(label: 'x', size: AppButtonSize.small, onPressed: () {})));

      expect(paintedHeight(tester), lessThan(48));
      expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
    });
  });

  group('layout', () {
    testWidgets('expanded fills the available width', (tester) async {
      await tester.pumpWidget(host(AppButton(label: 'Wide', onPressed: () {})));

      final width = tester.getSize(find.byType(FilledButton)).width;
      expect(width, tester.getSize(find.byType(Scaffold)).width);
    });

    testWidgets('not expanded shrinks to its content', (tester) async {
      await tester.pumpWidget(
        host(
          Center(
            child: AppButton(label: 'Narrow', expanded: false, onPressed: () {}),
          ),
        ),
      );

      final width = tester.getSize(find.byType(FilledButton)).width;
      expect(width, lessThan(tester.getSize(find.byType(Scaffold)).width));
    });

    testWidgets('an icon renders alongside the label', (tester) async {
      await tester.pumpWidget(host(AppButton(label: 'Add', icon: Icons.add, onPressed: () {})));

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('a long label ellipsises instead of overflowing', (tester) async {
      await tester.pumpWidget(host(AppButton(label: 'A label far too long to fit' * 4, onPressed: () {})));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.byType(Text)).overflow, TextOverflow.ellipsis);
    });
  });
}
