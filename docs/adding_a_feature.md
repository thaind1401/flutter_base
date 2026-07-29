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

### Rebuild scope

The screen is a **tree of small `const` widgets**, one per region that changes
independently, each on its own `BlocSelector`. Not one `BlocBuilder` at the top:
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
the one thing on screen, as in `ArticleListScreen`. `BlocBuilder` with
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
- [ ] Screen split into `const` widgets, one `BlocSelector` each (ADR-0008)
- [ ] Nothing displayed is read from outside the state
- [ ] State extends `Equatable`, `props` lists every field
- [ ] No literal colours or spacings in widgets
- [ ] Barrel exports the minimum
- [ ] No import of another `feature_*` package
- [ ] `make ci` green
