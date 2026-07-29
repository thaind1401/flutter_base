import 'package:core_ui/src/theme/theme_context_x.dart';
import 'package:flutter/material.dart';

/// One choice in an [AppDropdownField].
///
/// A separate type rather than handing the field a raw `Map` or two parallel
/// lists: the value and its label travel together, so they cannot fall out of
/// sync when someone reorders one list and not the other.
@immutable
final class AppDropdownItem<T> {
  const AppDropdownItem({required this.value, required this.label});

  final T value;
  final String label;
}

/// The app's select field.
///
/// Sibling to [AppTextField] rather than a bare `DropdownButtonFormField`:
/// same label-above layout, same minimal [InputDecoration] (hint, error,
/// nothing else — border and fill colour come from the app's
/// `inputDecorationTheme` so the two fields render identically without this
/// one repeating that styling).
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.items,
    required this.value,
    this.onChanged,
    this.label,
    this.hint,
    this.errorText,
    this.enabled = true,
  });

  final List<AppDropdownItem<T>> items;

  /// Must be null or match the `value` of one entry in [items] — the same
  /// requirement `DropdownButtonFormField` itself enforces.
  final T? value;

  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hint;

  /// Non-null shows the field in its error state, same contract as
  /// [AppTextField.errorText].
  final String? errorText;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dimens = context.dimens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[Text(label!, style: context.textStyles.label), SizedBox(height: dimens.space4)],
        DropdownButtonFormField<T>(
          initialValue: value,
          items: [for (final item in items) DropdownMenuItem<T>(value: item.value, child: Text(item.label))],
          onChanged: enabled ? onChanged : null,
          icon: Icon(Icons.expand_more_rounded, size: dimens.iconMd, color: colors.textSecondary),
          style: context.textStyles.bodyMd.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(hintText: hint, errorText: errorText, counterText: ''),
        ),
      ],
    );
  }
}
