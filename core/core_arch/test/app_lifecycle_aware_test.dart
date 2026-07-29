import 'package:core_arch/core_arch.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mixin exists so that only the blocs that need lifecycle events pay for
/// them — the previous generation registered an observer per bloc and every
/// transition walked the whole list. What matters here is that opting in
/// actually delivers, and that opting in does not leak an observer past close.

final class _LifecycleBloc extends BaseCubit<int> with WidgetsBindingObserver, AppLifecycleAware<int> {
  _LifecycleBloc({bool observe = true}) : super(0) {
    if (observe) observeLifecycle();
  }

  final List<String> calls = [];

  /// Re-exposed because [observeLifecycle] is protected; a test needs to prove
  /// calling it twice does not register a second observer.
  void observeAgain() => observeLifecycle();

  @override
  void onAppResumed() => calls.add('resumed');

  @override
  void onAppInactive() => calls.add('inactive');

  @override
  void onAppPaused() => calls.add('paused');

  @override
  void onAppDetached() => calls.add('detached');

  @override
  void onAppHidden() => calls.add('hidden');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Drives the real binding rather than calling the callback directly, so the
  /// test proves the observer is registered and not merely that a switch works.
  void send(AppLifecycleState state) => TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(state);

  test('every lifecycle state reaches its hook', () {
    final bloc = _LifecycleBloc();
    addTearDown(bloc.close);

    send(AppLifecycleState.inactive);
    send(AppLifecycleState.hidden);
    send(AppLifecycleState.paused);
    send(AppLifecycleState.resumed);

    expect(bloc.calls, ['inactive', 'hidden', 'paused', 'resumed']);
  });

  test('detached is delivered', () {
    // Reached through hidden/paused first: the framework rejects an illegal
    // transition, so sending detached cold would assert.
    final bloc = _LifecycleBloc();
    addTearDown(bloc.close);

    send(AppLifecycleState.inactive);
    send(AppLifecycleState.hidden);
    send(AppLifecycleState.paused);
    send(AppLifecycleState.detached);

    expect(bloc.calls.last, 'detached');
  });

  test('a bloc that never opts in receives nothing', () {
    // The entire point of the mixin being opt-in.
    final bloc = _LifecycleBloc(observe: false);
    addTearDown(bloc.close);

    send(AppLifecycleState.inactive);
    send(AppLifecycleState.resumed);

    expect(bloc.calls, isEmpty);
  });

  test('opting in twice registers one observer, not two', () {
    final bloc = _LifecycleBloc();
    addTearDown(bloc.close);

    bloc.observeAgain();
    send(AppLifecycleState.inactive);

    expect(bloc.calls, ['inactive'], reason: 'a duplicate registration would deliver the event twice');
  });

  test('closing removes the observer', () async {
    // A bloc outliving its screen and still receiving lifecycle callbacks is a
    // leak that survives for the life of the app.
    final bloc = _LifecycleBloc();

    send(AppLifecycleState.inactive);
    expect(bloc.calls, ['inactive']);

    await bloc.close();
    send(AppLifecycleState.resumed);

    expect(bloc.calls, ['inactive'], reason: 'no callback may arrive after close');
  });

  test('a state arriving on a closed bloc is ignored', () async {
    // Belt and braces for the isClosed guard: close() removes the observer, but
    // a transition already in flight must not reach a closed bloc either.
    final bloc = _LifecycleBloc();
    await bloc.close();

    expect(() => bloc.didChangeAppLifecycleState(AppLifecycleState.resumed), returnsNormally);
    expect(bloc.calls, isEmpty);
  });
}
