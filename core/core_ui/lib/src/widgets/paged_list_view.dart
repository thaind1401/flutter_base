import 'package:core_arch/core_arch.dart';
import 'package:core_ui/src/l10n/generated/core_l10n.dart';
import 'package:core_ui/src/theme/theme_context_x.dart';
import 'package:core_ui/src/widgets/state_views.dart';
import 'package:flutter/material.dart';

/// Infinite list wired to a [PagedViewState].
///
/// Handles the parts that are easy to get subtly wrong and are therefore worth
/// writing once:
///   * fires load-more from a scroll threshold, not from the last item's
///     `builder` — a builder fires again on every relayout and double-loads;
///   * never fires while a load is already in flight or after the last page;
///   * keeps items on screen during refresh and during a load-more failure;
///   * distinguishes a first-page failure (full-screen error) from a
///     load-more failure (footer with retry).
class PagedListView<T> extends StatefulWidget {
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

  /// Pixels from the bottom at which the next page starts loading. Large enough
  /// that the user never reaches a spinner on a normal scroll.
  final double loadMoreThreshold;

  final ScrollController? scrollController;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
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
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: 240, child: body)],
        ),
      );
    }

    final itemCount = state.items.length + (_hasFooter ? 1 : 0);

    return _wrapRefresh(
      ListView.separated(
        controller: _controller,
        padding: widget.padding ?? EdgeInsets.symmetric(vertical: context.dimens.space8),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: widget.separatorBuilder ?? (_, _) => SizedBox(height: context.dimens.space8),
        itemBuilder: (context, index) {
          if (index >= state.items.length) return _footer(context);
          return widget.itemBuilder(context, state.items[index], index);
        },
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
