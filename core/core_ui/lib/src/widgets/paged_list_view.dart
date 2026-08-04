import 'package:core_arch/core_arch.dart';
import 'package:core_ui/src/theme/theme_context_x.dart';
import 'package:core_ui/src/widgets/paged_scroll_view.dart';
import 'package:flutter/material.dart';

/// Infinite list wired to a [PagedViewState].
///
/// Everything that makes pagination correct — the scroll threshold, the
/// load-more guards, the retry footer, refresh, empty and error routing —
/// lives in [PagedScrollView]. This adds one thing: the items are a
/// `SliverList`. [PagedGridView] is the same widget with a `SliverGrid`.
///
/// The split is not decoration. Those guards are subtle and their failure modes
/// are silent, so there is exactly one copy of them.
class PagedListView<T> extends StatelessWidget {
  const PagedListView({
    super.key,
    required this.state,
    required this.itemBuilder,
    required this.onLoadMore,
    this.onRefresh,
    this.onRetry,
    this.separatorBuilder,
    this.padding,
    this.emptyBuilder,
    this.loadMoreThreshold = 400,
    this.scrollController,
  });

  final PagedViewState<T> state;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final VoidCallback onLoadMore;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onRetry;
  final IndexedWidgetBuilder? separatorBuilder;
  final EdgeInsets? padding;
  final WidgetBuilder? emptyBuilder;
  final double loadMoreThreshold;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return PagedScrollView<T>(
      state: state,
      onLoadMore: onLoadMore,
      onRefresh: onRefresh,
      onRetry: onRetry,
      padding: padding,
      emptyBuilder: emptyBuilder,
      loadMoreThreshold: loadMoreThreshold,
      scrollController: scrollController,
      sliverBuilder: (context) => SliverList.separated(
        itemCount: state.items.length,
        itemBuilder: (context, index) => itemBuilder(context, state.items[index], index),
        separatorBuilder: separatorBuilder ?? (_, _) => SizedBox(height: context.dimens.space8),
      ),
    );
  }
}
