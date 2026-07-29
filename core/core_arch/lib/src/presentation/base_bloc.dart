import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:core_kit/core_kit.dart';
import 'package:meta/meta.dart';

/// Shared behaviour for every bloc and cubit in the app.
///
/// What it buys, none of which should be re-implemented per feature:
///   * [safeEmit] — emitting after close is the single most common crash in a
///     bloc codebase (a debounce timer, a late network response, a stream that
///     outlived its screen). It becomes a no-op instead of an exception.
///   * [listenTo] — subscriptions are cancelled on close automatically, so a
///     forgotten `cancel()` cannot leak a listener for the app's lifetime.
///   * [emitEffect] — one-shot side effects (navigate, toast, close sheet) as a
///     stream, not as flags smuggled through state. A flag has to be cleared,
///     and if it is not, the toast fires again on every rebuild.
mixin BlocLifecycle<State> on BlocBase<State> {
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final StreamController<Object> _effects = StreamController<Object>.broadcast();

  /// One-shot side effects. Listened to by `BlocEffectListener` in `core_ui`.
  Stream<Object> get effects => _effects.stream;

  /// Emits only while the bloc is open.
  @protected
  void safeEmit(State state) {
    if (isClosed) return;
    emit(state);
  }

  @protected
  void emitEffect(Object effect) {
    if (isClosed || _effects.isClosed) return;
    _effects.add(effect);
  }

  /// Subscribes and registers the subscription for automatic cancellation.
  @protected
  StreamSubscription<T> listenTo<T>(
    Stream<T> stream,
    void Function(T event) onData, {
    Function? onError,
    void Function()? onDone,
  }) {
    final subscription = stream.listen(onData, onError: onError, onDone: onDone);
    _subscriptions.add(subscription);
    return subscription;
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _effects.close();
    return super.close();
  }
}

/// Base class for event-driven blocs.
///
/// Note what is *not* here: this deliberately does not register a
/// `WidgetsBindingObserver`. The previous generation did so in its bloc base,
/// which meant every bloc in the app — dozens at once — received every
/// lifecycle callback whether it cared or not. Blocs that need lifecycle now
/// opt in with [AppLifecycleAware].
abstract class BaseBloc<Event, State> extends Bloc<Event, State> with BlocLifecycle<State> {
  BaseBloc(super.initialState, {AppLogger logger = const NoopLogger()}) : _logger = logger;

  final AppLogger _logger;

  @protected
  AppLogger get logger => _logger;
}

abstract class BaseCubit<State> extends Cubit<State> with BlocLifecycle<State> {
  BaseCubit(super.initialState, {AppLogger logger = const NoopLogger()}) : _logger = logger;

  final AppLogger _logger;

  @protected
  AppLogger get logger => _logger;
}
