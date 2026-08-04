import 'package:core_kit/core_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    test('Ok carries the value and reports isOk', () {
      const result = Ok<int>(42);
      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('Err carries the failure', () {
      const result = Err<int>(NetworkFailure(debugMessage: 'offline'));
      expect(result.isErr, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isA<NetworkFailure>());
    });

    test('map transforms Ok and passes Err through', () {
      expect(const Ok<int>(2).map((v) => v * 2), const Ok<int>(4));
      const failure = TimeoutFailure();
      expect(const Err<int>(failure).map((v) => v * 2), const Err<int>(failure));
    });

    test('flatMap short-circuits on the first failure', () {
      const failure = NotFoundFailure();
      final result = const Ok<int>(1).flatMap<int>((_) => const Err<int>(failure)).flatMap<int>((v) => Ok<int>(v + 1));
      expect(result, const Err<int>(failure));
    });

    test('fold picks the matching branch', () {
      expect(const Ok<int>(1).fold((v) => 'ok', (f) => 'err'), 'ok');
      expect(const Err<int>(CacheFailure()).fold((v) => 'ok', (f) => 'err'), 'err');
    });

    test('mapErr rewrites only failures', () {
      final mapped = const Err<int>(ServerFailure()).mapErr((_) => const UnauthorizedFailure());
      expect(mapped.failureOrNull, isA<UnauthorizedFailure>());
      expect(const Ok<int>(1).mapErr((_) => const UnauthorizedFailure()), const Ok<int>(1));
    });

    test('collect returns every value or the first failure', () {
      expect(Result.collect<int>(const [Ok(1), Ok(2)]).valueOrNull, [1, 2]);
      expect(Result.collect<int>(const [Ok(1), Err(CacheFailure()), Ok(3)]).failureOrNull, isA<CacheFailure>());
    });

    test('guard converts a throw into UnexpectedFailure', () {
      final result = Result.guard<int>(() => throw StateError('boom'));
      expect(result.failureOrNull, isA<UnexpectedFailure>());
      expect(result.failureOrNull!.debugMessage, contains('boom'));
    });

    test('guard preserves an already-classified failure instead of re-wrapping it', () {
      const original = UnauthorizedFailure(code: 'TOKEN_EXPIRED', traceId: 'abc');
      final result = Result.guard<int>(() => throw const AppException(original));
      expect(result.failureOrNull, same(original));
    });

    test('guard applies the supplied mapper to unknown errors', () {
      final result = Result.guard<int>(
        () => throw const FormatException('bad json'),
        onError: (e, s) => ServerFailure(statusCode: 500, debugMessage: e.toString()),
      );
      expect(result.failureOrNull, isA<ServerFailure>());
    });

    test('guardAsync captures async throws', () async {
      final result = await Result.guardAsync<int>(() async => throw StateError('async boom'));
      expect(result.isErr, isTrue);
    });

    test('onOk and onErr run side effects without changing the result', () {
      var okCount = 0;
      var errCount = 0;
      const Ok<int>(1).onOk((_) => okCount++).onErr((_) => errCount++);
      const Err<int>(CacheFailure()).onOk((_) => okCount++).onErr((_) => errCount++);
      expect(okCount, 1);
      expect(errCount, 1);
    });

    test('asUnit discards the payload', () {
      expect(const Ok<int>(7).asUnit(), const Ok<Unit>(unit));
    });
  });

  // `Failure` itself moved to failure_test.dart — retryability, the deliberate
  // exclusion of `cause`/`stackTrace` from `props`, and the per-subclass equality
  // cases belong next to each other rather than as a coda to `Result`.
}
