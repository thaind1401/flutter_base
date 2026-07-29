import 'package:core_kit/src/error/failure.dart';

/// Escape hatch for carrying a [Failure] across an API that can only throw.
///
/// The architecture's default is `Result<T>`; anything that returns a Result
/// must not throw. This exists for the two places where throwing is the only
/// option: inside a `Result.guard` body, and inside third-party callbacks
/// (Dio interceptors, stream transformers) whose signature is fixed.
final class AppException implements Exception {
  const AppException(this.failure);

  final Failure failure;

  @override
  String toString() => 'AppException(${failure.toString()})';
}
