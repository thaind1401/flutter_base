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
///     and if it is not, the toast fires again on every rebuild. Effects emitted
///     before the first subscriber are held and replayed rather than dropped;
///     see [_pendingEffects] for why that is bounded to the first subscriber
///     only.
mixin BlocLifecycle<State> on BlocBase<State> {
  /// How many effects are held for a bloc nothing has subscribed to yet.
  ///
  /// Reaching it means a bloc is emitting one-shot effects into a tree that has
  /// no listener, which is a design error rather than a load problem — hence the
  /// assert. Release builds drop the oldest instead of growing without bound.
  static const int maxPendingEffects = 32;

  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// Effects emitted before the first subscriber arrived.
  ///
  /// A broadcast stream discards anything added while nobody is listening, and
  /// `BlocEffectListener` does not subscribe until `didChangeDependencies` — its
  /// first build. So an effect emitted any earlier used to vanish with no error
  /// and nothing in the logs: a cubit method called from `initState`, or
  /// `SessionCubit` reacting during `Bootstrap.run()`, which happens before a
  /// widget tree exists at all. Rule 4 requires *every* one-shot outcome to go
  /// through this channel, so "the toast simply never appeared" was a supported
  /// way to use it.
  final List<Object> _pendingEffects = [];

  bool _hasEverListened = false;

  late final StreamController<Object> _effects = StreamController<Object>.broadcast(onListen: _flushPendingEffects);

  /// One-shot side effects. Listened to by `BlocEffectListener` in `core_ui`.
  Stream<Object> get effects => _effects.stream;

  /// Replays what was emitted before anyone was listening — **once**.
  ///
  /// Deliberately not "buffer whenever there is no listener". A singleton that
  /// outlives its screen — `SessionCubit` is one — would then accumulate effects
  /// while the app sits in the background and fire the whole backlog at whatever
  /// screen mounts next. A one-shot effect from ten minutes ago is worse than a
  /// lost one: the user gets a toast about something they have already moved on
  /// from. Only the start-up race is repaired; after the first listener, plain
  /// broadcast semantics apply.
  void _flushPendingEffects() {
    if (_hasEverListened) return;
    _hasEverListened = true;
    if (_pendingEffects.isEmpty) return;

    final pending = List<Object>.of(_pendingEffects);
    _pendingEffects.clear();

    // `onListen` runs synchronously inside `listen()`, before the subscription
    // is handed back, so adding here would deliver into the gap this exists to
    // close. A microtask puts delivery after `listen()` returns.
    scheduleMicrotask(() {
      if (_effects.isClosed) return;
      for (final effect in pending) {
        _effects.add(effect);
      }
    });
  }

  /// Emits only while the bloc is open.
  @protected
  void safeEmit(State state) {
    if (isClosed) return;
    emit(state);
  }

  @protected
  void emitEffect(Object effect) {
    if (isClosed || _effects.isClosed) return;

    if (!_hasEverListened) {
      assert(
        _pendingEffects.length < maxPendingEffects,
        'More than $maxPendingEffects effects were emitted by $runtimeType before anything '
        'listened. Effects are for one-shot outcomes a screen reacts to; a bloc producing '
        'this many with no listener is signalling into a tree that is not there.',
      );
      if (_pendingEffects.length >= maxPendingEffects) _pendingEffects.removeAt(0);
      _pendingEffects.add(effect);
      return;
    }

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
    // Anything still waiting for a listener that never arrived. Closing without
    // this would leave the list alive for as long as something holds the bloc.
    _pendingEffects.clear();
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
