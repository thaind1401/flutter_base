import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'paged_scroll_contract.dart';

/// Every screen extends one of three bases, so a defect here is a defect in
/// every screen. What matters is that the base supplies the chrome nobody should
/// have to remember, and that it supplies *only* that — a plain screen must not
/// inherit a list screen's paging surface, and a list screen must not be able to
/// drop the paging by overriding a method.

class _Plain extends BaseScreen {
  const _Plain();

  @override
  Widget buildBody(BuildContext context) => const Text('body');
}

class _Configured extends BaseScreen {
  const _Configured();

  @override
  String? title(BuildContext context) => 'Titled';

  @override
  List<Widget>? actions(BuildContext context) => const [Icon(Icons.more_vert, key: Key('action'))];

  @override
  Widget? bottomBar(BuildContext context) => const Text('bottom');

  @override
  Widget? floatingActionButton(BuildContext context) => const FloatingActionButton(onPressed: null);

  @override
  Color? backgroundColor(BuildContext context) => const Color(0xFF00FF00);

  @override
  bool get padded => true;

  @override
  Widget buildBody(BuildContext context) => const Text('body');
}

class _WithOwnAppBar extends BaseScreen {
  const _WithOwnAppBar();

  @override
  String? title(BuildContext context) => 'Ignored';

  @override
  PreferredSizeWidget? appBar(BuildContext context) =>
      const PreferredSize(preferredSize: Size.fromHeight(40), child: Text('Custom'));

  @override
  Widget buildBody(BuildContext context) => const Text('body');
}

class _Counter extends BaseCubit<PagedViewState<String>> {
  _Counter() : super(pagedState(count: 3));

  void put(PagedViewState<String> next) => emit(next);
}

class _List extends BaseListScreen<_Counter, String> {
  const _List();

  @override
  String? title(BuildContext context) => 'Items';

  @override
  Widget buildItem(BuildContext context, String item, int index) => SizedBox(height: 60, child: Text(item));

  @override
  void onLoadMore(BuildContext context) => loadMoreCalls++;

  @override
  Future<void> onRefresh(BuildContext context) async => refreshCalls++;
}

class _NoRefreshList extends _List {
  const _NoRefreshList();

  @override
  bool get enablePullToRefresh => false;
}

class _Grid extends BaseGridScreen<_Counter, String> {
  const _Grid();

  @override
  double get maxCrossAxisExtent => 200;

  @override
  double get childAspectRatio => 4;

  @override
  Widget buildItem(BuildContext context, String item, int index) => Text(item);

  @override
  void onLoadMore(BuildContext context) => loadMoreCalls++;

  @override
  Future<void> onRefresh(BuildContext context) async => refreshCalls++;
}

int loadMoreCalls = 0;
int refreshCalls = 0;

void main() {
  setUp(() {
    loadMoreCalls = 0;
    refreshCalls = 0;
  });

  Widget host(Widget screen, {_Counter? bloc}) => MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: const [
      CoreL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: CoreL10n.supportedLocales,
    home: bloc == null ? screen : BlocProvider<_Counter>.value(value: bloc, child: screen),
  );

  group('BaseScreen supplies the chrome', () {
    testWidgets('renders the body inside an AppScaffold', (tester) async {
      await tester.pumpWidget(host(const _Plain()));

      expect(find.byType(AppScaffold), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('no title means no app bar', (tester) async {
      // What a splash or a login screen wants: nothing to go back to, so no bar.
      await tester.pumpWidget(host(const _Plain()));

      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('every chrome hook reaches the scaffold', (tester) async {
      await tester.pumpWidget(host(const _Configured()));

      expect(find.text('Titled'), findsOneWidget);
      expect(find.byKey(const Key('action')), findsOneWidget);
      expect(find.text('bottom'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, const Color(0xFF00FF00));
    });

    testWidgets('padded insets the body', (tester) async {
      await tester.pumpWidget(host(const _Configured()));
      final paddedLeft = tester.getTopLeft(find.text('body')).dx;

      await tester.pumpWidget(host(const _Plain()));

      expect(paddedLeft, greaterThan(tester.getTopLeft(find.text('body')).dx));
    });

    testWidgets('an appBar override wins over title', (tester) async {
      await tester.pumpWidget(host(const _WithOwnAppBar()));

      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Ignored'), findsNothing);
    });

    testWidgets('the keyboard dismissal default is on', (tester) async {
      // The single most-forgotten screen default, which is why it lives here and
      // not in each screen.
      await tester.pumpWidget(host(const _Plain()));

      expect(find.byType(GestureDetector), findsWidgets);
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).resizeToAvoidBottomInset, isTrue);
    });
  });

  group('BaseScreen carries no paging surface', () {
    // The compile-time half of this is asserted by the analyzer: `onLoadMore`,
    // `onRefresh`, `onRetry`, `buildItem` and `enablePullToRefresh` are not
    // defined on a BaseScreen subclass at all, because they live on a private
    // intermediate class only the paged bases extend. A plain screen therefore
    // cannot accidentally half-implement a list.
    testWidgets('a plain screen builds without any bloc in the tree', (tester) async {
      // A paging base would need one and would throw here. This is the runtime
      // shadow of that separation.
      await tester.pumpWidget(host(const _Plain()));

      expect(tester.takeException(), isNull);
      expect(find.byType(RefreshIndicator), findsNothing);
      expect(find.byType(Scrollable), findsNothing);
    });
  });

  group('BaseListScreen', () {
    testWidgets('renders items through buildItem inside the chrome', (tester) async {
      final bloc = _Counter();
      addTearDown(bloc.close);

      await tester.pumpWidget(host(const _List(), bloc: bloc));

      expect(find.text('Items'), findsOneWidget, reason: 'chrome still comes from BaseScreen');
      expect(find.text('item 0'), findsOneWidget);
      expect(find.text('item 2'), findsOneWidget);
    });

    testWidgets('rebuilds as the bloc emits', (tester) async {
      final bloc = _Counter();
      addTearDown(bloc.close);

      await tester.pumpWidget(host(const _List(), bloc: bloc));
      bloc.put(pagedState(count: 5));
      await tester.pump();

      expect(find.text('item 4'), findsOneWidget);
    });

    testWidgets('a first load shows the loader, not an empty list', (tester) async {
      final bloc = _Counter()..put(pagedState(status: PagedStatus.loading));
      addTearDown(bloc.close);

      await tester.pumpWidget(host(const _List(), bloc: bloc));

      expect(find.byType(AppLoader), findsOneWidget);
    });

    testWidgets('pull-to-refresh is wired by default', (tester) async {
      final bloc = _Counter();
      addTearDown(bloc.close);

      await tester.pumpWidget(host(const _List(), bloc: bloc));

      expect(find.byType(RefreshIndicator), findsOneWidget);

      await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(refreshCalls, 1);
    });

    testWidgets('enablePullToRefresh false removes the indicator', (tester) async {
      final bloc = _Counter();
      addTearDown(bloc.close);

      await tester.pumpWidget(host(const _NoRefreshList(), bloc: bloc));

      expect(find.byType(RefreshIndicator), findsNothing);
    });

    testWidgets('onRetry defaults to retrying the same page', (tester) async {
      final bloc = _Counter()..put(pagedState(count: 3, status: PagedStatus.failed, failure: const NetworkFailure()));
      addTearDown(bloc.close);

      await tester.pumpWidget(host(const _List(), bloc: bloc));
      await tester.tap(find.byType(TextButton));

      expect(loadMoreCalls, 1, reason: 'the default onRetry dispatches onLoadMore');
    });
  });

  group('BaseGridScreen', () {
    testWidgets('lays items out in a grid inside the same chrome', (tester) async {
      final bloc = _Counter()..put(pagedState(count: 8));
      addTearDown(bloc.close);

      await tester.pumpWidget(host(const _Grid(), bloc: bloc));

      expect(find.text('item 0'), findsOneWidget);
      // Deliberately not asserting a column count: at 200pt max extent the
      // 800pt test surface yields four, and pinning that would make this test
      // about the surface size rather than about gridding. What must hold for
      // any column count of two or more is that the first two items share a row
      // and a later item does not.
      expect(tester.getTopLeft(find.text('item 0')).dy, tester.getTopLeft(find.text('item 1')).dy);
      expect(tester.getTopLeft(find.text('item 1')).dx, greaterThan(tester.getTopLeft(find.text('item 0')).dx));
      expect(tester.getTopLeft(find.text('item 7')).dy, greaterThan(tester.getTopLeft(find.text('item 0')).dy));
    });

    testWidgets('shares the paging behaviour, not just the look', (tester) async {
      final bloc = _Counter()..put(pagedState(count: 3, status: PagedStatus.failed, failure: const NetworkFailure()));
      addTearDown(bloc.close);

      await tester.pumpWidget(host(const _Grid(), bloc: bloc));
      await tester.tap(find.byType(TextButton));

      expect(loadMoreCalls, 1);
    });
  });
}
