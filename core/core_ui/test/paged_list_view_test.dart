import 'package:core_arch/core_arch.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'paged_scroll_contract.dart';

/// Everything shared with `PagedGridView` is in the contract. What is left here
/// is the one thing this widget adds: separators between rows.
void main() {
  runPagedScrollContract(
    'PagedListView',
    ({
      required state,
      required itemBuilder,
      required onLoadMore,
      onRefresh,
      onRetry,
      padding,
      emptyBuilder,
      scrollController,
    }) => PagedListView<String>(
      state: state,
      itemBuilder: itemBuilder,
      onLoadMore: onLoadMore,
      onRefresh: onRefresh,
      onRetry: onRetry,
      padding: padding,
      emptyBuilder: emptyBuilder,
      scrollController: scrollController,
    ),
  );

  group('PagedListView specifics', () {
    Widget host(PagedViewState<String> state, {IndexedWidgetBuilder? separatorBuilder}) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        CoreL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: CoreL10n.supportedLocales,
      home: Scaffold(
        body: PagedListView<String>(
          state: state,
          separatorBuilder: separatorBuilder,
          itemBuilder: (context, item, index) => SizedBox(height: 100, child: Text(item)),
          onLoadMore: () {},
        ),
      ),
    );

    testWidgets('rows are separated by the design system gap', (tester) async {
      await tester.pumpWidget(host(pagedState(count: 3)));

      final first = tester.getRect(find.text('item 0'));
      final second = tester.getRect(find.text('item 1'));

      // 100pt item plus the token gap, so the rows are not flush against each
      // other. The exact token is core_ui's business; that there *is* one is
      // this widget's.
      expect(second.top - first.bottom, greaterThan(0));
    });

    testWidgets('a custom separatorBuilder replaces the default', (tester) async {
      await tester.pumpWidget(
        host(pagedState(count: 3), separatorBuilder: (_, _) => const Divider(key: Key('sep'), height: 40)),
      );

      expect(find.byKey(const Key('sep')), findsNWidgets(2), reason: 'n items means n-1 separators');
    });
  });
}
