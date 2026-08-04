import 'dart:async';

import 'package:core_arch/core_arch.dart';
import 'package:flutter/widgets.dart';

/// Delivers a bloc's one-shot effects to the widget tree.
///
/// Why effects are not state: "show a toast" and "close this sheet" happen
/// once. Modelled as a state flag they have to be cleared afterwards, and if
/// the clear is missed the toast fires again on the next rebuild — or worse, on
/// every rebuild. A stream has no such retained value.
///
/// ```dart
/// BlocEffectListener<LoginBloc, LoginEffect>(
///   onEffect: (context, effect) => switch (effect) {
///     LoginSucceeded() => HomeRoute.spec.go(context),
///     LoginFailed(:final failure) => context.showFailureToast(failure),
///   },
///   child: const _LoginForm(),
/// )
/// ```
class BlocEffectListener<B extends BlocLifecycle<Object?>, E> extends StatefulWidget {
  const BlocEffectListener({super.key, required this.onEffect, required this.child, this.bloc});

  /// Explicit bloc, or null to read it from the nearest provider.
  final B? bloc;

  final void Function(BuildContext context, E effect) onEffect;
  final Widget child;

  @override
  State<BlocEffectListener<B, E>> createState() => _BlocEffectListenerState<B, E>();
}

class _BlocEffectListenerState<B extends BlocLifecycle<Object?>, E> extends State<BlocEffectListener<B, E>> {
  StreamSubscription<Object>? _subscription;
  B? _bloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  /// Covers the case [didChangeDependencies] does not: a change to this
  /// widget's own `bloc` argument is not a dependency change, so without this
  /// the listener kept delivering effects from the bloc it was first given and
  /// silently ignored the replacement.
  @override
  void didUpdateWidget(covariant BlocEffectListener<B, E> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.bloc, oldWidget.bloc)) _bind();
  }

  void _bind() {
    final bloc = widget.bloc ?? context.read<B>();
    if (identical(bloc, _bloc)) return;
    _bloc = bloc;
    _resubscribe(bloc);
  }

  void _resubscribe(B bloc) {
    unawaited(_subscription?.cancel());
    _subscription = bloc.effects.listen((effect) {
      // The effect stream is untyped so BlocLifecycle stays generic-free; a
      // screen listening for one effect family ignores anything else.
      if (effect is! E) return;
      // A navigation effect arriving as the screen is being torn down would
      // otherwise use a defunct context.
      if (!mounted) return;
      // `is!` does not promote a type variable, so the cast is required even
      // though the check above already proved it.
      widget.onEffect(context, effect as E);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
