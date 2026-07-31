import 'package:core_ui/src/l10n/generated/core_l10n.dart';
import 'package:core_ui/src/theme/theme_context_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's text input.
///
/// [errorText] is driven by the bloc's `FormzInput`, not by an internal
/// `validator`. That keeps validation in one place — the same rules run on
/// submit as on keystroke — and lets the submit button's enabled state and the
/// field's error come from the same source of truth.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffix,
    this.inputFormatters,
    this.focusNode,
    this.autofillHints,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;

  /// Non-null shows the field in its error state. Comes from
  /// `input.displayError` so a pristine field never shows an error.
  final String? errorText;

  final String? helperText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int maxLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dimens = context.dimens;
    final l10n = CoreL10n.of(context);

    final field = TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      obscureText: _obscured,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: context.textStyles.bodyMd,
      decoration: InputDecoration(
        hintText: widget.hint,
        errorText: widget.errorText,
        helperText: widget.helperText,
        counterText: '',
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, size: dimens.iconMd, color: colors.textSecondary),
        // The reveal toggle is built in: hand-rolling it per screen is how
        // one login form ends up without it.
        suffixIcon: widget.obscureText
            ? IconButton(
                // Without this the toggle announces as "button" with no name,
                // and there is nothing on screen to infer it from — the icon is
                // the only content. `tooltip` supplies the semantic name and a
                // long-press label in one, so the two cannot drift apart.
                tooltip: _obscured ? l10n.a11yShowPassword : l10n.a11yHidePassword,
                icon: Icon(
                  _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: dimens.iconMd,
                  color: colors.textSecondary,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : widget.suffix,
      ),
    );

    if (widget.label == null) return field;

    // The label is a sibling `Text`, not `InputDecoration.labelText`, so nothing
    // connects the two: a screen reader reads "Email" as loose text, then moves
    // to an unnamed edit field. `MergeSemantics` makes the pair one node, which
    // is how a sighted user already perceives it.
    //
    // The visible label is kept as its own `Text` rather than handed to
    // `labelText` on purpose — a Material floating label animates into the
    // border and this design system puts it above the field, statically.
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label!, style: context.textStyles.label),
          SizedBox(height: dimens.space4),
          field,
        ],
      ),
    );
  }
}
