import 'dart:io';

import 'package:core_kit/core_kit.dart';
import 'package:core_network/src/api_error_envelope.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// The one place a transport exception becomes a domain [Failure].
///
/// Nothing above the data layer knows Dio exists. Keeping this mapping in a
/// single injectable class — instead of a `handleError` method inherited by
/// every repository — means it is unit-testable on its own and a project can
/// override the status-code policy without touching repositories.
@LazySingleton(as: FailureMapper)
final class DioFailureMapper implements FailureMapper {
  const DioFailureMapper();

  @override
  Failure map(Object error, StackTrace stackTrace) {
    // A failure that a layer below already classified passes through untouched;
    // re-wrapping would erase its status code, business code and traceId.
    if (error is Failure) return error;
    if (error is AppException) return error.failure;
    if (error is DioException) return _fromDio(error, stackTrace);
    if (error is SocketException || error is HandshakeException) {
      return NetworkFailure(debugMessage: error.toString(), cause: error, stackTrace: stackTrace);
    }
    if (error is FormatException || error is TypeError) {
      // A parse error is a contract break between client and server, not a
      // transport problem. Surfacing it as ServerFailure keeps "retry" out of
      // the UI for something retrying will never fix.
      return ServerFailure(debugMessage: 'response parse failed: $error', cause: error, stackTrace: stackTrace);
    }
    return UnexpectedFailure(debugMessage: error.toString(), cause: error, stackTrace: stackTrace);
  }

  Failure _fromDio(DioException error, StackTrace stackTrace) {
    final debugMessage = error.message ?? error.error?.toString() ?? error.type.name;

    switch (error.type) {
      case DioExceptionType.cancel:
        return CancelledFailure(debugMessage: debugMessage, cause: error, stackTrace: stackTrace);

      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      // Response transformation ran past its budget — usually a huge JSON body
      // being decoded on the main isolate. Retrying is the right advice.
      case DioExceptionType.transformTimeout:
        return TimeoutFailure(debugMessage: debugMessage, cause: error, stackTrace: stackTrace);

      case DioExceptionType.connectionError:
        return NetworkFailure(debugMessage: debugMessage, cause: error, stackTrace: stackTrace);

      case DioExceptionType.badCertificate:
        // Deliberately not a NetworkFailure: a certificate mismatch can be an
        // interception attempt and must not be presented as "check your wifi".
        return ServerFailure(debugMessage: 'bad certificate: $debugMessage', cause: error, stackTrace: stackTrace);

      case DioExceptionType.badResponse:
        return _fromStatus(error, stackTrace);

      case DioExceptionType.unknown:
        final root = error.error;
        if (root is SocketException || root is HandshakeException) {
          return NetworkFailure(debugMessage: root.toString(), cause: error, stackTrace: stackTrace);
        }
        return UnexpectedFailure(debugMessage: debugMessage, cause: error, stackTrace: stackTrace);
    }
  }

  Failure _fromStatus(DioException error, StackTrace stackTrace) {
    final status = error.response?.statusCode;
    final envelope = ApiErrorEnvelope.parse(error.response?.data);
    final message = envelope.message ?? error.message ?? 'HTTP $status';
    final code = envelope.code;
    final traceId = envelope.traceId;

    return switch (status) {
      401 => UnauthorizedFailure(
        debugMessage: message,
        code: code,
        traceId: traceId,
        cause: error,
        stackTrace: stackTrace,
      ),
      403 => ForbiddenFailure(
        debugMessage: message,
        code: code,
        traceId: traceId,
        cause: error,
        stackTrace: stackTrace,
      ),
      404 => NotFoundFailure(debugMessage: message, code: code, traceId: traceId, cause: error, stackTrace: stackTrace),
      408 => TimeoutFailure(debugMessage: message, cause: error, stackTrace: stackTrace),
      422 => ValidationFailure(
        fieldErrors: envelope.fieldErrors,
        debugMessage: message,
        code: code,
        traceId: traceId,
        cause: error,
        stackTrace: stackTrace,
      ),
      // 4xx with a business code is a rule the domain rejected, not a bug.
      // Screens switch on `code` to show the specific copy.
      final int s when s >= 400 && s < 500 && code != null => BusinessFailure(
        details: envelope.errors,
        debugMessage: message,
        code: code,
        traceId: traceId,
        cause: error,
        stackTrace: stackTrace,
      ),
      _ => ServerFailure(
        statusCode: status,
        debugMessage: message,
        code: code,
        traceId: traceId,
        cause: error,
        stackTrace: stackTrace,
      ),
    };
  }
}
