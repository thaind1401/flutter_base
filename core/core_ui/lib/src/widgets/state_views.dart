import 'package:core_kit/core_kit.dart';
import 'package:core_ui/src/l10n/failure_presenter.dart';
import 'package:core_ui/src/l10n/generated/core_l10n.dart';
import 'package:core_ui/src/theme/theme_context_x.dart';
import 'package:flutter/material.dart';

/// Centered spinner. The one loading indicator in the app, so a design change
/// (a branded animation, a skeleton) lands everywhere at once.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.message, this.size = 28});

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: context.colors.brand),
          ),
          if (message != null) ...[
            SizedBox(height: context.dimens.space12),
            Text(message!, style: context.textStyles.bodySm.copyWith(color: context.colors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// Full-area error state with an optional retry.
///
/// Takes a [Failure] rather than a string so the decision about what to say —
/// and whether retrying is even meaningful — stays in [FailurePresenter]
/// instead of being made again at each call site.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.failure,
    this.onRetry,
    this.presenter = const FailurePresenter(),
    this.compact = false,
  });

  final Failure failure;
  final VoidCallback? onRetry;
  final FailurePresenter presenter;

  /// Inline variant for a list footer or a card, rather than a full page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final message = presenter.present(context, failure);
    final showRetry = onRetry != null && message.canRetry;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? context.dimens.space16 : context.dimens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(failure), size: compact ? context.dimens.iconLg : 48, color: context.colors.textDisabled),
            SizedBox(height: context.dimens.space12),
            Text(message.title, textAlign: TextAlign.center, style: context.textStyles.titleSm),
            SizedBox(height: context.dimens.space4),
            Text(
              message.description,
              textAlign: TextAlign.center,
              style: context.textStyles.bodySm.copyWith(color: context.colors.textSecondary),
            ),
            if (message.reference != null) ...[
              SizedBox(height: context.dimens.space8),
              // Support asks for this on every ticket; showing it saves a round
              // trip asking the user to reproduce the problem.
              Text(
                CoreL10n.of(context).errorTraceId(message.reference!),
                style: context.textStyles.caption.copyWith(color: context.colors.textDisabled),
              ),
            ],
            if (showRetry) ...[
              SizedBox(height: context.dimens.space16),
              OutlinedButton(onPressed: onRetry, child: Text(CoreL10n.of(context).commonRetry)),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(Failure failure) => switch (failure) {
    NetworkFailure() => Icons.wifi_off_rounded,
    TimeoutFailure() => Icons.hourglass_empty_rounded,
    UnauthorizedFailure() => Icons.lock_outline_rounded,
    ForbiddenFailure() => Icons.block_rounded,
    NotFoundFailure() => Icons.search_off_rounded,
    PermissionFailure() => Icons.settings_outlined,
    _ => Icons.error_outline_rounded,
  };
}

/// Full-area empty state.
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({super.key, this.title, this.description, this.icon, this.action});

  /// The variant for "your search matched nothing", which is a different
  /// message from "you have no data yet" and is confusing when they share copy.
  const AppEmptyView.search({super.key, this.action})
    : title = null,
      description = null,
      icon = Icons.search_off_rounded;

  final String? title;
  final String? description;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l10n = CoreL10n.of(context);
    final isSearch = icon == Icons.search_off_rounded && title == null;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.dimens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.inbox_outlined, size: 48, color: context.colors.textDisabled),
            SizedBox(height: context.dimens.space12),
            Text(
              title ?? (isSearch ? l10n.emptySearchTitle : l10n.emptyTitle),
              textAlign: TextAlign.center,
              style: context.textStyles.titleSm,
            ),
            SizedBox(height: context.dimens.space4),
            Text(
              description ?? (isSearch ? l10n.emptySearchDescription : l10n.emptyDescription),
              textAlign: TextAlign.center,
              style: context.textStyles.bodySm.copyWith(color: context.colors.textSecondary),
            ),
            if (action != null) ...[SizedBox(height: context.dimens.space16), action!],
          ],
        ),
      ),
    );
  }
}
