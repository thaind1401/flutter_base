import 'package:core_arch/core_arch.dart';
import 'package:core_ui/src/theme/theme_context_x.dart';
import 'package:core_ui/src/widgets/app_scaffold.dart';
import 'package:core_ui/src/widgets/paged_grid_view.dart';
import 'package:core_ui/src/widgets/paged_list_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The three shapes every screen in this codebase takes.
///
///   * [BaseScreen] — one block of data, or a form. Most screens.
///   * [BaseListScreen] — a paginated list.
///   * [BaseGridScreen] — a paginated grid.
///
/// Every screen extends exactly one of them, so the chrome every screen needs is
/// decided once: keyboard dismissal on tap outside a field, `resizeToAvoid`
/// `BottomInset`, safe-area handling including a bottom bar clearing the home
/// indicator, and the back-button policy. A screen that forgets one of those is
/// no longer possible, because it cannot write the scaffold itself.
///
/// ## What the base does not own
///
/// **Rebuild scope stays with the screen.** [BaseScreen.buildBody] is called
/// from `build` and its result is handed straight to the scaffold — the base
/// wraps it in no builder and subscribes to nothing. Rule 11 applies inside
/// `buildBody` exactly as before: a tree of small `const` widgets, one
/// `BlocSelector` per region that changes independently.
///
/// That constraint is the whole reason this is safe. A base that wrapped the
/// body in a `BlocBuilder` would decide rebuild scope for every screen deriving
/// from it, and a keystroke in one field would rebuild the other field, both
/// buttons and the scaffold. `core_arch`'s `BaseBloc` carries a comment about
/// the same class of mistake: the previous generation registered a
/// `WidgetsBindingObserver` in the bloc base, so every bloc in the app received
/// every lifecycle callback whether it cared or not. A base class taxes every
/// subclass for every feature it takes on; this one deliberately takes on only
/// the frame.
///
/// [BaseListScreen] and [BaseGridScreen] *do* subscribe, and that is the
/// documented exception in ADR-0008 rather than a contradiction: for a
/// paginated collection the whole state is the one thing on screen, and the
/// paged view reads all of it — items, `hasMore`, `isRefreshing`, the failure.
///
/// ```dart
/// class OrderDetailScreen extends BaseScreen {
///   const OrderDetailScreen({super.key});
///
///   @override
///   String? title(BuildContext context) => 'Order';
///
///   @override
///   Widget buildBody(BuildContext context) => const _OrderBody();
/// }
/// ```
abstract class BaseScreen extends StatelessWidget {
  const BaseScreen({super.key});

  /// The screen's content.
  ///
  /// Rule 11 applies here: small `const` widgets, one `BlocSelector` per region
  /// that changes independently. Nothing above this method rebuilds, so a
  /// `BlocBuilder` spanning the whole body has the same cost it always had.
  @protected
  Widget buildBody(BuildContext context);

  /// App bar title. Null and no [appBar] means no app bar at all — which is what
  /// a splash or a full-bleed screen wants.
  @protected
  String? title(BuildContext context) => null;

  /// Full app bar override. Wins over [title].
  @protected
  PreferredSizeWidget? appBar(BuildContext context) => null;

  @protected
  List<Widget>? actions(BuildContext context) => null;

  /// Pinned action area, inset above the keyboard and the home indicator.
  @protected
  Widget? bottomBar(BuildContext context) => null;

  @protected
  Widget? floatingActionButton(BuildContext context) => null;

  @protected
  Color? backgroundColor(BuildContext context) => null;

  /// Intercepts the back button — for a form with unsaved changes. Null pops.
  @protected
  VoidCallback? onBack(BuildContext context) => null;

  /// Applies the design system's page insets to [buildBody].
  @protected
  bool get padded => false;

  @protected
  bool get showBackButton => true;

  /// Off for a screen with its own gesture handling — a map, a signature pad.
  @protected
  bool get dismissKeyboardOnTap => true;

  @protected
  bool get safeAreaBottom => true;

  /// Assembles the chrome. Marked [nonVirtual] on purpose: overriding it would
  /// silently discard every hook above and reintroduce exactly the per-screen
  /// scaffold this class exists to remove. Override [buildBody], or [appBar] if
  /// the app bar itself is the unusual part.
  @override
  @nonVirtual
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title(context),
      appBar: appBar(context),
      actions: actions(context),
      bottomBar: bottomBar(context),
      floatingActionButton: floatingActionButton(context),
      backgroundColor: backgroundColor(context),
      padded: padded,
      showBackButton: showBackButton,
      onBack: onBack(context),
      dismissKeyboardOnTap: dismissKeyboardOnTap,
      safeAreaBottom: safeAreaBottom,
      body: buildBody(context),
    );
  }
}

/// Shared paging hooks for [BaseListScreen] and [BaseGridScreen].
///
/// Private, so the public surface stays the three classes a screen author picks
/// from. Both subclasses differ only in which paged view they build.
abstract class _BasePagedScreen<B extends StateStreamable<PagedViewState<T>>, T> extends BaseScreen {
  const _BasePagedScreen({super.key});

  /// One row or tile. Called only for loaded items — first load, empty and
  /// first-page failure are rendered by the paged view.
  @protected
  Widget buildItem(BuildContext context, T item, int index);

  /// Dispatch the load-more event. Called from a scroll threshold, already
  /// guarded against firing while a request is in flight or past the last page.
  @protected
  void onLoadMore(BuildContext context);

  /// Pull-to-refresh. Must complete when the bloc settles, or the spinner snaps
  /// away the moment the gesture ends — await the bloc's stream, do not just
  /// dispatch and return.
  @protected
  Future<void> onRefresh(BuildContext context);

  /// Whether to show the refresh indicator at all. On by default because a
  /// paginated collection almost always wants it; set false for a list the user
  /// cannot meaningfully refresh, and [onRefresh] then goes unused.
  @protected
  bool get enablePullToRefresh => true;

  /// Retry after a load-more failure. Defaults to retrying the same page.
  @protected
  void onRetry(BuildContext context) => onLoadMore(context);

  /// Replaces the design system's default empty view. Null keeps `AppEmptyView`,
  /// so the default lives in one place rather than being repeated here.
  @protected
  WidgetBuilder? get emptyBuilder => null;

  @protected
  EdgeInsets? contentPadding(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: context.dimens.pagePadding, vertical: context.dimens.space8);

  /// The state is read with a `BlocBuilder` rather than a `BlocSelector`, which
  /// is ADR-0008's documented exception: the paged view reads every field of
  /// this state, so selecting them one at a time would rebuild the same widget
  /// for the same reasons with more code. `bloc` already suppresses an emit of
  /// an equal state.
  ///
  /// If a screen grows a region independent of the list — a filter bar, a header
  /// — it stops qualifying for the exception. Extend [BaseScreen] instead and
  /// compose `PagedListView` inside a body whose regions each have a selector.
  /// [nonVirtual] for the same reason [BaseScreen.build] is: this method *is*
  /// the paging installation. A subclass overriding it would keep the class name
  /// and silently lose the scroll listener, the load-more guards and the retry
  /// footer. A list screen that genuinely needs a different body is not a list
  /// screen — extend [BaseScreen] and compose `PagedListView` yourself.
  @override
  @protected
  @nonVirtual
  Widget buildBody(BuildContext context) {
    return BlocBuilder<B, PagedViewState<T>>(builder: buildPagedView);
  }

  @protected
  Widget buildPagedView(BuildContext context, PagedViewState<T> state);
}

/// A screen whose body is a paginated list.
///
/// ```dart
/// class OrderListScreen extends BaseListScreen<OrderListBloc, Order> {
///   const OrderListScreen({super.key});
///
///   @override
///   String? title(BuildContext context) => 'Orders';
///
///   @override
///   Widget buildItem(BuildContext context, Order order, int index) => _OrderTile(order);
///
///   @override
///   void onLoadMore(BuildContext context) =>
///       context.read<OrderListBloc>().add(const OrderListLoadMore());
///
///   @override
///   Future<void> onRefresh(BuildContext context) async {
///     final bloc = context.read<OrderListBloc>()..add(const OrderListRefreshed());
///     await bloc.stream.firstWhere((state) => !state.isRefreshing);
///   }
/// }
/// ```
abstract class BaseListScreen<B extends StateStreamable<PagedViewState<T>>, T> extends _BasePagedScreen<B, T> {
  const BaseListScreen({super.key});

  /// Separator between rows. Defaults to the design system gap.
  @protected
  IndexedWidgetBuilder? separatorBuilder(BuildContext context) => null;

  @override
  @protected
  @nonVirtual
  Widget buildPagedView(BuildContext context, PagedViewState<T> state) {
    return PagedListView<T>(
      state: state,
      itemBuilder: buildItem,
      separatorBuilder: separatorBuilder(context),
      padding: contentPadding(context),
      emptyBuilder: emptyBuilder,
      onLoadMore: () => onLoadMore(context),
      onRetry: () => onRetry(context),
      onRefresh: enablePullToRefresh ? () => onRefresh(context) : null,
    );
  }
}

/// A screen whose body is a paginated grid.
///
/// Columns come from [maxCrossAxisExtent] by default, so the same screen gives
/// two columns on a phone and four on a tablet with no breakpoint logic here.
/// Override [crossAxisCount] only when the design fixes a column count rather
/// than a tile size.
abstract class BaseGridScreen<B extends StateStreamable<PagedViewState<T>>, T> extends _BasePagedScreen<B, T> {
  const BaseGridScreen({super.key});

  /// Maximum tile width. Ignored when [crossAxisCount] is non-null.
  @protected
  double get maxCrossAxisExtent => 200;

  /// Fixed column count. Null means derive it from [maxCrossAxisExtent].
  @protected
  int? get crossAxisCount => null;

  @protected
  double get childAspectRatio => 1;

  @override
  @protected
  @nonVirtual
  Widget buildPagedView(BuildContext context, PagedViewState<T> state) {
    final columns = crossAxisCount;
    if (columns != null) {
      return PagedGridView<T>.count(
        state: state,
        crossAxisCount: columns,
        childAspectRatio: childAspectRatio,
        itemBuilder: buildItem,
        padding: contentPadding(context),
        emptyBuilder: emptyBuilder,
        onLoadMore: () => onLoadMore(context),
        onRetry: () => onRetry(context),
        onRefresh: enablePullToRefresh ? () => onRefresh(context) : null,
      );
    }
    return PagedGridView<T>.extent(
      state: state,
      maxCrossAxisExtent: maxCrossAxisExtent,
      childAspectRatio: childAspectRatio,
      itemBuilder: buildItem,
      padding: contentPadding(context),
      emptyBuilder: emptyBuilder,
      onLoadMore: () => onLoadMore(context),
      onRetry: () => onRetry(context),
      onRefresh: enablePullToRefresh ? () => onRefresh(context) : null,
    );
  }
}
