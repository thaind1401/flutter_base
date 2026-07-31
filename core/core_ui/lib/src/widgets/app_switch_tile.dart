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

    // One node for the whole row, not two.
    //
    // The row is an `InkWell` *and* contains a `Switch`, so without this a
    // screen reader finds two separate controls for the same setting: an
    // unnamed tappable region, then a switch with no label. This publishes the
    // single "…, switch, on" node that matches what the widget already claims
    // to be — a row where the whole thing toggles, not just the thumb.
    //
    // The subtree is **excluded**, not merged. Merging keeps every descendant's
    // contribution, so the title `Text` and the label here both land on the
    // node and it announces "Notifications Notifications" — which is what
    // `accessibility_test.dart` caught. Everything the node needs is already on
    // this `Semantics`: the title, the subtitle, the toggle state, the action.
    //
    // `ExcludeSemantics` hides the subtree from assistive technology only. Hit
    // testing is untouched, so the `InkWell` still handles the real tap and
    // still draws its ripple.
    return Semantics(
      container: true,
      toggled: value,
      enabled: callback != null,
      label: subtitle == null ? title : '$title. $subtitle',
      onTap: callback == null ? null : () => callback(!value),
      child: ExcludeSemantics(
        child: InkWell(
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
        ),
      ),
    );
  }
}
