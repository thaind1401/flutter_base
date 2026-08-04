import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Every way a call can fail, as a closed set.
///
/// Why sealed: the compiler tells you when a `switch` over failures misses a
/// case. The previous generation of this codebase threw ad-hoc exception
/// subclasses, so a new failure type silently fell through to a generic
/// "something went wrong" toast until QA found it.
///
/// A [Failure] is **not** user-facing. [debugMessage] is for logs and crash
/// reports. Presentation resolves the localized copy from the failure's *type*
/// (see `FailureMessageResolver` in `core_ui`), never from this string.
@immutable
sealed class Failure extends Equatable {
  const Failure({this.debugMessage = '', this.code, this.traceId, this.cause, this.stackTrace});

  /// Technical detail for logs. Never render this to a user.
  final String debugMessage;

  /// Business error code from the backend envelope (`{ code: "..." }`), when
  /// the server supplied one. Screens key their special-case copy off this.
  final String? code;

  /// Correlation id echoed by the backend; goes into bug reports.
  final String? traceId;

  /// The original error object, kept for crash reporting.
  final Object? cause;

  final StackTrace? stackTrace;

  /// Whether retrying the exact same call could plausibly succeed.
  bool get isRetryable => switch (this) {
    NetworkFailure() || TimeoutFailure() || ServerFailure() => true,
    _ => false,
  };

  /// `cause` and `stackTrace` are **deliberately absent**, and `runtimeType` is
  /// deliberately present.
  ///
  /// Two `NetworkFailure`s raised at different call sites carry different
  /// `StackTrace` objects, and `cause` is whatever the transport threw — a
  /// `DioException` compares by identity. Including either would make every
  /// failure instance unique, so `ViewFailed(failure) == ViewFailed(failure)`
  /// would be false and a bloc re-emitting the same failure would rebuild the
  /// screen every time. They are diagnostics, not identity.
  ///
  /// `runtimeType` is what separates a `NetworkFailure` from a `TimeoutFailure`,
  /// which are otherwise field-for-field identical.
  ///
  /// `make check-props` knows about this exclusion by name; adding a field here
  /// without listing it fails that check.
  @override
  List<Object?> get props => [runtimeType, debugMessage, code, traceId];

  @override
  String toString() => '$runtimeType(code: $code, traceId: $traceId, message: $debugMessage)';
}

/// Device is offline, DNS failed, or the socket never opened.
final class NetworkFailure extends Failure {
  const NetworkFailure({super.debugMessage, super.cause, super.stackTrace});
}

/// The request opened but did not complete in time.
final class TimeoutFailure extends Failure {
  const TimeoutFailure({super.debugMessage, super.cause, super.stackTrace});
}

/// 5xx, or a response the client cannot parse.
final class ServerFailure extends Failure {
  const ServerFailure({this.statusCode, super.debugMessage, super.code, super.traceId, super.cause, super.stackTrace});

  final int? statusCode;

  @override
  List<Object?> get props => [...super.props, statusCode];
}

/// 401. The session gate listens for this and drops the user to login.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.debugMessage, super.code, super.traceId, super.cause, super.stackTrace});
}

/// 403. Authenticated but not permitted — never a reason to log the user out.
final class ForbiddenFailure extends Failure {
  const ForbiddenFailure({super.debugMessage, super.code, super.traceId, super.cause, super.stackTrace});
}

/// 404, or a lookup that returned nothing where something was required.
final class NotFoundFailure extends Failure {
  const NotFoundFailure({super.debugMessage, super.code, super.traceId, super.cause, super.stackTrace});
}

/// 422-style field validation rejected by the server.
final class ValidationFailure extends Failure {
  const ValidationFailure({
    this.fieldErrors = const {},
    super.debugMessage,
    super.code,
    super.traceId,
    super.cause,
    super.stackTrace,
  });

  /// Field name -> messages, as returned by the backend.
  final Map<String, List<String>> fieldErrors;

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

/// The request was technically fine; the domain rejected it (quota exceeded,
/// cooldown active, state transition not allowed). [code] carries which rule.
final class BusinessFailure extends Failure {
  const BusinessFailure({
    this.details = const {},
    super.debugMessage,
    super.code,
    super.traceId,
    super.cause,
    super.stackTrace,
  });

  /// The backend's `errors` object, e.g. `{cooldownRemainingSeconds: 265}`.
  final Map<String, Object?> details;

  @override
  List<Object?> get props => [...super.props, details];
}

/// Caller cancelled — a user navigating away, a debounced search superseded.
/// Screens must swallow this silently rather than showing an error.
final class CancelledFailure extends Failure {
  const CancelledFailure({super.debugMessage, super.cause, super.stackTrace});
}

/// Local persistence failed (keystore locked, disk full, corrupt payload).
final class CacheFailure extends Failure {
  const CacheFailure({super.debugMessage, super.cause, super.stackTrace});
}

/// A permission the feature requires was denied by the OS.
final class PermissionFailure extends Failure {
  const PermissionFailure({
    required this.permission,
    this.permanentlyDenied = false,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  final String permission;

  /// True when the OS will no longer prompt; the UI must deep-link to settings.
  final bool permanentlyDenied;

  @override
  List<Object?> get props => [...super.props, permission, permanentlyDenied];
}

/// Nothing above matched. Treat every occurrence as a bug to triage — if a
/// failure mode is expected, it deserves its own case in this file.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure({super.debugMessage, super.cause, super.stackTrace});
}
