import 'package:flutter/material.dart';

/// Named text styles.
///
/// Screens use `context.textStyles.titleMd`, never a bare `TextStyle(...)`.
/// The colour is applied by the theme, so the same style works in light and
/// dark without a conditional at the call site.
@immutable
final class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.displayLg,
    required this.titleLg,
    required this.titleMd,
    required this.titleSm,
    required this.bodyLg,
    required this.bodyMd,
    required this.bodySm,
    required this.label,
    required this.caption,
    required this.button,
  });

  /// Heights are unitless multiples so text scales correctly when the user
  /// raises the system font size — a fixed pixel height clips at 200%.
  factory AppTypography.standard({String? fontFamily}) => AppTypography(
    displayLg: TextStyle(fontFamily: fontFamily, fontSize: 32, height: 1.25, fontWeight: FontWeight.w700),
    titleLg: TextStyle(fontFamily: fontFamily, fontSize: 24, height: 1.3, fontWeight: FontWeight.w700),
    titleMd: TextStyle(fontFamily: fontFamily, fontSize: 18, height: 1.35, fontWeight: FontWeight.w600),
    titleSm: TextStyle(fontFamily: fontFamily, fontSize: 16, height: 1.4, fontWeight: FontWeight.w600),
    bodyLg: TextStyle(fontFamily: fontFamily, fontSize: 16, height: 1.5),
    bodyMd: TextStyle(fontFamily: fontFamily, fontSize: 14, height: 1.5),
    bodySm: TextStyle(fontFamily: fontFamily, fontSize: 12, height: 1.45),
    label: TextStyle(fontFamily: fontFamily, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
    caption: TextStyle(fontFamily: fontFamily, fontSize: 11, height: 1.35),
    button: TextStyle(fontFamily: fontFamily, fontSize: 15, height: 1.2, fontWeight: FontWeight.w600),
  );

  final TextStyle displayLg;
  final TextStyle titleLg;
  final TextStyle titleMd;
  final TextStyle titleSm;
  final TextStyle bodyLg;
  final TextStyle bodyMd;
  final TextStyle bodySm;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle button;

  /// Applies the theme's text colour to every style in one pass.
  AppTypography withColor(Color color) => AppTypography(
    displayLg: displayLg.copyWith(color: color),
    titleLg: titleLg.copyWith(color: color),
    titleMd: titleMd.copyWith(color: color),
    titleSm: titleSm.copyWith(color: color),
    bodyLg: bodyLg.copyWith(color: color),
    bodyMd: bodyMd.copyWith(color: color),
    bodySm: bodySm.copyWith(color: color),
    label: label.copyWith(color: color),
    caption: caption.copyWith(color: color),
    button: button.copyWith(color: color),
  );

  @override
  AppTypography copyWith({TextStyle? bodyMd, TextStyle? titleMd}) => AppTypography(
    displayLg: displayLg,
    titleLg: titleLg,
    titleMd: titleMd ?? this.titleMd,
    titleSm: titleSm,
    bodyLg: bodyLg,
    bodyMd: bodyMd ?? this.bodyMd,
    bodySm: bodySm,
    label: label,
    caption: caption,
    button: button,
  );

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      displayLg: TextStyle.lerp(displayLg, other.displayLg, t)!,
      titleLg: TextStyle.lerp(titleLg, other.titleLg, t)!,
      titleMd: TextStyle.lerp(titleMd, other.titleMd, t)!,
      titleSm: TextStyle.lerp(titleSm, other.titleSm, t)!,
      bodyLg: TextStyle.lerp(bodyLg, other.bodyLg, t)!,
      bodyMd: TextStyle.lerp(bodyMd, other.bodyMd, t)!,
      bodySm: TextStyle.lerp(bodySm, other.bodySm, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
    );
  }
}
