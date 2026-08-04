import 'package:flutter/material.dart';

/// Spacing, radius and elevation on a fixed scale.
///
/// A scale rather than free numbers: when every gap is one of seven values,
/// screens line up without anyone measuring, and a density change is one edit.
/// `SizedBox(height: 13)` in a widget is the smell this replaces.
@immutable
final class AppDimens extends ThemeExtension<AppDimens> {
  const AppDimens({
    this.space2 = 2,
    this.space4 = 4,
    this.space8 = 8,
    this.space12 = 12,
    this.space16 = 16,
    this.space24 = 24,
    this.space32 = 32,
    this.space48 = 48,
    this.radiusSm = 6,
    this.radiusMd = 12,
    this.radiusLg = 20,
    this.radiusPill = 999,
    this.borderWidth = 1,
    this.iconSm = 16,
    this.iconMd = 24,
    this.iconLg = 32,
    this.controlHeight = 48,
    this.pagePadding = 16,
  });

  final double space2;
  final double space4;
  final double space8;
  final double space12;
  final double space16;
  final double space24;
  final double space32;
  final double space48;

  final double radiusSm;
  final double radiusMd;
  final double radiusLg;

  /// Fully rounded — for chips and pill buttons.
  final double radiusPill;

  final double borderWidth;

  final double iconSm;
  final double iconMd;
  final double iconLg;

  /// Minimum tappable height for buttons and fields. Kept at 48 to satisfy the
  /// platform accessibility guidance on both iOS and Android.
  final double controlHeight;

  final double pagePadding;

  EdgeInsets get pageInsets => EdgeInsets.all(pagePadding);

  BorderRadius get radiusSmAll => BorderRadius.circular(radiusSm);

  BorderRadius get radiusMdAll => BorderRadius.circular(radiusMd);

  BorderRadius get radiusLgAll => BorderRadius.circular(radiusLg);

  BorderRadius get radiusPillAll => BorderRadius.circular(radiusPill);

  /// Every field, forwarded.
  ///
  /// It used to name three and pass only those to the constructor, so the other
  /// fifteen silently fell back to their **defaults**: a project that had tuned
  /// `space16` lost that tuning the moment anything called
  /// `copyWith(pagePadding: …)`. Nothing caught it because the whole method sat
  /// at zero coverage, and `AppColors` and `AppTypography` — which both forward
  /// correctly — made the pattern look established.
  ///
  /// A partial `copyWith` on a `ThemeExtension` is always this bug. If a field
  /// is not worth a parameter, it still has to be passed through.
  @override
  AppDimens copyWith({
    double? space2,
    double? space4,
    double? space8,
    double? space12,
    double? space16,
    double? space24,
    double? space32,
    double? space48,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusPill,
    double? borderWidth,
    double? iconSm,
    double? iconMd,
    double? iconLg,
    double? controlHeight,
    double? pagePadding,
  }) => AppDimens(
    space2: space2 ?? this.space2,
    space4: space4 ?? this.space4,
    space8: space8 ?? this.space8,
    space12: space12 ?? this.space12,
    space16: space16 ?? this.space16,
    space24: space24 ?? this.space24,
    space32: space32 ?? this.space32,
    space48: space48 ?? this.space48,
    radiusSm: radiusSm ?? this.radiusSm,
    radiusMd: radiusMd ?? this.radiusMd,
    radiusLg: radiusLg ?? this.radiusLg,
    radiusPill: radiusPill ?? this.radiusPill,
    borderWidth: borderWidth ?? this.borderWidth,
    iconSm: iconSm ?? this.iconSm,
    iconMd: iconMd ?? this.iconMd,
    iconLg: iconLg ?? this.iconLg,
    controlHeight: controlHeight ?? this.controlHeight,
    pagePadding: pagePadding ?? this.pagePadding,
  );

  /// Dimensions do not animate between themes; snapping avoids a layout that
  /// jitters for 200ms on every theme switch.
  @override
  AppDimens lerp(ThemeExtension<AppDimens>? other, double t) => t < 0.5 ? this : (other as AppDimens? ?? this);
}
