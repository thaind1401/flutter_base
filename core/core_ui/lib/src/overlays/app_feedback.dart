import 'package:core_kit/core_kit.dart';
import 'package:core_ui/src/l10n/failure_presenter.dart';
import 'package:core_ui/src/l10n/generated/core_l10n.dart';
import 'package:core_ui/src/theme/theme_context_x.dart';
import 'package:flutter/material.dart';

enum ToastKind { info, success, warning, error }

/// Toasts, confirmations and bottom sheets, as context extensions.
///
/// Context extensions rather than a global service: these need the widget tree
/// anyway, and taking the context as a parameter makes it obvious at the call
/// site that the caller must still be mounted. A global with a navigator key
/// hides that and fires into a disposed tree after an async gap.
extension AppFeedbackX on BuildContext {
  void showToast(String message, {ToastKind kind = ToastKind.info, Duration? duration, SnackBarAction? action}) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;

    final (Color background, IconData icon) = switch (kind) {
      ToastKind.info => (colors.textPrimary, Icons.info_outline_rounded),
      ToastKind.success => (colors.success, Icons.check_circle_outline_rounded),
      ToastKind.warning => (colors.warning, Icons.warning_amber_rounded),
      ToastKind.error => (colors.danger, Icons.error_outline_rounded),
    };

    messenger
      // Queued snackbars pile up when several requests fail at once; the newest
      // message is the relevant one.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          duration: duration ?? const Duration(seconds: 3),
          action: action,
          content: Row(
            children: [
              Icon(icon, color: colors.surface, size: dimens.iconSm),
              SizedBox(width: dimens.space8),
              Expanded(
                child: Text(message, style: textStyles.bodyMd.copyWith(color: colors.surface)),
              ),
            ],
          ),
        ),
      );
  }

  /// Toast for a [Failure], localized through [FailurePresenter].
  ///
  /// A [CancelledFailure] is swallowed: the user caused it by navigating away
  /// and an error toast for their own action is confusing.
  void showFailureToast(Failure failure, {FailurePresenter presenter = const FailurePresenter()}) {
    if (failure is CancelledFailure) return;
    showToast(presenter.present(this, failure).description, kind: ToastKind.error);
  }

  /// Yes/no dialog. Resolves false when dismissed by tapping outside, so a
  /// destructive action can never happen by accident.
  Future<bool> confirm({
    required String title,
    String? message,
    String? confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
  }) async {
    final l10n = CoreL10n.of(this);
    final result = await showDialog<bool>(
      context: this,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(cancelLabel ?? l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: isDestructive ? context.colors.danger : null),
            child: Text(confirmLabel ?? l10n.commonConfirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Bottom sheet with the design system's chrome.
  ///
  /// `isScrollControlled` and the keyboard inset are on by default: a sheet
  /// containing a text field is otherwise hidden behind the keyboard, which is
  /// the single most common bug with raw `showModalBottomSheet`.
  Future<T?> showAppBottomSheet<T>({
    required WidgetBuilder builder,
    String? title,
    bool isDismissible = true,
    bool useSafeArea = true,
  }) {
    return showModalBottomSheet<T>(
      context: this,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      useSafeArea: useSafeArea,
      backgroundColor: colors.surface,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: context.dimens.space12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
            ),
            if (title != null) ...[
              SizedBox(height: context.dimens.space16),
              Text(title, style: context.textStyles.titleSm),
            ],
            SizedBox(height: context.dimens.space16),
            Flexible(child: builder(context)),
            SizedBox(height: context.dimens.space16),
          ],
        ),
      ),
    );
  }
}
