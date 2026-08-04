import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_ui/src/widgets/state_views.dart';
import 'package:flutter/material.dart';

/// Renders a [ViewState] without every screen re-writing the same five
/// branches.
///
/// Only [data] is required. Loading, empty and error fall back to the design
/// system's own views, so a screen's build method contains its content and
/// nothing else — and the day the error view changes, it changes once.
class ViewStateBuilder<T> extends StatelessWidget {
  const ViewStateBuilder({
    super.key,
    required this.state,
    required this.data,
    this.onRetry,
    this.loading,
    this.empty,
    this.error,
    this.idle,
  });

  final ViewState<T> state;
  final Widget Function(BuildContext context, T data) data;

  /// Re-runs the failed load. Only rendered for failures worth retrying.
  final VoidCallback? onRetry;

  final WidgetBuilder? loading;
  final WidgetBuilder? empty;
  final Widget Function(BuildContext context, Failure failure)? error;

  /// Defaults to the loading view: for most screens "not asked yet" and
  /// "asking" look the same to the user.
  final WidgetBuilder? idle;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ViewIdle<T>() => idle?.call(context) ?? loading?.call(context) ?? const AppLoader(),
      ViewLoading<T>() => loading?.call(context) ?? const AppLoader(),
      ViewEmpty<T>(:final message) => empty?.call(context) ?? AppEmptyView(description: message),
      ViewData<T>(data: final value) => data(context, value),
      // Stale content stays visible under a retry affordance rather than being
      // replaced by a full-screen error the user cannot escape.
      ViewFailed<T>(:final failure, :final lastData) =>
        lastData != null
            ? data(context, lastData)
            : error?.call(context, failure) ?? AppErrorView(failure: failure, onRetry: onRetry),
    };
  }
}

/// Bloc-aware [ViewStateBuilder]: subscribes and rebuilds on state change.
class ViewStateConsumer<B extends StateStreamable<S>, S, T> extends StatelessWidget {
  const ViewStateConsumer({
    super.key,
    required this.selector,
    required this.data,
    this.onRetry,
    this.loading,
    this.empty,
    this.error,
  });

  /// Pulls the [ViewState] out of a larger bloc state, so a screen with several
  /// independent sections can drive each from one bloc.
  final ViewState<T> Function(S state) selector;

  final Widget Function(BuildContext context, T data) data;
  final VoidCallback? onRetry;
  final WidgetBuilder? loading;
  final WidgetBuilder? empty;
  final Widget Function(BuildContext context, Failure failure)? error;

  /// A `BlocSelector`, which is what rule 11 asks every screen to use — this
  /// widget was the counter-example living inside the design system.
  ///
  /// It used to be `BlocBuilder` with
  /// `buildWhen: (p, c) => selector(p) != selector(c)` and a builder that called
  /// `selector(state)` again. Two problems, and the second is the one that
  /// matters:
  ///
  ///   * `selector` ran three times per state change instead of once, so any
  ///     work inside it — a `where`, a `map`, a lookup — was paid triple on
  ///     every emit, in the widget most likely to be copied;
  ///   * the rebuild condition and the value the builder rendered were two
  ///     separate expressions. That is exactly what rule 11 calls a last resort,
  ///     because the two drift: change one and the widget keeps rendering while
  ///     silently no longer rebuilding for the right reason.
  ///
  /// `BlocSelector` collapses both into one expression that cannot disagree
  /// with itself, and caches the selected value so the comparison is against
  /// what was last *rendered* rather than a re-derivation.
  @override
  Widget build(BuildContext context) {
    return BlocSelector<B, S, ViewState<T>>(
      selector: selector,
      builder: (context, viewState) => ViewStateBuilder<T>(
        state: viewState,
        data: data,
        onRetry: onRetry,
        loading: loading,
        empty: empty,
        error: error,
      ),
    );
  }
}
