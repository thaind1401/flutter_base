import 'package:core_ui/src/theme/theme_context_x.dart';
import 'package:flutter/material.dart';

/// A labelled boolean toggle.
///
/// Wraps title, optional description and the switch as one tappable row —
/// the whole row toggles, not just the small thumb, which is the target size
/// the platform accessibility guidance asks for.
class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dimens = context.dimens;
    final callback = enabled ? onChanged : null;

    return InkWell(
      borderRadius: dimens.radiusMdAll,
      onTap: callback == null ? null : () => callback(!value),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: dimens.space8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.bodyMd),
                  if (subtitle != null) ...[
                    SizedBox(height: dimens.space4),
                    Text(subtitle!, style: context.textStyles.bodySm.copyWith(color: colors.textSecondary)),
                  ],
                ],
              ),
            ),
            SizedBox(width: dimens.space12),
            Switch.adaptive(value: value, onChanged: callback, activeTrackColor: colors.brand),
          ],
        ),
      ),
    );
  }
}
