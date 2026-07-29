import 'dart:async';

import 'package:core_ui/src/theme/theme_context_x.dart';
import 'package:core_ui/src/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

enum LoadingOverlayStatus { hidden, loading, success, failed }

@immutable
final class LoadingOverlayState {
  const LoadingOverlayState._(this.status, [this.message]);

  const LoadingOverlayState.hidden() : this._(LoadingOverlayStatus.hidden);

  const LoadingOverlayState.loading([String? message]) : this._(LoadingOverlayStatus.loading, message);

  const LoadingOverlayState.success([String? message]) : this._(LoadingOverlayStatus.success, message);

  const LoadingOverlayState.failed([String? message]) : this._(LoadingOverlayStatus.failed, message);

  final LoadingOverlayStatus status;
  final String? message;

  bool get isVisible => status != LoadingOverlayStatus.hidden;
}

/// The app-wide blocking loader.
///
/// A controller plus a host widget rather than `showDialog`: a dialog needs a
/// `BuildContext` and a matching `pop`, and an unbalanced pop — a failure path
/// that returns early, a screen popped while a request is in flight — leaves
/// the app stuck behind a modal barrier. Here the overlay is a value in a
/// [ValueNotifier]; hiding it is idempotent and cannot pop the wrong route.
///
/// Reach for it only for genuinely blocking work (submitting a form). Loading
/// *content* belongs in the screen's own [ViewState].
@lazySingleton
final class LoadingOverlayController {
  final ValueNotifier<LoadingOverlayState> state = ValueNotifier(const LoadingOverlayState.hidden());
  Timer? _autoHide;

  /// Nesting: two concurrent operations must not let the first one to finish
  /// dismiss the overlay while the second is still running.
  int _depth = 0;

  void show([String? message]) {
    _depth++;
    _autoHide?.cancel();
    state.value = LoadingOverlayState.loading(message);
  }

  void hide() {
    _depth = (_depth - 1).clamp(0, 1 << 30);
    if (_depth > 0) return;
    _autoHide?.cancel();
    state.value = const LoadingOverlayState.hidden();
  }

  /// Dismisses everything regardless of depth — for a hard reset such as a
  /// forced sign-out.
  void reset() {
    _depth = 0;
    _autoHide?.cancel();
    state.value = const LoadingOverlayState.hidden();
  }

  void showSuccess({String? message, Duration duration = const Duration(milliseconds: 1200)}) =>
      _flash(LoadingOverlayState.success(message), duration);

  void showFailure({String? message, Duration duration = const Duration(milliseconds: 1600)}) =>
      _flash(LoadingOverlayState.failed(message), duration);

  void _flash(LoadingOverlayState next, Duration duration) {
    _depth = 0;
    _autoHide?.cancel();
    state.value = next;
    _autoHide = Timer(duration, reset);
  }

  /// Runs [action] with the overlay up, guaranteeing it comes down — including
  /// when [action] throws.
  Future<T> wrap<T>(Future<T> Function() action, {String? message}) async {
    show(message);
    try {
      return await action();
    } finally {
      hide();
    }
  }

  @disposeMethod
  void dispose() {
    _autoHide?.cancel();
    state.dispose();
  }
}

/// Renders whatever [LoadingOverlayController] currently holds. Mounted once,
/// above the router, in the app's `builder`.
class LoadingOverlayHost extends StatelessWidget {
  const LoadingOverlayHost({super.key, required this.controller, required this.child});

  final LoadingOverlayController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<LoadingOverlayState>(
          valueListenable: controller.state,
          builder: (context, state, _) {
            if (!state.isVisible) return const SizedBox.shrink();
            return Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: context.colors.overlay,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(context.dimens.space24),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: context.dimens.radiusLgAll,
                      ),
                      child: switch (state.status) {
                        LoadingOverlayStatus.loading => AppLoader(message: state.message),
                        LoadingOverlayStatus.success => _Result(
                          icon: Icons.check_circle_outline_rounded,
                          color: context.colors.success,
                          message: state.message,
                        ),
                        LoadingOverlayStatus.failed => _Result(
                          icon: Icons.error_outline_rounded,
                          color: context.colors.danger,
                          message: state.message,
                        ),
                        LoadingOverlayStatus.hidden => const SizedBox.shrink(),
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.icon, required this.color, this.message});

  final IconData icon;
  final Color color;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: context.dimens.iconLg),
        if (message != null) ...[
          SizedBox(height: context.dimens.space8),
          Text(message!, textAlign: TextAlign.center, style: context.textStyles.bodySm),
        ],
      ],
    );
  }
}
