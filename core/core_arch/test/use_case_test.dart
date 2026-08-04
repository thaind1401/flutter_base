import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:flutter_test/flutter_test.dart';

// `UseCase` is the base every business operation in the codebase extends, and
// rules 2 and 3 are both written in terms of it — yet `core_arch` shipped no
// test for it at all. The per-file coverage floor is what surfaced that: the
// package read 79% while this file sat at 20%.
//
// Nothing here is elaborate, and that is the point. These are the guarantees
// every use case inherits without restating them, so a change that breaks one
// breaks the whole app quietly.

final class _Echo extends UseCase<String, String> {
  const _Echo();

  @override
  Future<Result<String>> execute(String params) async => Ok('echo:$params');
}

final class _Ping extends NoParamsUseCase<int> {
  const _Ping();

  @override
  Future<Result<int>> execute(NoParams params) async => const Ok(1);
}

final class _Save extends CompletableUseCase<String> {
  const _Save(this.saved);

  final List<String> saved;

  @override
  Future<Result<Unit>> execute(String params) async {
    saved.add(params);
    return const Ok(unit);
  }
}

final class _Feed extends StreamUseCase<int, int> {
  const _Feed();

  @override
  Stream<Result<int>> execute(int params) => Stream.fromIterable([Ok(params), Ok(params + 1)]);
}

final class _Failing extends NoParamsUseCase<int> {
  const _Failing();

  @override
  Future<Result<int>> execute(NoParams params) async => const Err(UnexpectedFailure(debugMessage: 'nope'));
}

void main() {
  group('NoParams', () {
    test('two instances are equal, so a state holding one compares by value', () {
      // It exists as a type rather than a nullable parameter, which only works
      // if instances are interchangeable — otherwise a record or state carrying
      // `NoParams` never compares equal and `BlocSelector` rebuilds forever.
      expect(const NoParams(), const NoParams());
      expect(const NoParams().hashCode, const NoParams().hashCode);
    });

    test('is not equal to some other object', () {
      expect(const NoParams() == Object(), isFalse);
    });
  });

  group('call', () {
    test('forwards to execute', () async {
      // `useCase(params)` is how every call site invokes one; `execute` is
      // `@protected`. If the forwarding broke, nothing in the app would run.
      expect(await const _Echo()('hi'), const Ok('echo:hi'));
    });

    test('carries a failure rather than throwing', () async {
      // Rule 1 at its origin: a use case returns `Err`, so no bloc above it
      // needs a `try/catch`.
      final result = await const _Failing()(const NoParams());
      expect(result, isA<Err<int>>());
    });
  });

  test('NoParamsUseCase takes the marker instead of an optional argument', () async {
    expect(await const _Ping()(const NoParams()), const Ok(1));
  });

  test('CompletableUseCase returns Unit so failures still travel', () async {
    final saved = <String>[];
    final result = await _Save(saved)('row');

    expect(result, const Ok(unit));
    expect(saved, ['row']);
  });

  test('StreamUseCase emits each event as its own Result', () async {
    // The reason it is a `Stream<Result<R>>` and not a `Result<Stream<R>>`: a
    // mid-stream failure is one bad event, not a torn-down subscription.
    expect(await const _Feed()(7).toList(), [const Ok(7), const Ok(8)]);
  });
}
