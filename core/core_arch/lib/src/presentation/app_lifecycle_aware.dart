import 'package:bloc/bloc.dart';
import 'package:core_arch/src/presentation/base_bloc.dart';
import 'package:flutter/widgets.dart';

/// Opt-in app lifecycle callbacks for a bloc.
///
/// Opt-in rather than built into [BaseBloc] on purpose: registering a
/// `WidgetsBindingObserver` per bloc means every lifecycle transition walks a
/// list containing every bloc alive. Only the few that genuinely need it — a
/// timer that must pause in the background, a session that re-validates on
/// resume — should pay that cost.
///
/// The `on WidgetsBindingObserver` constraint means the bloc mixes in Flutter's
/// observer itself and inherits its no-op defaults. Stubbing the interface here
/// instead would break on every Flutter release that adds a callback.
///
/// ```dart
/// final class TimerBloc extends BaseBloc<TimerEvent, TimerState>
///     with WidgetsBindingObserver, AppLifecycleAware {
///   TimerBloc() : super(const TimerState.idle()) {
///     observeLifecycle();
///   }
///
///   @override
///   void onAppResumed() => add(const TimerEvent.resync());
/// }
/// ```
mixin AppLifecycleAware<State> on BlocBase<State>, BlocLifecycle<State>, WidgetsBindingObserver {
  bool _observing = false;

  /// Call from the constructor of the bloc that needs lifecycle events.
  @protected
  void observeLifecycle() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isClosed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        onAppResumed();
      case AppLifecycleState.inactive:
        onAppInactive();
      case AppLifecycleState.paused:
        onAppPaused();
      case AppLifecycleState.detached:
        onAppDetached();
      case AppLifecycleState.hidden:
        onAppHidden();
    }
  }

  @protected
  void onAppResumed() {}

  @protected
  void onAppInactive() {}

  @protected
  void onAppPaused() {}

  @protected
  void onAppDetached() {}

  @protected
  void onAppHidden() {}

  @override
  Future<void> close() {
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    return super.close();
  }
}
