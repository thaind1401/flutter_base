import 'dart:async';

import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:flutter_test/flutter_test.dart';

sealed class _Event {}

final class _Increment extends _Event {}

final class _EmitEffect extends _Event {}

final class _CounterBloc extends BaseBloc<_Event, int> {
  _CounterBloc({Stream<int>? source}) : super(0) {
    on<_Increment>((event, emit) => emit(state + 1));
    on<_EmitEffect>((event, emit) => emitEffect('boom'));
    if (source != null) listenTo(source, safeEmit);
  }

  /// Simulates a late callback firing after the screen is gone.
  void emitLate(int value) => safeEmit(value);

  void emitLateEffect(Object effect) => emitEffect(effect);
}

final class _EchoRepository extends BaseRepository {
  _EchoRepository(super.failureMapper, {this.throws});

  final Object? throws;

  Future<Result<String>> load() => guard(() async {
    if (throws != null) throw throws!;
    return 'ok';
  });

  Future<Result<String>> loadWithFallback({required Failure raise, required String cached}) =>
      guardWithFallback(() async => throw AppException(raise), fallback: (_) async => Ok(cached));
}

typedef _DoubleParams = ({int value});

final class _DoubleUseCase extends UseCase<_DoubleParams, int> {
  const _DoubleUseCase();

  @override
  Future<Result<int>> execute(_DoubleParams params) async => Ok(params.value * 2);
}

void main() {
  group('BlocLifecycle', () {
    test('safeEmit after close is a no-op instead of a crash', () async {
      final bloc = _CounterBloc();
      await bloc.close();
      expect(() => bloc.emitLate(9), returnsNormally);
    });

    test('cancels registered subscriptions on close', () async {
      final controller = StreamController<int>();
      final bloc = _CounterBloc(source: controller.stream);

      controller.add(5);
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state, 5);

      await bloc.close();
      // With the subscription still live this would throw on emit.
      controller.add(6);
      await Future<void>.delayed(Duration.zero);
      expect(controller.hasListener, isFalse);
      await controller.close();
    });

    test('effects are delivered as one-shot events', () async {
      final bloc = _CounterBloc();
      final received = <Object>[];
      final subscription = bloc.effects.listen(received.add);

      bloc.add(_EmitEffect());
      await Future<void>.delayed(Duration.zero);

      expect(received, ['boom']);
      await subscription.cancel();
      await bloc.close();
    });

    test('emitting an effect after close does not throw', () async {
      // The realistic trigger is an awaited network call completing after the
      // screen was popped, not an `add` — bloc rejects those by design.
      final bloc = _CounterBloc();
      await bloc.close();
      expect(() => bloc.emitLateEffect('late'), returnsNormally);
    });
  });

  group('BaseRepository', () {
    const mapper = PassthroughFailureMapper();

    test('guard returns Ok for a clean call', () async {
      expect(await _EchoRepository(mapper).load(), const Ok<String>('ok'));
    });

    test('guard converts a throw into a Failure via the injected mapper', () async {
      final result = await _EchoRepository(mapper, throws: StateError('boom')).load();
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });

    test('guardWithFallback serves the cache for a retryable failure', () async {
      final result = await _EchoRepository(mapper).loadWithFallback(raise: const NetworkFailure(), cached: 'cached');
      expect(result, const Ok<String>('cached'));
    });

    test('guardWithFallback does not hide an auth failure behind the cache', () async {
      // A 401 must reach the session gate; serving stale data would leave the
      // user in a signed-out app that looks signed in.
      final result = await _EchoRepository(
        mapper,
      ).loadWithFallback(raise: const UnauthorizedFailure(), cached: 'cached');
      expect(result.failureOrNull, isA<UnauthorizedFailure>());
    });
  });

  group('UseCase', () {
    test('is callable and returns a Result', () async {
      expect(await const _DoubleUseCase()((value: 21)), const Ok<int>(42));
    });
  });
}
