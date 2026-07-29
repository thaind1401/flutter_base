import 'dart:async';

import 'package:core_kit/core_kit.dart';
import 'package:meta/meta.dart';

/// Marker for a use case that needs no input.
///
/// Deliberately a type rather than a nullable parameter. The previous
/// generation declared `Future<R> call([P? params])`, which made every use case
/// accept `null` — so a required parameter could be omitted at a call site and
/// only blew up at runtime, inside the repository. `NoParams` restores the
/// compiler's ability to check the call.
@immutable
final class NoParams {
  const NoParams();

  @override
  bool operator ==(Object other) => other is NoParams;

  @override
  int get hashCode => 0;
}

/// One business operation. The only unit the presentation layer may call.
///
/// Deliberately not a `base` class: test suites that use mocktail or mockito
/// need to `implements` a use case, and sealing the hierarchy would force every
/// test to construct the real thing with a fake repository underneath it.
///
/// Rules the whole codebase relies on:
///   * **returns `Result`, never throws** — the repository already converted
///     exceptions, so a bloc needs no `try/catch`;
///   * **parameters are a typed record or a value class**, never a
///     `Map<String, dynamic>` — an untyped body pushes field-name bugs to
///     runtime and hides the contract from every reader;
///   * **no `BuildContext`, no widgets, no `Dio`** — a use case is testable
///     with plain `dart test` plus a fake repository.
///
/// ```dart
/// typedef SignInParams = ({String email, String password});
///
/// @injectable
/// final class SignInUseCase extends UseCase<SignInParams, Session> {
///   const SignInUseCase(this._repository);
///   final AuthRepository _repository;
///
///   @override
///   Future<Result<Session>> execute(SignInParams params) =>
///       _repository.signIn(email: params.email, password: params.password);
/// }
/// ```
abstract class UseCase<P, R> {
  const UseCase();

  /// The implementation. Never call this directly — call the instance.
  @protected
  Future<Result<R>> execute(P params);

  /// `useCase(params)` reads better than `useCase.execute(params)` and gives
  /// this base a single place to add cross-cutting behaviour later.
  Future<Result<R>> call(P params) => execute(params);
}

/// A use case with no input: `await refreshProfile(const NoParams())`.
abstract class NoParamsUseCase<R> extends UseCase<NoParams, R> {
  const NoParamsUseCase();
}

/// Completes with no payload. Returns `Result<Unit>` so failures still travel.
abstract class CompletableUseCase<P> extends UseCase<P, Unit> {
  const CompletableUseCase();
}

/// A use case that emits over time — a websocket feed, a location stream, a
/// watched cache. Each event is a `Result`, so a mid-stream failure does not
/// tear the subscription down.
abstract class StreamUseCase<P, R> {
  const StreamUseCase();

  @protected
  Stream<Result<R>> execute(P params);

  Stream<Result<R>> call(P params) => execute(params);
}
