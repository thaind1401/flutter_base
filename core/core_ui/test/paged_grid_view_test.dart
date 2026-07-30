import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'paged_scroll_contract.dart';

/// The grid runs the same contract as the list — that is the point of extracting
/// `PagedScrollView`. What is tested below the contract is only what a grid adds:
/// how columns are decided.
void main() {
  runPagedScrollContract(
    'PagedGridView',
    ({
      required state,
      required itemBuilder,
      required onLoadMore,
      onRefresh,
      onRetry,
      padding,
      emptyBuilder,
      scrollController,
    }) => PagedGridView<String>.count(
      state: state,
      crossAxisCount: 2,
      // Wide and short, so a grid row is about as tall as a list row and the
      // contract's scroll assertions mean the same thing for both. At the
      // default ratio of 1, two columns on the test surface give 400pt-tall
      // tiles: three items already overflow the viewport, the footer sliver is
      // never built because slivers are lazy, and every footer assertion fails
      // for a reason that has nothing to do with the footer.
      childAspectRatio: 4,
      itemBuilder: itemBuilder,
      onLoadMore: onLoadMore,
      onRefresh: onRefresh,
      onRetry: onRetry,
      padding: padding,
      emptyBuilder: emptyBuilder,
      scrollController: scrollController,
    ),
  );

  group('PagedGridView column sizing', () {
    Widget host(Widget grid, {Size surface = const Size(400, 800)}) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        CoreL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: CoreL10n.supportedLocales,
      home: Scaffold(
        body: SizedBox(width: surface.width, height: surface.height, child: grid),
      ),
    );

    Widget tile(BuildContext context, String item, int index) => Text(item);

    testWidgets('count lays items out in the requested number of columns', (tester) async {
      await tester.pumpWidget(
        host(
          PagedGridView<String>.count(
            state: pagedState(count: 4),
            crossAxisCount: 2,
            itemBuilder: tile,
            onLoadMore: () {},
          ),
        ),
      );

      // Two per row: items 0 and 1 share a top edge, item 2 sits below.
      expect(tester.getTopLeft(find.text('item 0')).dy, tester.getTopLeft(find.text('item 1')).dy);
      expect(tester.getTopLeft(find.text('item 2')).dy, greaterThan(tester.getTopLeft(find.text('item 0')).dy));
      expect(tester.getTopLeft(find.text('item 1')).dx, greaterThan(tester.getTopLeft(find.text('item 0')).dx));
    });

    testWidgets('extent derives the column count from the viewport', (tester) async {
      // The reason extent is the recommended constructor: the same widget gives
      // two columns on a phone and four on a tablet with no breakpoint logic at
      // the call site.
      await tester.pumpWidget(
        host(
          PagedGridView<String>.extent(
            state: pagedState(count: 8),
            maxCrossAxisExtent: 200,
            itemBuilder: tile,
            onLoadMore: () {},
          ),
        ),
      );
      final narrowRowCount = tester
          .widgetList<Text>(find.byType(Text))
          .where((text) => tester.getTopLeft(find.text(text.data!)).dy == tester.getTopLeft(find.text('item 0')).dy)
          .length;

      await tester.pumpWidget(
        host(
          PagedGridView<String>.extent(
            state: pagedState(count: 8),
            maxCrossAxisExtent: 200,
            itemBuilder: tile,
            onLoadMore: () {},
          ),
          surface: const Size(900, 800),
        ),
      );
      final wideRowCount = tester
          .widgetList<Text>(find.byType(Text))
          .where((text) => tester.getTopLeft(find.text(text.data!)).dy == tester.getTopLeft(find.text('item 0')).dy)
          .length;

      expect(narrowRowCount, 2, reason: '400pt viewport at 200pt max extent');
      expect(wideRowCount, greaterThan(narrowRowCount), reason: 'a wider viewport must gain columns');
    });

    /// Keyed, because `find.byType` on a plain box also matches the ones Material
    /// paints for the scaffold background — the first match is then the full
    /// viewport, not a tile.
    Widget keyedTile(BuildContext context, String item, int index) => SizedBox(key: ValueKey(item), child: Text(item));

    testWidgets('tiles never exceed the requested max extent', (tester) async {
      await tester.pumpWidget(
        host(
          PagedGridView<String>.extent(
            state: pagedState(count: 4),
            maxCrossAxisExtent: 150,
            itemBuilder: keyedTile,
            onLoadMore: () {},
          ),
        ),
      );

      expect(tester.getSize(find.byKey(const ValueKey('item 0'))).width, lessThanOrEqualTo(150));
    });

    testWidgets('spacing defaults to a design system gap rather than zero', (tester) async {
      // Flutter's own default is 0, which makes an unspecified grid look wrong
      // rather than look like the design system.
      await tester.pumpWidget(
        host(
          PagedGridView<String>.count(
            state: pagedState(count: 2),
            crossAxisCount: 2,
            itemBuilder: keyedTile,
            onLoadMore: () {},
          ),
        ),
      );

      final left = tester.getRect(find.byKey(const ValueKey('item 0')));
      final right = tester.getRect(find.byKey(const ValueKey('item 1')));

      expect(right.left - left.right, greaterThan(0), reason: 'adjacent tiles must not be flush');
    });
  });
}
