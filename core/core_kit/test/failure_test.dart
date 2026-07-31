import 'package:core_kit/core_kit.dart';
import 'package:test/test.dart';

/// `Failure` is the closed set every layer above the transport switches over,
/// and two of its properties are load-bearing in ways that are invisible when
/// they break.
///
/// `isRetryable` decides whether a retry button is offered at all. `props`
/// decides whether `ViewFailed(failure) == ViewFailed(failure)` — which decides
/// whether a bloc re-emitting the same failure rebuilds the screen on every
/// emit. The deliberate exclusion of `cause` and `stackTrace` from `props` is
/// what makes that equality hold, and `make check-props` knows about it by
/// name; the tests below are what stop the exclusion from being widened by
/// accident to a field that does matter.
void main() {
  group('isRetryable', () {
    test('is true only for the transient transport failures', () {
      // Offering "try again" for a 403 tells the user to repeat something that
      // cannot start working. Withholding it after a timeout strands them.
      expect(const NetworkFailure().isRetryable, isTrue);
      expect(const TimeoutFailure().isRetryable, isTrue);
      expect(const ServerFailure().isRetryable, isTrue);
    });

    test('is false for everything a retry cannot fix', () {
      expect(const UnauthorizedFailure().isRetryable, isFalse);
      expect(const ForbiddenFailure().isRetryable, isFalse);
      expect(const NotFoundFailure().isRetryable, isFalse);
      expect(const ValidationFailure().isRetryable, isFalse);
      expect(const BusinessFailure().isRetryable, isFalse);
      expect(const CancelledFailure().isRetryable, isFalse);
      expect(const CacheFailure().isRetryable, isFalse);
      expect(const PermissionFailure(permission: 'camera').isRetryable, isFalse);
      expect(const UnexpectedFailure().isRetryable, isFalse);
    });
  });

  group('equality', () {
    test('two failures raised at different call sites are equal', () {
      // The reason `cause` and `stackTrace` are outside `props`. Each carries a
      // distinct `StackTrace` object and a `DioException` that compares by
      // identity, so including either would make every instance unique — and a
      // bloc re-emitting the same failure would rebuild the screen every time.
      final first = NetworkFailure(debugMessage: 'offline', cause: StateError('a'), stackTrace: StackTrace.current);
      final second = NetworkFailure(debugMessage: 'offline', cause: StateError('b'), stackTrace: StackTrace.current);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('runtimeType separates otherwise identical failures', () {
      // `NetworkFailure` and `TimeoutFailure` are field-for-field the same.
      // Without `runtimeType` in `props` they would compare equal, and a screen
      // showing "no connection" would never update to "took too long".
      expect(const NetworkFailure(debugMessage: 'x'), isNot(const TimeoutFailure(debugMessage: 'x')));
    });

    test('the shared fields all participate', () {
      const base = ServerFailure(debugMessage: 'm', code: 'C', traceId: 'T', statusCode: 500);

      expect(base, const ServerFailure(debugMessage: 'm', code: 'C', traceId: 'T', statusCode: 500));
      expect(base, isNot(const ServerFailure(debugMessage: 'other', code: 'C', traceId: 'T', statusCode: 500)));
      expect(base, isNot(const ServerFailure(debugMessage: 'm', code: 'OTHER', traceId: 'T', statusCode: 500)));
      expect(base, isNot(const ServerFailure(debugMessage: 'm', code: 'C', traceId: 'OTHER', statusCode: 500)));
      // The subclass field, which is the one a `[...super.props, x]` override
      // is easy to forget.
      expect(base, isNot(const ServerFailure(debugMessage: 'm', code: 'C', traceId: 'T', statusCode: 503)));
    });

    test('subclass fields participate for every subclass that adds one', () {
      expect(
        const ValidationFailure(
          fieldErrors: {
            'email': ['taken'],
          },
        ),
        isNot(
          const ValidationFailure(
            fieldErrors: {
              'email': ['invalid'],
            },
          ),
        ),
      );
      expect(
        const BusinessFailure(details: {'cooldownRemainingSeconds': 265}),
        isNot(const BusinessFailure(details: {'cooldownRemainingSeconds': 10})),
      );
      expect(const PermissionFailure(permission: 'camera'), isNot(const PermissionFailure(permission: 'location')));
      expect(
        const PermissionFailure(permission: 'camera'),
        isNot(const PermissionFailure(permission: 'camera', permanentlyDenied: true)),
      );
    });
  });

  test('toString carries the diagnostics without the payload', () {
    final text = const ServerFailure(debugMessage: 'boom', code: 'E_QUOTA', traceId: 'abc-123').toString();

    expect(text, contains('ServerFailure'));
    expect(text, contains('E_QUOTA'));
    expect(text, contains('abc-123'));
    expect(text, contains('boom'));
  });

  group('AppException', () {
    test('wraps a failure for the APIs that can only throw', () {
      const failure = UnauthorizedFailure(debugMessage: 'token expired');

      expect(const AppException(failure).failure, failure);
      expect(const AppException(failure).toString(), contains('UnauthorizedFailure'));
    });
  });

  group('PassthroughFailureMapper', () {
    const mapper = PassthroughFailureMapper();

    test('a Failure survives the trip unchanged', () {
      // Re-wrapping would erase the status code, business code and traceId that
      // something upstream already worked out.
      const original = ServerFailure(statusCode: 503, code: 'E_MAINTENANCE');

      expect(mapper.map(original, StackTrace.current), same(original));
    });

    test('anything else becomes UnexpectedFailure with its diagnostics kept', () {
      final error = StateError('boom');
      final stack = StackTrace.current;

      final mapped = mapper.map(error, stack);

      expect(mapped, isA<UnexpectedFailure>());
      expect(mapped.debugMessage, contains('boom'));
      expect(mapped.cause, same(error));
      expect(mapped.stackTrace, same(stack));
    });
  });
}
