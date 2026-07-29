import 'package:core_kit/src/error/failure.dart';

/// Turns an arbitrary thrown object into a [Failure].
///
/// Declared in `core_kit` so that `core_arch`'s repository base can require one
/// without depending on `core_network`. The Dio implementation lives next to
/// Dio; a GraphQL or gRPC transport supplies its own without any other layer
/// changing.
abstract interface class FailureMapper {
  Failure map(Object error, StackTrace stackTrace);
}

/// Fallback used by tests and by repositories with no transport of their own.
final class PassthroughFailureMapper implements FailureMapper {
  const PassthroughFailureMapper();

  @override
  Failure map(Object error, StackTrace stackTrace) {
    if (error is Failure) return error;
    return UnexpectedFailure(debugMessage: error.toString(), cause: error, stackTrace: stackTrace);
  }
}
