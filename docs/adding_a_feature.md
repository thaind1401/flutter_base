# Adding a feature

Copy `feature_auth`. Everything below is what that package already
demonstrates; this page is the checklist.

## 1. Create the package

```
features/feature_orders/
├── pubspec.yaml
├── analysis_options.yaml        include: ../analysis_options.yaml
└── lib/
    ├── feature_orders.dart      barrel — the feature's entire public surface
    ├── di.dart                  @InjectableInit.microPackage()
    └── src/
        ├── domain/
        │   ├── entities/
        │   ├── repositories/    interfaces only
        │   └── use_cases/
        ├── data/
        │   ├── models/          DTOs, *.g.dart
        │   ├── data_sources/    @RestApi
        │   └── repositories/    implementations
        └── presentation/
            ├── orders_route_module.dart
            └── order_list/      bloc + state + screen + widgets
```

Register it in three places:

1. `pubspec.yaml` at the repo root → `workspace:` (as `features/feature_orders`)
2. `tools/check_dependencies.dart` → `allowedDependencies`
3. `Makefile` → `PACKAGES`, plus `CODEGEN_PACKAGES` / `TEST_PACKAGES` if it
   needs them

Steps 1 and 2 are cross-checked: `make check-deps` fails if a package appears in
one and not the other. With a flat root a new directory is easy to add and easy
to forget, and a package missing from `allowedDependencies` would otherwise be
exempt from every boundary rule.

Then `app/pubspec.yaml`, `app/lib/app/di/injection.dart`
(`ExternalModule(FeatureOrdersPackageModule)`), and the router module list.

## 2. Domain first

```dart
// domain/entities/order.dart — no fromJson, no nullable soup
final class Order extends Equatable { ... }

// domain/repositories/order_repository.dart
abstract interface class OrderRepository {
  Future<Result<PagedList<Order>>> fetchPage(PageRequest request);
}

// domain/use_cases/fetch_orders_use_case.dart
typedef FetchOrdersParams = ({PageRequest page, String? status});

@injectable
class FetchOrdersUseCase extends UseCase<FetchOrdersParams, PagedList<Order>> {
  const FetchOrdersUseCase(this._repository);
  final OrderRepository _repository;

  @override
  Future<Result<PagedList<Order>>> execute(FetchOrdersParams params) =>
      _repository.fetchPage(params.page);
}
```

Parameters are a **typed record**. `Map<String, dynamic>` turns a renamed field
into a runtime bug the backend notices before you do.

## 3. Data

```dart
@RestApi()
@injectable
abstract class OrderApi {
  @factoryMethod
  factory OrderApi(Dio dio) = _OrderApi;

  @GET('/v1/orders')
  Future<PagedResponseDto<OrderDto>> fetchOrders(@Queries() Map<String, dynamic> query);
}

@LazySingleton(as: OrderRepository)
final class OrderRepositoryImpl extends BaseRepository implements OrderRepository {
  OrderRepositoryImpl(this._api, super.failureMapper);
  final OrderApi _api;

  @override
  Future<Result<PagedList<Order>>> fetchPage(PageRequest request) =>
      guard(() async => (await _api.fetchOrders(request.toQuery())).toEntity());
}
```

Every call goes through `guard`. No `try/catch`, ever.

The DTO → entity mapping is not ceremony: it is the seam that lets the backend
rename `full_name` to `display_name` without the change reaching a widget.

## 4. Presentation

### Choosing a state shape

Three shapes ship with the base. Pick before writing the bloc, because changing
your mind later means rewriting both the bloc and every `BlocSelector` on the
screen.

The question that decides it: **can the screen be in two of its conditions at
once?**

| Screen | State | Render with |
|---|---|---|
| One block of data — a detail page, a profile, a dashboard card | `ViewState<T>` | `ViewStateBuilder` / `ViewStateConsumer` |
| Several fields live at once — any form | Your own `Equatable` class | one `BlocSelector` per region |
| An infinite list | `PagedViewState<T>` | `PagedListView` |
| An infinite grid — a gallery, a product catalogue | `PagedViewState<T>` | `PagedGridView` |

**`ViewState<T>`** (`core_arch`) when the conditions are mutually exclusive:
loading *or* data *or* empty *or* failed, never two together. It is sealed, so
`switch` is exhaustive and `ViewData` means you have data — no nullable field to
re-check. Render it with `ViewStateBuilder` (`core_ui`) rather than rewriting the
five branches per screen; only `data` is required, and loading, empty and error
fall back to the design system's own views.

```dart
@injectable
final class OrderDetailBloc extends BaseBloc<OrderDetailEvent, ViewState<Order>> {
  OrderDetailBloc(this._fetchOrder) : super(const ViewState<Order>.idle()) {
    on<OrderDetailStarted>(_onStarted, transformer: droppable());
  }

  Future<void> _onStarted(OrderDetailStarted event, Emitter<ViewState<Order>> emit) async {
    emit(const ViewState<Order>.loading());
    final result = await _fetchOrder((id: event.id));
    emit(switch (result) {
      Ok(:final value) => ViewState<Order>.data(value),
      Err(:final failure) => ViewState<Order>.failed(failure),
    });
  }
}

// The whole screen body:
ViewStateConsumer<OrderDetailBloc, ViewState<Order>, Order>(
  selector: (state) => state,
  data: (context, order) => _OrderBody(order),
  onRetry: () => context.read<OrderDetailBloc>().add(OrderDetailStarted(id)),
)
```

**Your own state class** when the conditions are simultaneous. A login form is
holding an email, a password, their validation errors, whether submit is enabled
and whether it is in flight — all true at the same time. A sealed state cannot
express that without becoming an enum crossed with itself. `login_screen.dart` is
the reference implementation, and the rest of this section is about it.

**`PagedViewState<T>`** for an infinite list or grid, and note it is deliberately
*not* sealed for the same reason — 40 items loaded, page 3 in flight and page 2
failed is one legitimate state. ADR-0004 has the full reasoning for both.

`PagedListView` and `PagedGridView` take the same arguments and the same state,
so swapping a list for a grid is a constructor change and nothing else. Both are
thin wrappers over `PagedScrollView`, which owns every part of paging that is
easy to get wrong: the load-more threshold, the guards against firing while a
request is in flight or past the last page, the retry footer, and keeping items
on screen through a refresh. Compose `PagedScrollView` directly if a screen needs
a sliver app bar above the items or two sections in one scrollable — that is what
it is exported for.

For a grid, prefer `PagedGridView.extent(maxCrossAxisExtent: …)` over
`.count(crossAxisCount: …)`. Extent derives the column count from the viewport,
so the same screen gives two columns on a phone and four on a tablet with no
breakpoint logic at the call site; a fixed count stretches tiles to 340pt on a
split view.

A screen with two independent regions can hold two `ViewState`s in one state
class and give each its own `ViewStateConsumer` with a different `selector`.
That is what `selector` is for.

### The bloc

```dart
@injectable
final class OrderListBloc extends BaseBloc<OrderListEvent, PagedViewState<Order>> {
  OrderListBloc(this._fetchOrders) : super(const PagedViewState<Order>()) {
    on<OrderListStarted>(_onStarted, transformer: droppable());
    on<OrderListRefreshed>(_onRefreshed, transformer: restartable());
    on<OrderListLoadMore>(_onLoadMore, transformer: droppable());
  }
  ...
}
```

Pick the transformer deliberately — the default (`concurrent`) is wrong for both
refresh and load-more. `restartable()` on refresh so two pulls cannot land out
of order; `droppable()` on load-more so a scroll listener firing repeatedly does
not fetch the same page twice.

The screen renders state and dispatches events. That is all it does.

### Choosing a screen base

Every screen extends one of three bases from `core_ui` and none of them writes
its own scaffold. The base owns the chrome — keyboard dismissal on tap outside a
field, `resizeToAvoidBottomInset`, safe area including a bottom bar clearing the
home indicator, the back-button policy — so forgetting one is no longer possible.

| Screen | Base | You implement |
|---|---|---|
| One block of data, or a form | `BaseScreen` | `buildBody` |
| A paginated list | `BaseListScreen<B, T>` | `buildItem`, `onLoadMore`, `onRefresh` |
| A paginated grid | `BaseGridScreen<B, T>` | the same, plus `maxCrossAxisExtent` |

**Pagination decides it, not the widget.** A `ListView` whose data arrives
complete is a `BaseScreen` — `HomeScreen` renders a list of installed mini-apps
and has no page to load and nothing to refresh. Choosing `BaseListScreen` there
would force an `onLoadMore` with nothing to do.

A plain screen has no paging surface *at all*: `onLoadMore`, `onRefresh`,
`onRetry`, `buildItem` and `enablePullToRefresh` live on a private intermediate
class that only the two paged bases extend, so none of them compiles on a
`BaseScreen` subclass. That is the point of the split rather than one base with
optional hooks.

Override `buildBody`; `build` is `@nonVirtual`, as is the `buildBody` that
installs paging on the list and grid bases — overriding it would keep the class
name while silently dropping the scroll listener, the load-more guards and the
retry footer.

A list screen that also has an independent region — a filter bar, a header that
reloads on its own — has stopped qualifying for `BaseListScreen`. Extend
`BaseScreen` and compose `PagedListView` inside a body whose regions each have
their own selector.

### Rebuild scope

Inside `buildBody`, the screen is a **tree of small `const` widgets**, one per
region that changes independently, each on its own `BlocSelector`. The base wraps
`buildBody` in no builder and subscribes to nothing, so this is unchanged by
extending it. Not one `BlocBuilder` at the top:
that makes a keystroke in one field rebuild every other field, both buttons and
the scaffold.

```dart
class _StatusFilter extends StatelessWidget {
  const _StatusFilter();

  @override
  Widget build(BuildContext context) {
    // The selector is the rebuild condition AND the only thing the builder can
    // see, so the two cannot fall out of step.
    return BlocSelector<OrderListBloc, OrderListState, String?>(
      selector: (state) => state.statusFilter,
      builder: (context, status) => FilterChips(
        selected: status,
        onChanged: (value) => context.read<OrderListBloc>().add(OrderStatusFiltered(value)),
      ),
    );
  }
}
```

Two fields in one region: select a **record**, not the whole state — records
have value equality, so this still rebuilds only when one of them changes.

```dart
BlocSelector<LoginBloc, LoginState, ({bool canSubmit, bool isSubmitting})>(
  selector: (state) => (canSubmit: state.canSubmit, isSubmitting: state.isSubmitting),
  builder: (context, submit) => AppButton(isLoading: submit.isSubmitting, ...),
)
```

`BlocBuilder` with no `buildWhen` is right in one case only: the whole state is
the one thing on screen — which is why `BaseListScreen` uses one internally.
`BlocBuilder` with
`buildWhen` is a last resort — the condition and the data the builder reads are
separate expressions, so adding a field to the builder and forgetting it in
`buildWhen` makes the widget stop updating with nothing to catch it.

Two rules that go with this:

- **The state must carry what the view renders.** Reading a displayed value
  through `context.read<X>().something` or `getIt` inside a builder means
  nothing rebuilds when it changes.
- **`Equatable`, with every field in `props`.** Both mechanisms decide by `==`.

ADR-0008 has the reasoning; `login_screen.dart` is the reference implementation.

## 5. Route module

```dart
final class OrdersRouteModule implements RouteModule {
  const OrdersRouteModule({required this.blocFactory});
  final OrderListBloc Function() blocFactory;

  static const RouteSpec list = RouteSpec(name: 'orders', path: '/orders');

  @override
  String get id => 'orders';

  @override
  List<RouteBase> rootRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) => const [];

  @override
  List<RouteBase> shellRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) => [
    GoRoute(
      name: list.name,
      path: list.path,
      builder: (context, state) => BlocProvider(
        create: (_) => blocFactory()..add(const OrderListStarted()),
        child: const OrderListScreen(),
      ),
    ),
  ];
}
```

`shellRoutes` for screens inside the bottom navigation; `rootRoutes` for
full-screen ones. Both are required so adding a feature forces the decision.

## 6. Barrel

Export the minimum: entities, repository interface, use cases the host needs,
and the route module. **Not** the repository implementation, the DTOs, or the
API class — those are private to the feature and exporting them is how a
boundary quietly dissolves.

## 7. Tests

At minimum: the bloc with a fake repository, and the DTO → entity mapping for
any field that is nullable, renamed, or format-ambiguous on the wire.

```bash
make codegen && make analyze && make test && make check-deps
```

## Checklist

- [ ] No `try/catch` above the data layer
- [ ] Use case params are a typed record
- [ ] Bloc depends on use cases only
- [ ] Event transformers chosen deliberately
- [ ] One-shot outcomes are effects, not state flags
- [ ] State shape chosen deliberately — `ViewState` for one block of data, your
      own class for a form, `PagedViewState` for a list (ADR-0004)
- [ ] Screen extends `BaseScreen`, `BaseListScreen` or `BaseGridScreen` and
      writes no scaffold of its own
- [ ] `buildBody` split into `const` widgets, one `BlocSelector` each (ADR-0008)
- [ ] Nothing displayed is read from outside the state
- [ ] State extends `Equatable`, `props` lists every field
- [ ] No literal colours or spacings in widgets
- [ ] Barrel exports the minimum
- [ ] No import of another `feature_*` package
- [ ] `make ci` green
