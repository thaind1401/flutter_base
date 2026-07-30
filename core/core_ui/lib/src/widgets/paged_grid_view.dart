import 'package:core_arch/core_arch.dart';
import 'package:core_ui/src/theme/theme_context_x.dart';
import 'package:core_ui/src/widgets/paged_scroll_view.dart';
import 'package:flutter/material.dart';

/// Infinite grid wired to a [PagedViewState].
///
/// The same widget as [PagedListView] with a `SliverGrid` instead of a
/// `SliverList` — every paging guard comes from [PagedScrollView], so a fix
/// there fixes both.
///
/// Two ways to size the columns, and the choice matters more than it looks:
///
///   * [PagedGridView.count] — a fixed number of columns. Fine for a phone-only
///     screen, wrong on a tablet or a split view, where three columns stretched
///     across 1024 logical pixels gives 340pt-wide tiles.
///   * [PagedGridView.extent] — a maximum tile width, and the column count
///     follows from the viewport. This is the responsive default and the one to
///     reach for unless the design genuinely fixes the column count.
class PagedGridView<T> extends StatelessWidget {
  /// Fixed column count. Prefer [PagedGridView.extent] unless the design really
  /// does specify a column count rather than a tile size.
  const PagedGridView.count({
    super.key,
    required this.state,
    required this.itemBuilder,
    required this.onLoadMore,
    required int crossAxisCount,
    this.onRefresh,
    this.onRetry,
    this.padding,
    this.emptyBuilder,
    this.childAspectRatio = 1,
    this.mainAxisSpacing,
    this.crossAxisSpacing,
    this.loadMoreThreshold = 400,
    this.scrollController,
  }) : _crossAxisCount = crossAxisCount,
       _maxCrossAxisExtent = null;

  /// Responsive: columns are derived from the viewport so tiles never exceed
  /// [maxCrossAxisExtent].
  const PagedGridView.extent({
    super.key,
    required this.state,
    required this.itemBuilder,
    required this.onLoadMore,
    required double maxCrossAxisExtent,
    this.onRefresh,
    this.onRetry,
    this.padding,
    this.emptyBuilder,
    this.childAspectRatio = 1,
    this.mainAxisSpacing,
    this.crossAxisSpacing,
    this.loadMoreThreshold = 400,
    this.scrollController,
  }) : _crossAxisCount = null,
       _maxCrossAxisExtent = maxCrossAxisExtent;

  final PagedViewState<T> state;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final VoidCallback onLoadMore;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onRetry;
  final EdgeInsets? padding;
  final WidgetBuilder? emptyBuilder;
  final double childAspectRatio;

  /// Default to the `space8` token rather than Flutter's 0, so a grid that
  /// specifies nothing still looks like the design system.
  final double? mainAxisSpacing;
  final double? crossAxisSpacing;

  final double loadMoreThreshold;
  final ScrollController? scrollController;

  final int? _crossAxisCount;
  final double? _maxCrossAxisExtent;

  @override
  Widget build(BuildContext context) {
    final gap = context.dimens.space8;
    final delegate = _crossAxisCount != null
        ? SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _crossAxisCount,
            childAspectRatio: childAspectRatio,
            mainAxisSpacing: mainAxisSpacing ?? gap,
            crossAxisSpacing: crossAxisSpacing ?? gap,
          )
        : SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: _maxCrossAxisExtent!,
            childAspectRatio: childAspectRatio,
            mainAxisSpacing: mainAxisSpacing ?? gap,
            crossAxisSpacing: crossAxisSpacing ?? gap,
          );

    return PagedScrollView<T>(
      state: state,
      onLoadMore: onLoadMore,
      onRefresh: onRefresh,
      onRetry: onRetry,
      padding: padding,
      emptyBuilder: emptyBuilder,
      loadMoreThreshold: loadMoreThreshold,
      scrollController: scrollController,
      sliverBuilder: (context) => SliverGrid.builder(
        gridDelegate: delegate,
        itemCount: state.items.length,
        itemBuilder: (context, index) => itemBuilder(context, state.items[index], index),
      ),
    );
  }
}
