import 'dart:math' as math;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme carries the token extensions', () {
    // Rule 6 of the architecture — "no literals in widgets, use context.colors"
    // — rests entirely on these three extensions being attached. Drop one and
    // nothing breaks loudly: `ThemeContextX` falls back to the light tokens, so
    // the dark theme quietly renders light text on light surfaces.
    for (final entry in {'light': AppTheme.light(), 'dark': AppTheme.dark()}.entries) {
      test('${entry.key} has colors, typography and dimens attached', () {
        expect(entry.value.extension<AppColors>(), isNotNull, reason: 'context.colors would fall back to light');
        expect(entry.value.extension<AppTypography>(), isNotNull);
        expect(entry.value.extension<AppDimens>(), isNotNull);
      });
    }

    testWidgets('context.colors resolves the dark tokens under the dark theme', (tester) async {
      late AppColors resolved;
      late bool isDark;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) {
              resolved = context.colors;
              isDark = context.isDarkMode;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Compared against the light value rather than asserted equal to a
      // literal: the point is that the fallback did not silently win.
      expect(resolved.background, isNot(AppColors.light().background));
      expect(resolved.background, AppColors.dark().background);
      expect(isDark, isTrue);
    });

    testWidgets('a widget outside any app theme still gets usable tokens', (tester) async {
      // The `?? AppColors.light()` fallback exists so a widget pumped bare in a
      // test or a preview renders instead of throwing on a null extension.
      late AppColors resolved;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              resolved = context.colors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved.background, AppColors.light().background);
    });
  });

  group('token contrast', () {
    // Checked here rather than left to a designer's eye, because a rebrand
    // edits two constructors and the failure mode is unreadable text on a
    // subset of screens nobody re-opens.
    for (final entry in {'light': AppColors.light(), 'dark': AppColors.dark()}.entries) {
      final name = entry.key;
      final colors = entry.value;

      test('$name primary text meets WCAG AA on background and surface', () {
        expect(_contrast(colors.textPrimary, colors.background), greaterThanOrEqualTo(4.5));
        expect(_contrast(colors.textPrimary, colors.surface), greaterThanOrEqualTo(4.5));
      });

      test('$name secondary text meets WCAG AA large on surface', () {
        // Secondary text is captions and labels — 3:1 is the large-text bar and
        // the realistic one for a muted colour.
        expect(_contrast(colors.textSecondary, colors.surface), greaterThanOrEqualTo(3));
      });

      test('$name button and status foregrounds are readable on their fills', () {
        // 3:1 is the large-text bar, and it is the right one *here*: these fills
        // carry button labels and banner text, which are bold or large. The bar
        // being deliberate is what makes the next test necessary.
        expect(_contrast(colors.onBrand, colors.brand), greaterThanOrEqualTo(3));
        expect(_contrast(colors.onStatus, colors.danger), greaterThanOrEqualTo(3));
        expect(_contrast(colors.onStatus, colors.success), greaterThanOrEqualTo(3));
        // `info` was missing from this list entirely, which is how it ended up
        // as a `SegmentedButton` fill at 4.10:1 with nothing objecting.
        expect(_contrast(colors.onStatus, colors.info), greaterThanOrEqualTo(3));
      });

      test('$name container fills carry ordinary text at full AA', () {
        // The pairing above is only safe for large or bold text. Material's
        // *container* roles are different: they back ordinary interface text —
        // a selected segment, a chip, an assist button — at regular weight and
        // size, so they owe the full 4.5:1.
        //
        // The base failed this before it existed. `AppTheme` left
        // `secondaryContainer` unspecified, Material fell back to `secondary`
        // (a status colour), and the settings theme picker put white 14pt text
        // on it. The token file looked fine; the screen did not.
        expect(_contrast(colors.textPrimary, colors.brandSubtle), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('AppColors', () {
    test('copyWith replaces only what it is given', () {
      final light = AppColors.light();
      final changed = light.copyWith(brand: const Color(0xFF00FF00));

      expect(changed.brand, const Color(0xFF00FF00));
      expect(changed.onBrand, light.onBrand);
      expect(changed.background, light.background);
      expect(changed.danger, light.danger);
      expect(changed.skeleton, light.skeleton);
    });

    test('lerp lands exactly on each end', () {
      final light = AppColors.light();
      final dark = AppColors.dark();

      // Theme animations run through lerp. A field missed there stays frozen at
      // the old value mid-transition, which reads as a flicker.
      expect(light.lerp(dark, 0).background, light.background);
      expect(light.lerp(dark, 1).background, dark.background);
      expect(light.lerp(dark, 1).skeleton, dark.skeleton);
    });

    test('lerp against a foreign extension returns this rather than throwing', () {
      final light = AppColors.light();
      expect(light.lerp(null, 0.5).brand, light.brand);
    });

    test('the dark palette is not a mechanical inversion of the light one', () {
      // Documented intent in app_colors.dart. If someone "simplifies" the dark
      // factory into inverted light values, status colours lose contrast on
      // dark surfaces — which the contrast group above would also catch, but
      // this states the design rule directly.
      expect(AppColors.dark().surface, isNot(AppColors.dark().background));
      expect(_luminance(AppColors.dark().surface), greaterThan(_luminance(AppColors.dark().background)));
    });
  });

  group('copyWith preserves the fields it is not asked to change', () {
    // The bug this exists for: `AppDimens.copyWith` named three parameters and
    // passed only those to the constructor, so the other fifteen fell back to
    // their defaults. A project that had tuned its spacing scale lost the tuning
    // the moment anything called `copyWith`, and the whole method was at zero
    // coverage so nothing said a word.
    //
    // Asserted for all three extensions rather than the one that broke, because
    // the next token class added here will be copied from whichever of these the
    // author happens to open.

    test('AppDimens keeps every unnamed field', () {
      const tuned = AppDimens(space16: 20, radiusLg: 28, iconMd: 30, borderWidth: 2);

      final copy = tuned.copyWith(pagePadding: 24);

      expect(copy.pagePadding, 24, reason: 'the requested change did not apply');
      expect(copy.space16, 20);
      expect(copy.radiusLg, 28);
      expect(copy.iconMd, 30);
      expect(copy.borderWidth, 2);
    });

    test('AppColors keeps every unnamed field', () {
      final tuned = AppTheme.light().extension<AppColors>()!;

      final copy = tuned.copyWith(brand: const Color(0xFF00FF00));

      expect(copy.brand, const Color(0xFF00FF00));
      expect(copy.textPrimary, tuned.textPrimary);
      expect(copy.danger, tuned.danger);
      expect(copy.skeleton, tuned.skeleton);
    });

    test('AppTypography keeps every unnamed field', () {
      final tuned = AppTheme.light().extension<AppTypography>()!;

      final copy = tuned.copyWith(bodyMd: const TextStyle(fontSize: 99));

      expect(copy.bodyMd.fontSize, 99);
      expect(copy.titleLg, tuned.titleLg);
      expect(copy.caption, tuned.caption);
    });
  });

  group('dimens expose the derived values widgets actually use', () {
    test('radius getters follow their scalar', () {
      const dimens = AppDimens(radiusSm: 4, radiusPill: 500);

      expect(dimens.radiusSmAll, BorderRadius.circular(4));
      expect(dimens.radiusPillAll, BorderRadius.circular(500));
    });

    test('page insets follow pagePadding', () {
      expect(const AppDimens(pagePadding: 20).pageInsets, const EdgeInsets.all(20));
    });
  });
}

/// WCAG 2.1 relative luminance.
double _luminance(Color color) {
  double channel(double component) {
    final value = component;
    return value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

/// WCAG 2.1 contrast ratio, 1.0 (identical) to 21.0 (black on white).
double _contrast(Color foreground, Color background) {
  final a = _luminance(foreground);
  final b = _luminance(background);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}
