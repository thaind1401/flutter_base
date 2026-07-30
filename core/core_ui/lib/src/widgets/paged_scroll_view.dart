import 'package:core_arch/core_arch.dart';
import 'package:core_ui/src/l10n/generated/core_l10n.dart';
import 'package:core_ui/src/theme/theme_context_x.dart';
import 'package:core_ui/src/widgets/state_views.dart';
import 'package:flutter/material.dart';

/// Everything a paginated scrollable does apart from laying out its items.
///
/// This exists because `PagedListView` and `PagedGridView` differ in exactly one
/// respect — `SliverList` versus `SliverGrid` — and agree on everything that is
/// actually hard:
///
///   * load-more fires from a scroll threshold, not from the last item's
///     `builder`, which runs again on every relayout and double-loads;
///   * it never fires while a load is in flight, after the last page, or while a
///     previous failure is still on screen;
///   * items stay on screen during a refresh and during a load-more failure;
///   * a first-page failure is a full-screen error, a load-more failure is a
///     footer with a retry;
///   * an empty list is still scrollable, so pull-to-refresh works on it;
///   * a caller-supplied `ScrollController` is not disposed, and an internally
///     created one is.
///
/// Duplicating that per layout is how the second copy goes stale, and the
/// failure modes are all silent — a double-loading list, a spinner the user
/// scrolls into, an error that wipes the rows they were reading.
///
/// Exported rather than private: a screen that needs a sliver app bar above the
/// list, a staggered grid, or two sections in one scrollable can compose this
/// directly instead of forking [PagedListView].
class PagedScrollView<T> extends StatefulWidget {
  const PagedScrollView({
    super.key,
    required this.state,
    required this.sliverBuilder,
    required this.onLoadMore,
    this.onRefresh,
    this.onRetry,
    this.padding,
    this.emptyBuilder,
    this.loadMoreThreshold = 400,
    this.scrollController,
  });

  final PagedViewState<T> state;

  /// Builds the sliver that lays the loaded items out. Called only when there
  /// are items — first load, empty and first-page failure are handled here, so
  /// this never has to check for them.
  final WidgetBuilder sliverBuilder;

  final VoidCallback onLoadMore;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onRetry;
  final EdgeInsets? padding;
  final WidgetBuilder? emptyBuilder;

  /// Pixels from the bottom at which the next page starts loading. Large enough
  /// that the user never reaches a spinner on a normal scroll.
  final double loadMoreThreshold;

  final ScrollController? scrollController;

  @override
  State<PagedScrollView<T>> createState() => _PagedScrollViewState<T>();
}

class _PagedScrollViewState<T> extends State<PagedScrollView<T>> {
  late final ScrollController _controller = widget.scrollController ?? ScrollController();
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.scrollController == null;
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    // Only dispose what this widget created; disposing a caller's controller
    // breaks the screen that still holds it.
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.state.canLoadMore) return;
    if (!_controller.hasClients) return;
    final remaining = _controller.position.maxScrollExtent - _controller.position.pixels;
    if (remaining <= widget.loadMoreThreshold) widget.onLoadMore();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    if (state.isFirstLoad) return const AppLoader();

    if (state.isEmpty) {
      final failure = state.failure;
      final body = failure != null
          ? AppErrorView(failure: failure, onRetry: widget.onRetry)
          : widget.emptyBuilder?.call(context) ?? const AppEmptyView();
      // Still scrollable so pull-to-refresh works on an empty list.
      return _wrapRefresh(
        ListView(
          controller: _controller,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: 240, child: body)],
        ),
      );
    }

    return _wrapRefresh(
      CustomScrollView(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: widget.padding ?? EdgeInsets.symmetric(vertical: context.dimens.space8),
            sliver: widget.sliverBuilder(context),
          ),
          // A sliver of its own rather than a cell inside the layout: in a grid
          // a footer built as an item would occupy one column and read as a
          // broken tile. Here it spans the viewport for both layouts.
          if (_hasFooter) SliverToBoxAdapter(child: _footer(context)),
        ],
      ),
    );
  }

  bool get _hasFooter => widget.state.isLoadingMore || (widget.state.failure != null && !widget.state.isEmpty);

  Widget _footer(BuildContext context) {
    if (widget.state.isLoadingMore) {
      return Padding(padding: EdgeInsets.all(context.dimens.space16), child: const AppLoader(size: 22));
    }
    return Padding(
      padding: EdgeInsets.all(context.dimens.space16),
      child: Center(
        child: TextButton.icon(
          onPressed: widget.onRetry ?? widget.onLoadMore,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(CoreL10n.of(context).loadMoreFailed),
        ),
      ),
    );
  }

  Widget _wrapRefresh(Widget child) {
    final onRefresh = widget.onRefresh;
    if (onRefresh == null) return child;
    return RefreshIndicator(onRefresh: onRefresh, color: context.colors.brand, child: child);
  }
}
