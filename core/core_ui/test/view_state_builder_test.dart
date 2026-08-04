import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one place a `ViewState` is turned into pixels. Every screen in every
/// feature goes through it, so a branch that renders the wrong thing here is
/// wrong everywhere at once — which is why this is tested before the widgets
/// that only one screen uses.

class _Bloc extends BaseCubit<ViewState<String>> {
  _Bloc() : super(const ViewState<String>.idle());

  void set(ViewState<String> next) => emit(next);
}

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: const [
      CoreL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: CoreL10n.supportedLocales,
    home: Scaffold(body: child),
  );

  Widget builderFor(
    ViewState<String> state, {
    VoidCallback? onRetry,
    WidgetBuilder? loading,
    WidgetBuilder? empty,
    WidgetBuilder? idle,
    Widget Function(BuildContext, Failure)? error,
  }) => host(
    ViewStateBuilder<String>(
      state: state,
      data: (context, value) => Text(value),
      onRetry: onRetry,
      loading: loading,
      empty: empty,
      idle: idle,
      error: error,
    ),
  );

  group('default branches', () {
    testWidgets('idle falls back to the loader', (tester) async {
      await tester.pumpWidget(builderFor(const ViewState<String>.idle()));

      expect(find.byType(AppLoader), findsOneWidget);
    });

    testWidgets('loading renders the loader', (tester) async {
      await tester.pumpWidget(builderFor(const ViewState<String>.loading()));

      expect(find.byType(AppLoader), findsOneWidget);
    });

    testWidgets('data renders the builder output', (tester) async {
      await tester.pumpWidget(builderFor(const ViewState<String>.data('hello')));

      expect(find.text('hello'), findsOneWidget);
      expect(find.byType(AppLoader), findsNothing);
    });

    testWidgets('empty renders the empty view and passes the message through', (tester) async {
      await tester.pumpWidget(builderFor(const ViewState<String>.empty(message: 'No invoices yet')));

      expect(find.byType(AppEmptyView), findsOneWidget);
      expect(find.text('No invoices yet'), findsOneWidget);
    });

    testWidgets('failed renders the error view', (tester) async {
      await tester.pumpWidget(builderFor(const ViewState<String>.failed(NetworkFailure())));

      expect(find.byType(AppErrorView), findsOneWidget);
    });
  });

  group('overrides win over the defaults', () {
    testWidgets('idle prefers its own builder over loading', (tester) async {
      await tester.pumpWidget(
        builderFor(
          const ViewState<String>.idle(),
          idle: (_) => const Text('idle'),
          loading: (_) => const Text('loading'),
        ),
      );

      expect(find.text('idle'), findsOneWidget);
      expect(find.text('loading'), findsNothing);
    });

    testWidgets('idle falls through to the loading builder when it has none', (tester) async {
      // The documented chain is idle → loading → AppLoader. The middle link is
      // the one worth pinning: "not asked yet" and "asking" look the same to a
      // user, so a screen that customises loading gets it for idle too.
      await tester.pumpWidget(builderFor(const ViewState<String>.idle(), loading: (_) => const Text('loading')));

      expect(find.text('loading'), findsOneWidget);
    });

    testWidgets('empty and error builders replace the defaults', (tester) async {
      await tester.pumpWidget(builderFor(const ViewState<String>.empty(), empty: (_) => const Text('nothing')));
      expect(find.text('nothing'), findsOneWidget);
      expect(find.byType(AppEmptyView), findsNothing);

      await tester.pumpWidget(
        builderFor(
          const ViewState<String>.failed(ServerFailure()),
          error: (_, failure) => Text('broke: ${failure.runtimeType}'),
        ),
      );
      expect(find.text('broke: ServerFailure'), findsOneWidget);
      expect(find.byType(AppErrorView), findsNothing);
    });
  });

  group('stale data survives a failure', () {
    testWidgets('failed with lastData keeps the content on screen', (tester) async {
      // The whole reason ViewFailed carries lastData: a refresh that fails must
      // not blank out what the user is already reading.
      await tester.pumpWidget(builderFor(const ViewState<String>.failed(NetworkFailure(), lastData: 'stale')));

      expect(find.text('stale'), findsOneWidget);
      expect(find.byType(AppErrorView), findsNothing);
    });

    testWidgets('lastData beats an explicit error builder too', (tester) async {
      await tester.pumpWidget(
        builderFor(
          const ViewState<String>.failed(NetworkFailure(), lastData: 'stale'),
          error: (_, _) => const Text('full screen error'),
        ),
      );

      expect(find.text('stale'), findsOneWidget);
      expect(find.text('full screen error'), findsNothing);
    });
  });

  group('retry', () {
    testWidgets('the retry button fires onRetry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        builderFor(const ViewState<String>.failed(NetworkFailure()), onRetry: () => retried = true),
      );

      await tester.tap(find.byType(OutlinedButton));
      expect(retried, isTrue);
    });

    testWidgets('no retry affordance without a callback', (tester) async {
      await tester.pumpWidget(builderFor(const ViewState<String>.failed(NetworkFailure())));

      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('no retry for a failure that retrying cannot fix', (tester) async {
      // Retry is offered by FailurePresenter's judgement, not by the presence
      // of a callback. Offering it on a validation error trains users to tap a
      // button that can never work.
      await tester.pumpWidget(builderFor(const ViewState<String>.failed(ValidationFailure()), onRetry: () {}));

      expect(find.byType(OutlinedButton), findsNothing);
    });
  });

  group('ViewStateConsumer', () {
    /// Emits and lets the rebuild land.
    ///
    /// Two frames, deliberately: the first delivers the stream event to
    /// `BlocBuilder`, the second renders the `setState` that delivery
    /// scheduled. One frame reads as a missing rebuild and sends you looking
    /// for a bug in the widget. `pumpAndSettle` is not an option — `AppLoader`
    /// holds a `CircularProgressIndicator`, which never settles.
    Future<void> emitAndPump(WidgetTester tester, _Bloc bloc, ViewState<String> state) async {
      bloc.set(state);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('rebuilds as the bloc moves through its states', (tester) async {
      final bloc = _Bloc();
      addTearDown(bloc.close);

      await tester.pumpWidget(
        host(
          BlocProvider<_Bloc>.value(
            value: bloc,
            child: ViewStateConsumer<_Bloc, ViewState<String>, String>(
              selector: (state) => state,
              data: (context, value) => Text(value),
            ),
          ),
        ),
      );

      expect(find.byType(AppLoader), findsOneWidget);

      await emitAndPump(tester, bloc, const ViewState<String>.data('loaded'));
      expect(find.text('loaded'), findsOneWidget);

      await emitAndPump(tester, bloc, const ViewState<String>.failed(TimeoutFailure()));
      expect(find.byType(AppErrorView), findsOneWidget);
    });

    testWidgets('does not rebuild when the selected slice is unchanged', (tester) async {
      // buildWhen compares the selected ViewState by ==, which is why every
      // state class extends Equatable. If that comparison degrades to identity
      // this test fails and rule 14 has been broken somewhere upstream.
      final bloc = _Bloc();
      addTearDown(bloc.close);
      var builds = 0;

      await tester.pumpWidget(
        host(
          BlocProvider<_Bloc>.value(
            value: bloc,
            child: ViewStateConsumer<_Bloc, ViewState<String>, String>(
              selector: (state) => state,
              data: (context, value) {
                builds++;
                return Text(value);
              },
            ),
          ),
        ),
      );

      await emitAndPump(tester, bloc, const ViewState<String>.data('same'));
      expect(builds, 1);

      await emitAndPump(tester, bloc, const ViewState<String>.data('same'));
      expect(builds, 1, reason: 'an equal state must not rebuild the data builder');

      await emitAndPump(tester, bloc, const ViewState<String>.data('different'));
      expect(builds, 2);
    });

    testWidgets('runs the selector once per state change, not three times', (tester) async {
      // This widget used to be a `BlocBuilder` whose `buildWhen` was
      // `selector(previous) != selector(current)` and whose builder called
      // `selector(state)` again — three invocations per emit, and a rebuild
      // condition written separately from the value being rendered, which is
      // precisely what rule 11 calls a last resort.
      //
      // Counting the calls is the only way this stays fixed: switching back to
      // `BlocBuilder` would keep every existing test in this file green.
      final bloc = _Bloc();
      addTearDown(bloc.close);
      var selectorCalls = 0;

      await tester.pumpWidget(
        host(
          BlocProvider<_Bloc>.value(
            value: bloc,
            child: ViewStateConsumer<_Bloc, ViewState<String>, String>(
              selector: (state) {
                selectorCalls++;
                return state;
              },
              data: (context, value) => Text(value),
            ),
          ),
        ),
      );

      final afterFirstBuild = selectorCalls;
      await emitAndPump(tester, bloc, const ViewState<String>.data('one'));

      expect(
        selectorCalls - afterFirstBuild,
        1,
        reason:
            'the selector should be evaluated once per emit; more means the '
            'rebuild condition and the rendered value are separate expressions',
      );
    });

    testWidgets('a selector that ignores the changed part does not rebuild', (tester) async {
      // The reason a screen reaches for this widget at all: one bloc driving
      // several independent regions, each selecting the slice it renders. A
      // region whose slice did not change must not rebuild when a sibling's
      // does.
      final bloc = _Bloc();
      addTearDown(bloc.close);
      var builds = 0;

      await tester.pumpWidget(
        host(
          BlocProvider<_Bloc>.value(
            value: bloc,
            child: ViewStateConsumer<_Bloc, ViewState<String>, String>(
              // Collapses every data state onto one value, so emitting
              // different data changes the state but not this slice.
              selector: (state) => state.hasData ? const ViewState<String>.data('slice') : state,
              data: (context, value) {
                builds++;
                return Text(value);
              },
            ),
          ),
        ),
      );

      await emitAndPump(tester, bloc, const ViewState<String>.data('first'));
      expect(builds, 1);

      await emitAndPump(tester, bloc, const ViewState<String>.data('second'));
      expect(builds, 1, reason: 'the underlying state changed but the selected slice did not');
    });
  });
}
