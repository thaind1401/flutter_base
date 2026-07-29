import 'dart:async';

import 'package:core_kit/src/error/app_exception.dart';
import 'package:core_kit/src/error/failure.dart';
import 'package:core_kit/src/result/unit.dart';
import 'package:meta/meta.dart';

/// The outcome of an operation that can fail: either [Ok] or [Err].
///
/// Why this instead of throwing: a thrown exception is invisible in a function
/// signature, so the compiler cannot tell a caller they forgot to handle a
/// failure. `Result` puts the failure in the return type, and because [Failure]
/// is sealed, an exhaustive `switch` is checked at compile time.
///
/// Rule for the whole codebase: **anything returning `Result` never throws.**
/// Repositories convert exceptions at their boundary (see `Result.guard`).
///
/// ```dart
/// final result = await getProfileUseCase(const NoParams());
/// switch (result) {
///   case Ok(:final value):  emit(Loaded(value));
///   case Err(:final failure): emit(LoadFailed(failure));
/// }
/// ```
@immutable
sealed class Result<T> {
  const Result();

  /// Runs [body] and converts any thrown object into an [Err].
  ///
  /// [onError] maps the caught object to a [Failure]; without it, an
  /// [AppException] passes its failure through untouched and everything else
  /// becomes [UnexpectedFailure]. Repositories supply a real mapper so that a
  /// `DioException` does not reach the domain layer.
  static Result<T> guard<T>(T Function() body, {Failure Function(Object error, StackTrace stackTrace)? onError}) {
    try {
      return Ok<T>(body());
    } catch (error, stackTrace) {
      return Err<T>(_toFailure(error, stackTrace, onError));
    }
  }

  /// Async twin of [guard]. This is the boundary every repository call goes
  /// through, and the reason no `try/catch` appears in a use case or a bloc.
  static Future<Result<T>> guardAsync<T>(
    FutureOr<T> Function() body, {
    Failure Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    try {
      return Ok<T>(await body());
    } catch (error, stackTrace) {
      return Err<T>(_toFailure(error, stackTrace, onError));
    }
  }

  static Failure _toFailure(
    Object error,
    StackTrace stackTrace,
    Failure Function(Object error, StackTrace stackTrace)? onError,
  ) {
    // A failure something already classified must survive the trip unchanged;
    // re-wrapping it would erase its status code, business code and traceId.
    if (error is AppException) return error.failure;
    if (error is Failure) return error;
    if (onError != null) return onError(error, stackTrace);
    return UnexpectedFailure(debugMessage: error.toString(), cause: error, stackTrace: stackTrace);
  }

  /// Collapses a list of results into a single result holding every value,
  /// short-circuiting on the first failure.
  static Result<List<T>> collect<T>(Iterable<Result<T>> results) {
    final values = <T>[];
    for (final result in results) {
      switch (result) {
        case Ok<T>(:final value):
          values.add(value);
        case Err<T>(:final failure):
          return Err<List<T>>(failure);
      }
    }
    return Ok<List<T>>(values);
  }

  bool get isOk => this is Ok<T>;

  bool get isErr => this is Err<T>;

  /// The value, or null when this is an [Err]. Prefer `switch` — this loses the
  /// failure and is only appropriate where the caller genuinely does not care.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  T getOrElse(T Function(Failure failure) orElse) => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>(:final failure) => orElse(failure),
  };

  /// Exhaustive handling of both branches. Equivalent to a `switch`, kept for
  /// expression position where a statement would be awkward.
  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) => switch (this) {
    Ok<T>(:final value) => onOk(value),
    Err<T>(:final failure) => onErr(failure),
  };

  /// Transforms the success value; a failure passes through untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok<R>(transform(value)),
    Err<T>(:final failure) => Err<R>(failure),
  };

  /// Chains another fallible step. Use this instead of nesting `switch`es when
  /// a use case composes several repository calls.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => transform(value),
    Err<T>(:final failure) => Err<R>(failure),
  };

  /// Async [flatMap], for composing awaited steps inside a use case.
  Future<Result<R>> flatMapAsync<R>(FutureOr<Result<R>> Function(T value) transform) async => switch (this) {
    Ok<T>(:final value) => await transform(value),
    Err<T>(:final failure) => Err<R>(failure),
  };

  /// Rewrites the failure — e.g. turning a generic [NotFoundFailure] from a
  /// shared data source into a domain-specific one.
  Result<T> mapErr(Failure Function(Failure failure) transform) => switch (this) {
    Ok<T>() => this,
    Err<T>(:final failure) => Err<T>(transform(failure)),
  };

  /// Fires [action] for a success without changing the result. For logging and
  /// cache writes that must not alter the flow.
  // Returning `this` is the point: these are pass-through taps meant to be
  // chained between map/flatMap steps, so `avoid_returning_this` is waived here.
  Result<T> onOk(void Function(T value) action) {
    if (this case Ok<T>(:final value)) action(value);
    // ignore: avoid_returning_this
    return this;
  }

  Result<T> onErr(void Function(Failure failure) action) {
    if (this case Err<T>(:final failure)) action(failure);
    // ignore: avoid_returning_this
    return this;
  }

  /// Discards the value, keeping only success/failure. Handy when a caller only
  /// needs to know that a write went through.
  Result<Unit> asUnit() => map((_) => unit);
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok<T>, value);

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err<T>, failure);

  @override
  String toString() => 'Err($failure)';
}

/// Extensions for the common `Future<Result<T>>` shape, so callers can chain
/// without an intermediate `await` on every line.
extension FutureResultX<T> on Future<Result<T>> {
  Future<Result<R>> mapAsync<R>(R Function(T value) transform) async => (await this).map(transform);

  Future<Result<R>> flatMapAsync<R>(FutureOr<Result<R>> Function(T value) transform) async =>
      (await this).flatMapAsync(transform);

  Future<Result<T>> mapErrAsync(Failure Function(Failure failure) transform) async => (await this).mapErr(transform);

  Future<T> getOrElseAsync(T Function(Failure failure) orElse) async => (await this).getOrElse(orElse);
}
