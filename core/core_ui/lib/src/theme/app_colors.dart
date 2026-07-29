import 'package:flutter/material.dart';

/// Semantic colors, exposed as a [ThemeExtension].
///
/// Widgets ask for meaning (`context.colors.danger`) rather than for a value
/// (`Colors.red`). That is what makes a dark theme, a white-label rebrand or an
/// accessibility pass a change to this one file instead of a search across
/// every screen.
///
/// Anything a widget needs that is not here should be *added* here — a literal
/// `Color(0xFF...)` inside a widget is the failure mode this exists to prevent.
@immutable
final class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brand,
    required this.onBrand,
    required this.brandSubtle,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.onStatus,
    required this.overlay,
    required this.skeleton,
  });

  /// Placeholder brand palette. `make rename` does not touch colors — swapping
  /// these two constructors is the intended first step of theming a new app.
  factory AppColors.light() => const AppColors(
    brand: Color(0xFF2563EB),
    onBrand: Color(0xFFFFFFFF),
    brandSubtle: Color(0xFFDBEAFE),
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textDisabled: Color(0xFF94A3B8),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    info: Color(0xFF0284C7),
    onStatus: Color(0xFFFFFFFF),
    overlay: Color(0x8A000000),
    skeleton: Color(0xFFE2E8F0),
  );

  /// Not a mechanical inversion: surfaces lift as they get closer to the user,
  /// and status colors are lightened so they keep contrast on a dark surface.
  factory AppColors.dark() => const AppColors(
    brand: Color(0xFF60A5FA),
    onBrand: Color(0xFF0B1220),
    brandSubtle: Color(0xFF1E3A5F),
    background: Color(0xFF0B1220),
    surface: Color(0xFF151C2C),
    surfaceVariant: Color(0xFF1E2637),
    border: Color(0xFF2B3547),
    textPrimary: Color(0xFFE2E8F0),
    textSecondary: Color(0xFF94A3B8),
    textDisabled: Color(0xFF64748B),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    info: Color(0xFF38BDF8),
    onStatus: Color(0xFF0B1220),
    overlay: Color(0xB3000000),
    skeleton: Color(0xFF1E2637),
  );

  final Color brand;
  final Color onBrand;
  final Color brandSubtle;

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  /// Foreground for text sitting on a status color.
  final Color onStatus;

  /// Scrim behind modals and the blocking loader.
  final Color overlay;

  /// Shimmer base for loading placeholders.
  final Color skeleton;

  @override
  AppColors copyWith({
    Color? brand,
    Color? onBrand,
    Color? brandSubtle,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? onStatus,
    Color? overlay,
    Color? skeleton,
  }) => AppColors(
    brand: brand ?? this.brand,
    onBrand: onBrand ?? this.onBrand,
    brandSubtle: brandSubtle ?? this.brandSubtle,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceVariant: surfaceVariant ?? this.surfaceVariant,
    border: border ?? this.border,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textDisabled: textDisabled ?? this.textDisabled,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    info: info ?? this.info,
    onStatus: onStatus ?? this.onStatus,
    overlay: overlay ?? this.overlay,
    skeleton: skeleton ?? this.skeleton,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brand: mix(brand, other.brand),
      onBrand: mix(onBrand, other.onBrand),
      brandSubtle: mix(brandSubtle, other.brandSubtle),
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceVariant: mix(surfaceVariant, other.surfaceVariant),
      border: mix(border, other.border),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textDisabled: mix(textDisabled, other.textDisabled),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      info: mix(info, other.info),
      onStatus: mix(onStatus, other.onStatus),
      overlay: mix(overlay, other.overlay),
      skeleton: mix(skeleton, other.skeleton),
    );
  }
}
