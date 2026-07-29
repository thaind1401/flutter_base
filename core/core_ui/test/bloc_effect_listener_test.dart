import 'package:core_arch/core_arch.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rule 4 says one-shot outcomes are effects, not state flags. This widget is
/// the only thing delivering them, so if it drops one, every "navigate after
/// login" and "toast on failure" in the app drops it too.

sealed class _Effect {}

final class _Toast extends _Effect {
  _Toast(this.text);
  final String text;
}

final class _Navigate extends _Effect {}

/// Not part of the [_Effect] family — a listener for [_Effect] must ignore it.
final class _Unrelated {}

class _Cubit extends BaseCubit<int> {
  _Cubit() : super(0);

  void fire(Object effect) => emitEffect(effect);
}

void main() {
  /// Two frames: the first delivers the effect stream event, the second renders
  /// anything the callback changed. See view_state_builder_test.dart.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Widget host({required _Cubit bloc, required void Function(BuildContext, _Effect) onEffect, bool explicit = false}) {
    final listener = BlocEffectListener<_Cubit, _Effect>(
      bloc: explicit ? bloc : null,
      onEffect: onEffect,
      child: const Text('child', textDirection: TextDirection.ltr),
    );
    return MaterialApp(
      home: explicit ? listener : BlocProvider<_Cubit>.value(value: bloc, child: listener),
    );
  }

  testWidgets('renders its child', (tester) async {
    final bloc = _Cubit();
    addTearDown(bloc.close);

    await tester.pumpWidget(host(bloc: bloc, onEffect: (_, _) {}));

    expect(find.text('child'), findsOneWidget);
  });

  testWidgets('delivers an effect read from the nearest provider', (tester) async {
    final bloc = _Cubit();
    addTearDown(bloc.close);
    final received = <_Effect>[];

    await tester.pumpWidget(host(bloc: bloc, onEffect: (_, effect) => received.add(effect)));
    bloc.fire(_Toast('saved'));
    await settle(tester);

    expect(received, hasLength(1));
    expect((received.single as _Toast).text, 'saved');
  });

  testWidgets('delivers an effect from an explicitly passed bloc', (tester) async {
    // The explicit form exists for a bloc that is not in the tree above this
    // widget; if it silently fell back to a provider lookup it would throw.
    final bloc = _Cubit();
    addTearDown(bloc.close);
    final received = <_Effect>[];

    await tester.pumpWidget(host(bloc: bloc, explicit: true, onEffect: (_, effect) => received.add(effect)));
    bloc.fire(_Navigate());
    await settle(tester);

    expect(received.single, isA<_Navigate>());
  });

  testWidgets('effects arrive in order, once each', (tester) async {
    // The point of a stream over a state flag: no retained value, so nothing is
    // redelivered on a later rebuild.
    final bloc = _Cubit();
    addTearDown(bloc.close);
    final received = <String>[];

    await tester.pumpWidget(
      host(bloc: bloc, onEffect: (_, effect) => received.add(effect is _Toast ? effect.text : 'nav')),
    );
    bloc
      ..fire(_Toast('first'))
      ..fire(_Navigate())
      ..fire(_Toast('second'));
    await settle(tester);

    expect(received, ['first', 'nav', 'second']);

    // A rebuild must not replay anything.
    await tester.pumpWidget(
      host(bloc: bloc, onEffect: (_, effect) => received.add(effect is _Toast ? effect.text : 'nav')),
    );
    await settle(tester);

    expect(received, ['first', 'nav', 'second']);
  });

  testWidgets('ignores effects outside the listened family', (tester) async {
    // The effect stream is untyped so BlocLifecycle stays generic-free. Two
    // listeners on one bloc is the normal case, and each must see only its own.
    final bloc = _Cubit();
    addTearDown(bloc.close);
    final received = <_Effect>[];

    await tester.pumpWidget(host(bloc: bloc, onEffect: (_, effect) => received.add(effect)));
    bloc
      ..fire(_Unrelated())
      ..fire('a bare string')
      ..fire(_Toast('mine'));
    await settle(tester);

    expect(received, hasLength(1));
    expect((received.single as _Toast).text, 'mine');
  });

  testWidgets('an effect emitted just before teardown is still delivered', (tester) async {
    // Pins the boundary the other way round, because it is easy to assume the
    // opposite: the subscription is live at the moment of the emit, so the
    // callback runs. An effect is not cancelled by a teardown that happens
    // after it. What must not happen is delivery *after* dispose — that is the
    // next test, and it is what protects the context from being used defunct.
    final bloc = _Cubit();
    addTearDown(bloc.close);
    var called = false;

    await tester.pumpWidget(host(bloc: bloc, onEffect: (_, _) => called = true));

    bloc.fire(_Toast('in flight'));
    await tester.pumpWidget(const MaterialApp(home: Text('gone', textDirection: TextDirection.ltr)));
    await settle(tester);

    expect(called, isTrue);
    expect(find.text('gone'), findsOneWidget);
  });

  testWidgets('stops listening once disposed', (tester) async {
    final bloc = _Cubit();
    addTearDown(bloc.close);
    var count = 0;

    await tester.pumpWidget(host(bloc: bloc, onEffect: (_, _) => count++));
    bloc.fire(_Toast('one'));
    await settle(tester);
    expect(count, 1);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await settle(tester);

    bloc.fire(_Toast('two'));
    await settle(tester);
    expect(count, 1, reason: 'the subscription must be cancelled in dispose');
  });

  testWidgets('re-subscribes when the bloc it is given changes', (tester) async {
    // didChangeDependencies compares by identity and resubscribes. If it did
    // not, a screen whose bloc is replaced would keep listening to the dead one.
    final first = _Cubit();
    final second = _Cubit();
    addTearDown(first.close);
    addTearDown(second.close);
    final received = <String>[];

    await tester.pumpWidget(host(bloc: first, explicit: true, onEffect: (_, e) => received.add((e as _Toast).text)));
    await tester.pumpWidget(host(bloc: second, explicit: true, onEffect: (_, e) => received.add((e as _Toast).text)));
    await settle(tester);

    second.fire(_Toast('from second'));
    await settle(tester);
    expect(received, ['from second']);

    first.fire(_Toast('from first'));
    await settle(tester);
    expect(received, ['from second'], reason: 'the old bloc must no longer be listened to');
  });
}
