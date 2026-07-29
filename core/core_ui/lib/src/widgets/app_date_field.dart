import 'package:core_kit/core_kit.dart';
import 'package:core_ui/src/theme/theme_context_x.dart';
import 'package:flutter/material.dart';

/// The app's date field.
///
/// Not a `TextField`: a date must come from the picker, never from typing, or
/// the field accepts "31 Feb" and the bloc has to validate a string it never
/// needed. Tapping anywhere in the field opens `showDatePicker`; there is no
/// text cursor to fight with.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.hint,
    this.errorText,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? label;
  final String? hint;

  /// Non-null shows the field in its error state, same contract as
  /// [AppTextField.errorText].
  final String? errorText;

  /// Defaults to five years either side of today — wide enough for a form
  /// that schedules or backdates something, narrow enough that a mis-tap
  /// cannot land in the wrong decade.
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dimens = context.dimens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[Text(label!, style: context.textStyles.label), SizedBox(height: dimens.space4)],
        InkWell(
          borderRadius: dimens.radiusMdAll,
          onTap: enabled ? () => _pick(context) : null,
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: hint,
              errorText: errorText,
              counterText: '',
              suffixIcon: Icon(Icons.calendar_today_outlined, size: dimens.iconMd, color: colors.textSecondary),
            ),
            child: Text(value == null ? '' : value!.format('dd MMM yyyy'), style: context.textStyles.bodyMd),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: firstDate ?? DateTime(now.year - 5),
      lastDate: lastDate ?? DateTime(now.year + 5),
    );
    if (picked != null) onChanged(picked);
  }
}
