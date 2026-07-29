import 'package:core_ui/src/theme/theme_context_x.dart';
import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { small, medium, large }

/// The app's button.
///
/// Wraps Material's buttons for two reasons a raw `FilledButton` cannot cover:
///   * [isLoading] swaps the label for a spinner **and** disables the button, so
///     the double-submit bug (tap, wait, tap again, two leave requests) cannot
///     be reintroduced screen by screen;
///   * variants are named by intent, so "the destructive button" is one enum
///     value rather than a colour someone has to remember.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.expanded = true,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.expanded = true,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.expanded = true,
  }) : variant = AppButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dimens = context.dimens;
    // A loading button is never pressable — this is the whole point of routing
    // every button through here.
    final enabled = onPressed != null && !isLoading;

    final height = switch (size) {
      AppButtonSize.small => 36.0,
      AppButtonSize.medium => dimens.controlHeight,
      AppButtonSize.large => 56.0,
    };

    final (Color background, Color foreground, BorderSide? border) = switch (variant) {
      AppButtonVariant.primary => (colors.brand, colors.onBrand, null),
      AppButtonVariant.secondary => (colors.surface, colors.brand, BorderSide(color: colors.border)),
      AppButtonVariant.ghost => (Colors.transparent, colors.brand, null),
      AppButtonVariant.danger => (colors.danger, colors.onStatus, null),
    };

    final child = isLoading
        ? SizedBox(
            width: dimens.iconSm,
            height: dimens.iconSm,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: dimens.iconSm), SizedBox(width: dimens.space8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final button = FilledButton(
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: variant == AppButtonVariant.ghost ? Colors.transparent : colors.border,
        disabledForegroundColor: colors.textDisabled,
        minimumSize: Size(expanded ? double.infinity : 0, height),
        padding: EdgeInsets.symmetric(horizontal: dimens.space16),
        textStyle: context.textStyles.button,
        side: border,
        shape: RoundedRectangleBorder(borderRadius: dimens.radiusMdAll),
      ),
      child: child,
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
