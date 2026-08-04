import 'package:core_ui/src/theme/app_colors.dart';
import 'package:core_ui/src/theme/app_dimens.dart';
import 'package:core_ui/src/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Builds the app's [ThemeData] from the token extensions.
///
/// Material's own `ColorScheme` is filled in from the same tokens so that
/// stock widgets (dialogs, snackbars, pickers) match the design system without
/// being restyled one by one.
abstract final class AppTheme {
  static ThemeData light({String? fontFamily}) => _build(AppColors.light(), Brightness.light, fontFamily);

  static ThemeData dark({String? fontFamily}) => _build(AppColors.dark(), Brightness.dark, fontFamily);

  static ThemeData _build(AppColors colors, Brightness brightness, String? fontFamily) {
    final typography = AppTypography.standard(fontFamily: fontFamily).withColor(colors.textPrimary);
    const dimens = AppDimens();

    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.brand,
      onPrimary: colors.onBrand,
      primaryContainer: colors.brandSubtle,
      onPrimaryContainer: colors.textPrimary,
      secondary: colors.info,
      onSecondary: colors.onStatus,
      // Spelled out, because leaving them off is not neutral: Material falls
      // back to `secondary`, and several widgets fill themselves from the
      // *container* roles rather than the base ones. `SegmentedButton` is one —
      // its selected segment took `info` as a background and put `onStatus`
      // white on it, giving 4.10:1 behind a 14pt regular label where WCAG AA
      // asks 4.5. A status colour is for a banner that says something happened;
      // it was never meant to carry interface text.
      //
      // `brandSubtle` with `textPrimary` is the pairing these roles are for, and
      // it is what a selected segment should look like anyway — a tint, not a
      // saturated fill. Found by running `textContrastGuideline` over the real
      // settings screen; no golden covers a SegmentedButton, and the token test
      // checked `onStatus` against danger and success but never against info.
      secondaryContainer: colors.brandSubtle,
      onSecondaryContainer: colors.textPrimary,
      error: colors.danger,
      onError: colors.onStatus,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      surfaceContainerHighest: colors.surfaceVariant,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      fontFamily: fontFamily,
      // Tokens ride along on every ThemeData so `context.colors` works
      // everywhere, including inside a nested Theme override.
      extensions: [colors, typography, dimens],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: typography.titleMd,
        systemOverlayStyle: brightness == Brightness.light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: dimens.borderWidth, space: dimens.borderWidth),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: dimens.radiusMdAll,
          side: BorderSide(color: colors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: dimens.space16, vertical: dimens.space12),
        hintStyle: typography.bodyMd.copyWith(color: colors.textDisabled),
        labelStyle: typography.label.copyWith(color: colors.textSecondary),
        errorStyle: typography.caption.copyWith(color: colors.danger),
        border: OutlineInputBorder(
          borderRadius: dimens.radiusMdAll,
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: dimens.radiusMdAll,
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: dimens.radiusMdAll,
          borderSide: BorderSide(color: colors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: dimens.radiusMdAll,
          borderSide: BorderSide(color: colors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: dimens.radiusMdAll,
          borderSide: BorderSide(color: colors.danger, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(dimens.controlHeight),
          backgroundColor: colors.brand,
          foregroundColor: colors.onBrand,
          disabledBackgroundColor: colors.border,
          disabledForegroundColor: colors.textDisabled,
          textStyle: typography.button,
          shape: RoundedRectangleBorder(borderRadius: dimens.radiusMdAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(dimens.controlHeight),
          foregroundColor: colors.brand,
          side: BorderSide(color: colors.border),
          textStyle: typography.button,
          shape: RoundedRectangleBorder(borderRadius: dimens.radiusMdAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.brand, textStyle: typography.button),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(dimens.radiusLg))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: dimens.radiusLgAll),
        titleTextStyle: typography.titleSm,
        contentTextStyle: typography.bodyMd.copyWith(color: colors.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.textPrimary,
        contentTextStyle: typography.bodyMd.copyWith(color: colors.surface),
        shape: RoundedRectangleBorder(borderRadius: dimens.radiusMdAll),
      ),
      // The default splash makes a design-system button look unbranded and is
      // the first thing designers file a bug about.
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
