import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/host.dart';

/// Accessibility, asserted rather than assumed.
///
/// This package had zero `Semantics`, zero `semanticLabel` and zero tooltips
/// while `AppColors` claimed an accessibility pass was "a change to this one
/// file". Colour was never the hard part. The gaps were structural: controls
/// with no name, a spinner that announced nothing, and one setting exposed as
/// two separate nodes.
///
/// The guarantees below are the ones that break silently — nothing renders
/// differently when a semantic label disappears, so only a test notices.
///
/// `isSemantics` rather than `matchesSemantics` throughout: the strict
/// matcher pins every flag on the node, so an unrelated Flutter upgrade that
/// adds one fails the suite for no reason. These assert what this package
/// promises and stay quiet about the rest.
void main() {
  group('AppButton', () {
    // The node is read off `FilledButton`, not off `AppButton`. `AppButton` is a
    // `StatelessWidget` with no render object of its own, so `getSemantics`
    // walks past it to the nearest ancestor that has one — the root — and every
    // assertion below would be made against the whole screen.
    final buttonNode = find.byType(FilledButton);

    testWidgets('an idle button is announced by its label', (tester) async {
      await tester.pumpWidget(testHost(AppButton(label: 'Save', onPressed: () {})));

      expect(
        tester.getSemantics(buttonNode),
        isSemantics(label: 'Save', isButton: true, isEnabled: true, hasTapAction: true),
      );
    });

    testWidgets('a loading button keeps a name instead of going anonymous', (tester) async {
      // The regression: `isLoading` swaps the `Text` for a spinner, so the only
      // thing naming the button is gone. It announced as "button, dimmed" —
      // which tells a screen-reader user the control is unavailable, at the one
      // moment they need to know their tap was accepted and is running.
      await tester.pumpWidget(testHost(AppButton(label: 'Save', isLoading: true, onPressed: () {})));

      expect(tester.getSemantics(buttonNode), isSemantics(label: 'Save, busy'));
      expect(find.text('Save'), findsNothing, reason: 'the visible label really is gone; only semantics carry it');
    });

    testWidgets('a disabled button is not announced as busy', (tester) async {
      await tester.pumpWidget(testHost(const AppButton(label: 'Save')));

      expect(tester.getSemantics(buttonNode), isSemantics(label: 'Save', isEnabled: false));
    });
  });

  group('AppTextField', () {
    testWidgets('the reveal toggle has a name that tracks its state', (tester) async {
      // An `IconButton` with no tooltip announces as "button" and nothing else.
      // There is no visible text to infer it from — the icon is all there is.
      await tester.pumpWidget(testHost(const AppTextField(label: 'Password', obscureText: true)));

      expect(find.byTooltip('Show password'), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // The name must follow the state, or it tells the user the opposite of
      // what the control will do.
      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets('the label and the field are one node, not two', (tester) async {
      // As siblings they were read as loose text followed by an unnamed edit
      // field. `MergeSemantics` makes them the single control a sighted user
      // already perceives.
      await tester.pumpWidget(testHost(const AppTextField(label: 'Email')));

      expect(find.byType(MergeSemantics), findsOneWidget);
      expect(tester.getSemantics(find.byType(MergeSemantics)), isSemantics(label: 'Email', isTextField: true));
    });

    testWidgets('a field with no label is left alone', (tester) async {
      await tester.pumpWidget(testHost(const AppTextField(hint: 'Search')));

      expect(find.byType(MergeSemantics), findsNothing);
    });
  });

  group('AppSwitchTile', () {
    testWidgets('the row is one switch, not a region plus a switch', (tester) async {
      await tester.pumpWidget(
        testHost(AppSwitchTile(title: 'Notifications', subtitle: 'Email me', value: true, onChanged: (_) {})),
      );

      expect(
        tester.getSemantics(find.byType(AppSwitchTile)),
        isSemantics(label: 'Notifications. Email me', isToggled: true, isEnabled: true, hasTapAction: true),
      );
    });

    testWidgets('a disabled tile says so', (tester) async {
      await tester.pumpWidget(testHost(const AppSwitchTile(title: 'Notifications', value: false, onChanged: null)));

      expect(
        tester.getSemantics(find.byType(AppSwitchTile)),
        isSemantics(label: 'Notifications', isToggled: false, isEnabled: false),
      );
    });
  });

  group('state views', () {
    testWidgets('a loader announces itself instead of rendering in silence', (tester) async {
      // A bare `CircularProgressIndicator` contributes no semantics at all, so
      // the screen reads as an empty, broken page while it loads.
      await tester.pumpWidget(testHost(const AppLoader()));

      expect(tester.getSemantics(find.byType(AppLoader)), isSemantics(label: 'Loading…', isLiveRegion: true));
    });

    testWidgets('a loader message is announced once, not twice', (tester) async {
      await tester.pumpWidget(testHost(const AppLoader(message: 'Saving')));

      expect(tester.getSemantics(find.byType(AppLoader)), isSemantics(label: 'Saving'));
    });

    testWidgets('the error title is a heading so it can be jumped to', (tester) async {
      await tester.pumpWidget(testHost(const AppErrorView(failure: NetworkFailure())));

      expect(tester.getSemantics(find.text('No connection')), isSemantics(label: 'No connection', isHeader: true));
    });

    testWidgets('the empty title is a heading too', (tester) async {
      await tester.pumpWidget(testHost(const AppEmptyView()));

      expect(
        tester.getSemantics(find.text('Nothing here yet')),
        isSemantics(label: 'Nothing here yet', isHeader: true),
      );
    });
  });

  group('platform guidelines', () {
    // Flutter ships these as first-class matchers, and they check the things
    // that are tedious to eyeball: 48x48 tap targets, text contrast against its
    // background, and every tappable control having a name.
    Widget form({bool withError = false}) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const AppTextField(label: 'Email', hint: 'you@example.com'),
          const SizedBox(height: 16),
          const AppTextField(label: 'Password', obscureText: true),
          const SizedBox(height: 16),
          AppSwitchTile(title: 'Remember me', value: true, onChanged: (_) {}),
          const SizedBox(height: 16),
          AppButton(label: 'Sign in', onPressed: () {}),
          if (withError) ...[const SizedBox(height: 16), const AppErrorView(failure: NetworkFailure())],
        ],
      ),
    );

    testWidgets('a form meets the tap-target, contrast and naming guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(testHost(form()));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    });

    testWidgets('the same form passes in the dark theme', (tester) async {
      // Contrast is the one guideline a theme change can break without touching
      // a single widget — `AppColors.dark()` is hand-tuned rather than an
      // inversion, so it is checked rather than assumed.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(testHost(form(withError: true), theme: AppTheme.dark()));

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      handle.dispose();
    });
  });
}
