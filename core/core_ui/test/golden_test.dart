@Tags(['golden'])
library;

import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/host.dart';

/// Pixel snapshots of the design system, in both themes.
///
/// Every other test in this package asserts *behaviour*: a button disables
/// while loading, a field shows the error it was handed. None of them can fail
/// when a spacing token changes from 12 to 16, a colour loses contrast against
/// its surface, or a dark-theme surface stops lifting — and those are the
/// changes a token file invites. `AppColors`, `AppDimens` and `AppTypography`
/// are one edit away from every screen in the app; these are the only tests
/// that look at the result.
///
/// **Both themes, always.** `AppColors.dark()` is hand-tuned rather than a
/// mechanical inversion — surfaces lift as they approach the user and status
/// colours are lightened to keep contrast. A light-only golden would let all of
/// that rot silently, which is exactly how a dark mode ends up shipped broken.
///
/// Reviewing a diff: `make golden-update` rewrites the PNGs, and the *images*
/// are the review. A regenerated golden that nobody opened is worse than no
/// golden, because it launders the regression into the baseline.
///
/// ## What these do not catch
///
/// **Text renders as boxes.** `flutter test` ships no real font, so every glyph
/// is a placeholder rectangle. That is Flutter's default, not a defect here,
/// and it is worth being precise about what survives it:
///
///   * caught — layout, spacing, alignment, every colour and its contrast
///     against the surface behind it, control heights, border radii, icon
///     sizes, and text *metrics* (a font-size or line-height token change moves
///     the boxes);
///   * not caught — font family, weight, and letterforms. A change to
///     `AppTypography.fontFamily` or a weight produces an identical image.
///
/// Closing that gap means committing a font binary and loading it with
/// `FontLoader`, which is a real option once this project picks a brand font —
/// it is not done here because the base ships no font of its own and a golden
/// baked against whatever Roboto the runner had is worse than an honest box.
///
/// Tagged `golden` so `make test` can skip them on a machine whose rendering
/// differs from CI's. `make golden` runs exactly these.
void main() {
  /// Each case is rendered twice — once per theme — from one declaration, so a
  /// widget cannot be added to the light set and forgotten in the dark one.
  Future<void> goldenPair(WidgetTester tester, String name, Widget child, {Size size = const Size(400, 220)}) async {
    for (final (label, theme) in [('light', AppTheme.light()), ('dark', AppTheme.dark())]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        testHost(
          // A surface behind the widget, or a transparent PNG hides every
          // contrast problem the dark theme could have.
          ColoredBox(
            color: theme.extension<AppColors>()!.background,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: child),
            ),
          ),
          theme: theme,
        ),
      );
      // Not `pumpAndSettle`: anything containing a `CircularProgressIndicator`
      // never settles — it animates forever, so the call times out rather than
      // returning. A fixed advance is also what a golden actually wants, since
      // it pins the animation to one reproducible phase instead of whatever
      // frame the settle happened to stop on.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.$label.png'));
    }
  }

  group('buttons', () {
    testWidgets('variants', (tester) async {
      await goldenPair(
        tester,
        'button_variants',
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(label: 'Primary', onPressed: () {}),
            const SizedBox(height: 8),
            AppButton.secondary(label: 'Secondary', onPressed: () {}),
            const SizedBox(height: 8),
            AppButton.danger(label: 'Danger', onPressed: () {}),
          ],
        ),
        size: const Size(400, 260),
      );
    });

    testWidgets('states', (tester) async {
      // Disabled and loading side by side on purpose: they are the two states
      // most likely to end up looking identical after a token change, and they
      // mean opposite things to the user.
      await goldenPair(
        tester,
        'button_states',
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(label: 'Enabled', onPressed: () {}),
            const SizedBox(height: 8),
            const AppButton(label: 'Disabled'),
            const SizedBox(height: 8),
            AppButton(label: 'Loading', isLoading: true, onPressed: () {}),
            const SizedBox(height: 8),
            AppButton(label: 'With icon', icon: Icons.check_rounded, onPressed: () {}),
          ],
        ),
        size: const Size(400, 320),
      );
    });
  });

  group('fields', () {
    testWidgets('text field states', (tester) async {
      await goldenPair(
        tester,
        'text_field',
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(label: 'Email', hint: 'you@example.com'),
            SizedBox(height: 12),
            AppTextField(label: 'Password', obscureText: true, helperText: 'At least 8 characters'),
            SizedBox(height: 12),
            AppTextField(label: 'Invalid', errorText: 'Enter a valid email address'),
          ],
        ),
        size: const Size(400, 340),
      );
    });

    testWidgets('switch tile', (tester) async {
      await goldenPair(
        tester,
        'switch_tile',
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSwitchTile(title: 'Notifications', subtitle: 'Email me about activity', value: true, onChanged: (_) {}),
            AppSwitchTile(title: 'Off', value: false, onChanged: (_) {}),
            const AppSwitchTile(title: 'Disabled', value: true, onChanged: null),
          ],
        ),
        size: const Size(400, 240),
      );
    });
  });

  group('state views', () {
    testWidgets('loader', (tester) async {
      await goldenPair(tester, 'loader', const AppLoader(message: 'Saving'), size: const Size(300, 160));
    });

    testWidgets('empty', (tester) async {
      await goldenPair(tester, 'empty_view', const AppEmptyView(), size: const Size(400, 300));
    });

    testWidgets('error with retry', (tester) async {
      // A `NetworkFailure` is retryable, so this covers the retry button too.
      // The icon, the copy and whether the button appears at all are all
      // decided by the failure type — one snapshot pins the whole chain.
      await goldenPair(
        tester,
        'error_view',
        AppErrorView(failure: const NetworkFailure(), onRetry: () {}),
        size: const Size(400, 340),
      );
    });
  });
}
