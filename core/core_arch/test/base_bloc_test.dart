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

    test('an effect emitted before anything subscribes is replayed, not dropped', () async {
      // The bug: `effects` is a broadcast stream, and a broadcast stream
      // discards whatever is added while nobody is listening.
      // `BlocEffectListener` does not subscribe until its first build, so an
      // effect emitted from a cubit method called in `initState` — or by
      // `SessionCubit` during `Bootstrap.run()`, before a widget tree exists at
      // all — disappeared with no error and nothing in the logs.
      //
      // Rule 4 routes *every* one-shot outcome through this channel, so "the
      // toast simply never appeared" was a supported way to use it.
      final bloc = _CounterBloc();
      bloc.emitLateEffect('before');

      final received = <Object>[];
      final subscription = bloc.effects.listen(received.add);
      await Future<void>.delayed(Duration.zero);

      expect(received, ['before']);

      await subscription.cancel();
      await bloc.close();
    });

    test('replayed effects keep their order, ahead of anything emitted after', () async {
      final bloc = _CounterBloc();
      bloc
        ..emitLateEffect('first')
        ..emitLateEffect('second');

      final received = <Object>[];
      final subscription = bloc.effects.listen(received.add);
      await Future<void>.delayed(Duration.zero);
      bloc.emitLateEffect('third');
      await Future<void>.delayed(Duration.zero);

      expect(received, ['first', 'second', 'third']);

      await subscription.cancel();
      await bloc.close();
    });

    test('the buffer is not re-armed once a listener has come and gone', () async {
      // Deliberate, and the reason this is not "buffer whenever nobody is
      // listening": a singleton outliving its screen — `SessionCubit` is one —
      // would otherwise pile up effects while the app sits in the background
      // and dump the backlog on whatever screen mounts next. A one-shot effect
      // from ten minutes ago is worse than a lost one.
      final bloc = _CounterBloc();
      final first = <Object>[];
      final subscription = bloc.effects.listen(first.add);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      bloc.emitLateEffect('while nobody is watching');

      final second = <Object>[];
      final resubscribed = bloc.effects.listen(second.add);
      await Future<void>.delayed(Duration.zero);

      expect(second, isEmpty, reason: 'a stale one-shot effect was resurrected');

      await resubscribed.cancel();
      await bloc.close();
    });

    test('a bloc signalling into a tree that is not there fails loudly', () async {
      // The buffer is bounded, and overflowing it is a design error rather than
      // a load problem: effects are for outcomes a screen reacts to, so dozens
      // of them with no listener means nothing is ever going to.
      //
      // Asserted as the throw rather than as the truncated list, because debug
      // is where these tests and the app both run — the cap that keeps release
      // bounded is the fallback, not the behaviour anyone should meet.
      final bloc = _CounterBloc();

      expect(() {
        for (var i = 0; i <= BlocLifecycle.maxPendingEffects; i++) {
          bloc.emitLateEffect(i);
        }
      }, throwsA(isA<AssertionError>()));

      await bloc.close();
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
