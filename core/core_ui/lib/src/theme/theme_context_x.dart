import 'package:core_ui/src/theme/app_colors.dart';
import 'package:core_ui/src/theme/app_dimens.dart';
import 'package:core_ui/src/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Short accessors for the design tokens.
///
/// `Theme.of(context).extension<AppColors>()!` at every call site is noisy and
/// the `!` invites a null crash when a widget is built outside the app theme.
/// These fall back to the default light tokens instead, so a widget rendered in
/// a bare `MaterialApp` in a test or a preview still looks right.
extension ThemeContextX on BuildContext {
  ThemeData get theme => Theme.of(this);

  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light();

  AppTypography get textStyles =>
      Theme.of(this).extension<AppTypography>() ?? AppTypography.standard().withColor(AppColors.light().textPrimary);

  AppDimens get dimens => Theme.of(this).extension<AppDimens>() ?? const AppDimens();

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  MediaQueryData get mediaQuery => MediaQuery.of(this);

  Size get screenSize => MediaQuery.sizeOf(this);

  /// Bottom inset for the on-screen keyboard — needed to keep a submit button
  /// above the keyboard in a scrollable form.
  double get keyboardInset => MediaQuery.viewInsetsOf(this).bottom;

  bool get isKeyboardVisible => keyboardInset > 0;
}
