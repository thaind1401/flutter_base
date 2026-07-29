/// Architectural base types: how a use case, a repository, a bloc, a state and
/// a route are shaped in this codebase.
///
/// Nothing here knows about HTTP, storage engines or design tokens — only about
/// structure. That is why a feature package can depend on `core_arch` without
/// dragging in Dio.
library core_arch;

export 'package:bloc_concurrency/bloc_concurrency.dart' show concurrent, droppable, restartable, sequential;
// Value equality is load-bearing here, not a convenience: `BlocSelector` and
// `buildWhen` decide whether to rebuild by comparing states with `==`. A state
// class that forgets Equatable rebuilds the whole subtree on every emit; one
// that forgets a field in `props` never rebuilds for that field. Exported so
// defining a state never needs a direct dependency on the package.
export 'package:equatable/equatable.dart' show Equatable;
export 'package:flutter_bloc/flutter_bloc.dart';
// The routing surface features and the host legitimately need. `GoRouterHelper`
// is the `context.go` / `context.pushNamed` extension; without it every screen
// has to import go_router directly and the abstraction leaks anyway.
export 'package:go_router/go_router.dart'
    show
        GoRoute,
        GoRouter,
        GoRouterHelper,
        GoRouterState,
        RouteBase,
        ShellRoute,
        StatefulShellBranch,
        StatefulShellRoute;

export 'src/domain/base_repository.dart';
export 'src/domain/use_case.dart';
export 'src/navigation/app_navigator.dart';
export 'src/navigation/app_router_builder.dart';
export 'src/navigation/route_module.dart';
export 'src/presentation/app_lifecycle_aware.dart';
export 'src/presentation/base_bloc.dart';
export 'src/presentation/paged_view_state.dart';
export 'src/presentation/view_state.dart';
