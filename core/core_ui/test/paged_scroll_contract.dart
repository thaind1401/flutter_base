import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The guarantees every paginated scrollable makes, asserted identically for
/// each one.
///
/// Same idea as `key_value_store_contract.dart` in `core_storage`: the promises
/// live in one file and each implementation is run against them, so a grid
/// cannot quietly behave differently from a list. All of this behaviour comes
/// from `PagedScrollView`, and this contract is what stops a future third
/// layout from reimplementing it slightly wrong.
///
/// The failure modes here are all silent — a double-loading list, a spinner the
/// user scrolls into, an error that wipes the rows they were reading — which is
/// why they are pinned rather than left to review.

/// Builds the widget under test from the shared parameter set. Every paginated
/// scrollable takes exactly these, which is the standardisation: a screen swaps
/// list for grid without rewriting a single argument.
typedef PagedWidgetBuilder =
    Widget Function({
      required PagedViewState<String> state,
      required Widget Function(BuildContext context, String item, int index) itemBuilder,
      required VoidCallback onLoadMore,
      Future<void> Function()? onRefresh,
      VoidCallback? onRetry,
      EdgeInsets? padding,
      WidgetBuilder? emptyBuilder,
      ScrollController? scrollController,
    });

PagedViewState<String> pagedState({
  int count = 0,
  PagedStatus status = PagedStatus.ready,
  bool hasMore = true,
  Failure? failure,
}) => PagedViewState<String>(
  page: PagedList<String>(
    items: [for (var i = 0; i < count; i++) 'item $i'],
    page: 1,
    hasMore: hasMore,
    totalItems: count,
  ),
  status: status,
  failure: failure,
);

void runPagedScrollContract(String name, PagedWidgetBuilder build) {
  group('$name — paged scroll contract', () {
    var loadMoreCalls = 0;
    var retryCalls = 0;

    setUp(() {
      loadMoreCalls = 0;
      retryCalls = 0;
    });

    Widget host(
      PagedViewState<String> state, {
      Future<void> Function()? onRefresh,
      VoidCallback? onRetry,
      WidgetBuilder? emptyBuilder,
      ScrollController? controller,
    }) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        CoreL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: CoreL10n.supportedLocales,
      home: Scaffold(
        body: build(
          state: state,
          itemBuilder: (context, item, index) => SizedBox(height: 100, child: Text(item)),
          onLoadMore: () => loadMoreCalls++,
          onRefresh: onRefresh,
          onRetry: onRetry == null ? null : () => retryCalls++,
          emptyBuilder: emptyBuilder,
          scrollController: controller,
        ),
      ),
    );

    /// Finds the scrollable by role, not by concrete type. `PagedListView`
    /// renders a `SliverList` and `PagedGridView` a `SliverGrid`, both inside a
    /// `CustomScrollView`; asserting on `ListView` would tie this contract to
    /// one layout's internals — which is exactly what it exists not to do.
    Finder scrollable() => find.byType(Scrollable);

    Future<void> scrollToBottom(WidgetTester tester) async {
      await tester.drag(scrollable().first, const Offset(0, -3000));
      await tester.pump();
    }

    group('first load', () {
      testWidgets('an empty loading state shows the full-screen loader', (tester) async {
        await tester.pumpWidget(host(pagedState(status: PagedStatus.loading)));

        expect(find.byType(AppLoader), findsOneWidget);
        expect(scrollable(), findsNothing);
      });

      testWidgets('a first-page failure shows a full-screen error', (tester) async {
        await tester.pumpWidget(host(pagedState(status: PagedStatus.failed, failure: const NetworkFailure())));

        expect(find.byType(AppErrorView), findsOneWidget);
      });

      testWidgets('an empty ready state shows the empty view', (tester) async {
        await tester.pumpWidget(host(pagedState()));

        expect(find.byType(AppEmptyView), findsOneWidget);
      });

      testWidgets('a custom emptyBuilder replaces it', (tester) async {
        await tester.pumpWidget(host(pagedState(), emptyBuilder: (_) => const Text('Nothing here yet')));

        expect(find.text('Nothing here yet'), findsOneWidget);
        expect(find.byType(AppEmptyView), findsNothing);
      });

      testWidgets('an empty list is still scrollable so pull-to-refresh works', (tester) async {
        // A non-scrollable empty state is the reason "I cannot refresh an empty
        // list" bugs exist.
        await tester.pumpWidget(host(pagedState(), onRefresh: () async {}));

        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(scrollable(), findsOneWidget);
      });
    });

    group('content', () {
      testWidgets('items render through the builder', (tester) async {
        await tester.pumpWidget(host(pagedState(count: 3)));

        expect(find.text('item 0'), findsOneWidget);
        expect(find.text('item 2'), findsOneWidget);
      });

      testWidgets('refreshing keeps the items on screen', (tester) async {
        // Clearing during refresh makes the list jump and loses scroll position.
        await tester.pumpWidget(host(pagedState(count: 3, status: PagedStatus.refreshing)));

        expect(find.text('item 0'), findsOneWidget);
        expect(find.byType(AppLoader), findsNothing);
      });

      testWidgets('a load-more failure keeps the items and shows a retry footer', (tester) async {
        await tester.pumpWidget(
          host(
            pagedState(count: 3, status: PagedStatus.failed, failure: const NetworkFailure()),
            onRetry: () {},
          ),
        );

        expect(find.text('item 0'), findsOneWidget);
        expect(find.byType(AppErrorView), findsNothing, reason: 'a load-more failure is a footer, not a full page');
        expect(find.byType(TextButton), findsOneWidget);
      });

      testWidgets('the retry footer spans the viewport rather than sitting in one cell', (tester) async {
        // The reason the footer is its own sliver. Built as an item it would
        // occupy a single grid column and read as a broken tile.
        await tester.pumpWidget(
          host(
            pagedState(count: 3, status: PagedStatus.failed, failure: const NetworkFailure()),
            onRetry: () {},
          ),
        );

        final footerWidth = tester.getSize(find.byType(TextButton).first).width;
        final viewportWidth = tester.getSize(find.byType(Scaffold)).width;

        expect(footerWidth, lessThanOrEqualTo(viewportWidth));
        // Centred across the whole viewport, so its midpoint is the viewport's.
        expect(tester.getCenter(find.byType(TextButton).first).dx, closeTo(viewportWidth / 2, 1));
      });

      testWidgets('the retry footer calls onRetry', (tester) async {
        await tester.pumpWidget(
          host(
            pagedState(count: 3, status: PagedStatus.failed, failure: const NetworkFailure()),
            onRetry: () {},
          ),
        );

        await tester.tap(find.byType(TextButton));
        expect(retryCalls, 1);
      });

      testWidgets('the retry footer falls back to onLoadMore', (tester) async {
        await tester.pumpWidget(
          host(pagedState(count: 3, status: PagedStatus.failed, failure: const NetworkFailure())),
        );

        await tester.tap(find.byType(TextButton));
        expect(loadMoreCalls, 1);
      });

      testWidgets('loading more shows a footer spinner under the items', (tester) async {
        await tester.pumpWidget(host(pagedState(count: 3, status: PagedStatus.loadingMore)));

        expect(find.text('item 0'), findsOneWidget);
        expect(find.byType(AppLoader), findsOneWidget);
      });
    });

    group('load-more triggering', () {
      testWidgets('scrolling near the bottom loads the next page', (tester) async {
        await tester.pumpWidget(host(pagedState(count: 30)));

        await scrollToBottom(tester);

        expect(loadMoreCalls, greaterThan(0));
      });

      testWidgets('never fires when there are no more pages', (tester) async {
        await tester.pumpWidget(host(pagedState(count: 30, hasMore: false)));

        await scrollToBottom(tester);

        expect(loadMoreCalls, 0);
      });

      testWidgets('never fires while a load is already in flight', (tester) async {
        // canLoadMore is false in loadingMore, which is what stops the scroll
        // listener queuing a second identical request.
        await tester.pumpWidget(host(pagedState(count: 30, status: PagedStatus.loadingMore)));

        await scrollToBottom(tester);

        expect(loadMoreCalls, 0);
      });

      testWidgets('never fires while a previous failure is on screen', (tester) async {
        // Otherwise the failed footer retries itself forever as the user scrolls.
        await tester.pumpWidget(
          host(pagedState(count: 30, status: PagedStatus.failed, failure: const NetworkFailure())),
        );

        await scrollToBottom(tester);

        expect(loadMoreCalls, 0);
      });
    });

    group('controller ownership', () {
      testWidgets('a caller-supplied controller survives disposal', (tester) async {
        // Disposing a controller the caller still holds throws on its next use;
        // the widget only disposes what it created.
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(host(pagedState(count: 5), controller: controller));
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

        expect(() => controller.hasClients, returnsNormally);
        expect(controller.hasClients, isFalse);
      });

      testWidgets('an internally created controller is disposed with the widget', (tester) async {
        await tester.pumpWidget(host(pagedState(count: 5)));
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

        expect(tester.takeException(), isNull);
      });

      testWidgets('a supplied controller drives the scroll listener', (tester) async {
        // Proves the listener is attached to the caller's controller, not to a
        // second one created internally and ignored.
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(host(pagedState(count: 30), controller: controller));
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();

        expect(loadMoreCalls, greaterThan(0));
      });
    });

    group('refresh', () {
      testWidgets('pull to refresh invokes onRefresh', (tester) async {
        var refreshed = false;
        await tester.pumpWidget(host(pagedState(count: 5), onRefresh: () async => refreshed = true));

        await tester.fling(scrollable().first, const Offset(0, 400), 1000);
        await tester.pumpAndSettle();

        expect(refreshed, isTrue);
      });

      testWidgets('without onRefresh there is no refresh indicator', (tester) async {
        await tester.pumpWidget(host(pagedState(count: 5)));

        expect(find.byType(RefreshIndicator), findsNothing);
      });
    });
  });
}
