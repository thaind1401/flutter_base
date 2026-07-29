import 'dart:io';

import 'package:core_kit/core_kit.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _badResponse(int status, {Object? body}) {
  final options = RequestOptions(path: '/v1/thing');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(requestOptions: options, statusCode: status, data: body),
  );
}

void main() {
  const mapper = DioFailureMapper();
  final stack = StackTrace.current;

  group('DioFailureMapper transport errors', () {
    test('maps every timeout variant to TimeoutFailure', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final error = DioException(
          requestOptions: RequestOptions(path: '/'),
          type: type,
        );
        expect(mapper.map(error, stack), isA<TimeoutFailure>(), reason: '$type');
      }
    });

    test('maps connectionError to NetworkFailure', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
      );
      expect(mapper.map(error, stack), isA<NetworkFailure>());
    });

    test('maps cancel to CancelledFailure so screens can stay silent', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.cancel,
      );
      expect(mapper.map(error, stack), isA<CancelledFailure>());
    });

    test('maps a bad certificate to ServerFailure, not NetworkFailure', () {
      // A cert mismatch may be interception; "check your connection" would be
      // the wrong thing to tell the user.
      final error = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badCertificate,
      );
      expect(mapper.map(error, stack), isA<ServerFailure>());
    });

    test('unwraps a SocketException hidden inside an unknown DioException', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.unknown,
        error: const SocketException('no route to host'),
      );
      expect(mapper.map(error, stack), isA<NetworkFailure>());
    });
  });

  group('DioFailureMapper status codes', () {
    test('401 becomes UnauthorizedFailure', () {
      expect(mapper.map(_badResponse(401), stack), isA<UnauthorizedFailure>());
    });

    test('403 becomes ForbiddenFailure and never logs the user out', () {
      final failure = mapper.map(_badResponse(403), stack);
      expect(failure, isA<ForbiddenFailure>());
      expect(failure, isNot(isA<UnauthorizedFailure>()));
    });

    test('404 becomes NotFoundFailure', () {
      expect(mapper.map(_badResponse(404), stack), isA<NotFoundFailure>());
    });

    test('422 carries field errors through to the form', () {
      final failure = mapper.map(
        _badResponse(
          422,
          body: {
            'message': 'Validation failed',
            'errors': {
              'email': ['is already taken'],
              'age': 'must be a number',
            },
          },
        ),
        stack,
      );
      expect(failure, isA<ValidationFailure>());
      final validation = failure as ValidationFailure;
      expect(validation.fieldErrors['email'], ['is already taken']);
      expect(validation.fieldErrors['age'], ['must be a number']);
    });

    test('4xx with a business code becomes BusinessFailure with its details', () {
      final failure = mapper.map(
        _badResponse(
          400,
          body: {
            'success': false,
            'code': 'LEAVE_REQUEST_COOLDOWN',
            'message': 'Please wait',
            'errors': {'cooldownRemainingSeconds': 265},
            'traceId': 'trace-123',
          },
        ),
        stack,
      );
      expect(failure, isA<BusinessFailure>());
      expect(failure.code, 'LEAVE_REQUEST_COOLDOWN');
      expect(failure.traceId, 'trace-123');
      expect((failure as BusinessFailure).details['cooldownRemainingSeconds'], 265);
    });

    test('4xx without a business code falls back to ServerFailure', () {
      final failure = mapper.map(_badResponse(400, body: {'message': 'Bad request'}), stack);
      expect(failure, isA<ServerFailure>());
    });

    test('5xx becomes a retryable ServerFailure carrying the status', () {
      final failure = mapper.map(_badResponse(503, body: {'message': 'maintenance'}), stack);
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, 503);
      expect(failure.isRetryable, isTrue);
    });

    test('parses an error envelope delivered as a raw JSON string', () {
      final failure = mapper.map(_badResponse(400, body: '{"code":"X","message":"boom"}'), stack);
      expect(failure.code, 'X');
      expect(failure.debugMessage, 'boom');
    });

    test('survives an HTML body from a proxy', () {
      final failure = mapper.map(_badResponse(502, body: '<html><body>Bad gateway</body></html>'), stack);
      expect(failure, isA<ServerFailure>());
      expect(failure.debugMessage, contains('Bad gateway'));
    });

    test('survives a null body', () {
      expect(mapper.map(_badResponse(500), stack), isA<ServerFailure>());
    });
  });

  group('DioFailureMapper non-Dio errors', () {
    test('passes an already-classified Failure through unchanged', () {
      const original = BusinessFailure(code: 'ALREADY_MAPPED');
      expect(mapper.map(original, stack), same(original));
    });

    test('unwraps an AppException without losing its failure', () {
      const original = UnauthorizedFailure(traceId: 't-1');
      expect(mapper.map(const AppException(original), stack), same(original));
    });

    test('treats a decode failure as a contract break, not a network blip', () {
      final failure = mapper.map(const FormatException('unexpected token'), stack);
      expect(failure, isA<ServerFailure>());
      expect(failure.isRetryable, isTrue);
    });

    test('anything else becomes UnexpectedFailure', () {
      expect(mapper.map(StateError('nope'), stack), isA<UnexpectedFailure>());
    });
  });
}
