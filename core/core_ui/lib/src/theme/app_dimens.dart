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

  @override
  AppDimens copyWith({double? pagePadding, double? controlHeight, double? radiusMd}) => AppDimens(
    pagePadding: pagePadding ?? this.pagePadding,
    controlHeight: controlHeight ?? this.controlHeight,
    radiusMd: radiusMd ?? this.radiusMd,
  );

  /// Dimensions do not animate between themes; snapping avoids a layout that
  /// jitters for 200ms on every theme switch.
  @override
  AppDimens lerp(ThemeExtension<AppDimens>? other, double t) => t < 0.5 ? this : (other as AppDimens? ?? this);
}
