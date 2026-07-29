import 'dart:async';

import 'package:core_kit/core_kit.dart';
import 'package:core_ui/src/l10n/generated/core_l10n.dart';
import 'package:core_ui/src/theme/theme_context_x.dart';
import 'package:flutter/material.dart';

/// Slides a connection banner down from the top of the app.
///
/// **Mounted once, above the router** — not a mixin, not a base screen. The
/// reasoning matters, because a mixin is the obvious first idea:
///
///   * a mixin has to be applied to every screen, and the one screen somebody
///     forgets is the one where the user is stuck wondering why nothing loads;
///   * a per-screen banner reflows that screen's layout, and shows twice inside
///     a nested navigator or a bottom sheet;
///   * connectivity is app-global state. Rendering it per screen means N
///     listeners for one value.
///
/// Placed in the app's `builder` next to `LoadingOverlayHost`, it survives every
/// navigation and costs each screen exactly nothing.
///
/// This is deliberately *only* the global connection indicator. "This screen
/// failed to load" is a different concern and stays with the screen — its bloc
/// gets a `NetworkFailure` and renders `AppErrorView` with a retry.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({
    super.key,
    required this.monitor,
    required this.child,
    this.onlineDisplayDuration = const Duration(seconds: 2),
  });

  final ConnectivityMonitor monitor;
  final Widget child;

  /// How long "back online" stays up before hiding. Confirmation matters: a
  /// banner that just disappears leaves the user unsure whether to retry.
  final Duration onlineDisplayDuration;

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

enum _BannerState { hidden, offline, restored }

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  StreamSubscription<ConnectivityStatus>? _subscription;
  Timer? _hideTimer;
  _BannerState _state = _BannerState.hidden;

  @override
  void initState() {
    super.initState();
    // `unknown` on a cold start stays hidden: flashing "no connection" before
    // the first check resolves is worse than showing nothing.
    if (widget.monitor.isOffline) _state = _BannerState.offline;
    _subscription = widget.monitor.changes.listen(_onStatus);
  }

  @override
  void didUpdateWidget(ConnectivityBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.monitor, widget.monitor)) {
      unawaited(_subscription?.cancel());
      _subscription = widget.monitor.changes.listen(_onStatus);
    }
  }

  void _onStatus(ConnectivityStatus status) {
    if (!mounted) return;
    _hideTimer?.cancel();

    switch (status) {
      case ConnectivityStatus.offline:
        setState(() => _state = _BannerState.offline);

      case ConnectivityStatus.online:
        // Only confirm a recovery the user actually saw fail.
        if (_state != _BannerState.offline) {
          setState(() => _state = _BannerState.hidden);
          return;
        }
        setState(() => _state = _BannerState.restored);
        _hideTimer = Timer(widget.onlineDisplayDuration, () {
          if (mounted) setState(() => _state = _BannerState.hidden);
        });

      case ConnectivityStatus.unknown:
        setState(() => _state = _BannerState.hidden);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            offset: _state == _BannerState.hidden ? const Offset(0, -1) : Offset.zero,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _state == _BannerState.hidden ? 0 : 1,
              child: _Banner(state: _state, onRetry: widget.monitor.check),
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.state, required this.onRetry});

  final _BannerState state;
  final Future<ConnectivityStatus> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = CoreL10n.of(context);
    final isOffline = state == _BannerState.offline;

    return Material(
      color: isOffline ? context.colors.danger : context.colors.success,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.dimens.space16, vertical: context.dimens.space8),
          child: Row(
            children: [
              Icon(
                isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                size: context.dimens.iconSm,
                color: context.colors.onStatus,
              ),
              SizedBox(width: context.dimens.space8),
              Expanded(
                child: Text(
                  isOffline ? l10n.connectivityOffline : l10n.connectivityRestored,
                  style: context.textStyles.bodySm.copyWith(color: context.colors.onStatus),
                ),
              ),
              if (isOffline)
                // Manual escape hatch: the monitor is debounced and cooled
                // down, so a user who has just fixed their wifi should not have
                // to wait for the next scheduled probe.
                TextButton(
                  onPressed: () => unawaited(onRetry()),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.onStatus,
                    padding: EdgeInsets.symmetric(horizontal: context.dimens.space8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.commonRetry, style: context.textStyles.label),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
