import 'package:core_kit/core_kit.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// What a screen showing one piece of data can be.
///
/// This replaces the old `status` enum plus nullable `data`/`error` triple.
/// That shape allowed states that cannot exist — `status: error` with data and
/// no error object — and forced every widget to re-check nullability the
/// compiler could not verify. Here, if you have a [ViewData] you have data; if
/// you have a [ViewFailed] you have a failure. `switch` is exhaustive.
///
/// ```dart
/// switch (state) {
///   ViewIdle() || ViewLoading() => const AppLoader(),
///   ViewEmpty(:final message)   => AppEmptyView(message: message),
///   ViewFailed(:final failure)  => AppErrorView(failure: failure, onRetry: ...),
///   ViewData(:final data)       => _Content(data),
/// }
/// ```
@immutable
sealed class ViewState<T> extends Equatable {
  const ViewState();

  /// Nothing requested yet. Distinct from [ViewLoading] so a screen can tell
  /// "never asked" from "asking now" — they often render differently.
  const factory ViewState.idle() = ViewIdle<T>;

  const factory ViewState.loading() = ViewLoading<T>;

  const factory ViewState.data(T data, {bool isRefreshing}) = ViewData<T>;

  const factory ViewState.empty({String? message}) = ViewEmpty<T>;

  const factory ViewState.failed(Failure failure, {T? lastData}) = ViewFailed<T>;

  /// The data if there is any — including the stale copy kept by [ViewFailed],
  /// which is what lets a screen show old content behind an error banner.
  T? get dataOrNull => switch (this) {
    ViewData<T>(:final data) => data,
    ViewFailed<T>(:final lastData) => lastData,
    _ => null,
  };

  bool get isLoading => this is ViewLoading<T>;

  bool get hasData => dataOrNull != null;

  /// True while a pull-to-refresh runs over content that is already on screen.
  bool get isRefreshing => this is ViewData<T> && (this as ViewData<T>).isRefreshing;

  @override
  bool get stringify => true;
}

final class ViewIdle<T> extends ViewState<T> {
  const ViewIdle();

  @override
  List<Object?> get props => const [];
}

final class ViewLoading<T> extends ViewState<T> {
  const ViewLoading();

  @override
  List<Object?> get props => const [];
}

final class ViewData<T> extends ViewState<T> {
  const ViewData(this.data, {this.isRefreshing = false});

  final T data;

  /// A refresh over existing content. Kept on [ViewData] rather than being its
  /// own state so the screen never has to clear what the user is reading.
  @override
  final bool isRefreshing;

  ViewData<T> refreshing() => ViewData<T>(data, isRefreshing: true);

  ViewData<T> settled() => ViewData<T>(data);

  @override
  List<Object?> get props => [data, isRefreshing];
}

final class ViewEmpty<T> extends ViewState<T> {
  const ViewEmpty({this.message});

  /// Optional override for the default "nothing here" copy. Prefer a
  /// localization key resolved by the widget over a literal built in a bloc.
  final String? message;

  @override
  List<Object?> get props => [message];
}

final class ViewFailed<T> extends ViewState<T> {
  const ViewFailed(this.failure, {this.lastData});

  final Failure failure;

  /// What was on screen before the failure, so a retry banner can appear over
  /// stale content instead of replacing it with a full-screen error.
  final T? lastData;

  @override
  List<Object?> get props => [failure, lastData];
}
