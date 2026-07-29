# Architecture

## The layer graph

```
                       ┌───────────┐
                       │ core_kit  │  pure Dart: Result, Failure, extensions
                       └─────┬─────┘
        ┌──────────────┬─────┴──────┬──────────────┐
        ▼              ▼            ▼              ▼
 ┌────────────┐ ┌────────────┐ ┌──────────┐ ┌────────────┐
 │core_storage│ │core_network│ │core_arch │ │  core_ui   │
 └──────┬─────┘ └──────┬─────┘ └────┬─────┘ └─────┬──────┘
        │              │            │             │
        │              │            └──────┬──────┘
        │              │                   ▼
        │              │          ┌──────────────────┐
        │              │          │mini_app_contract │
        │              │          └────────┬─────────┘
        └──────┬───────┘                   │
               ▼                           ▼
        ┌─────────────┐            ┌────────────────┐
        │ feature_*   │            │  mini_app_*    │
        └──────┬──────┘            └───────┬────────┘
               └───────────┬───────────────┘
                           ▼
                        ┌─────┐
                        │ app │  composition root
                        └─────┘
```

Arrows point *downward only*. `make check-deps` fails the build on any edge not
in the table in `tools/check_dependencies.dart`.

Three consequences worth naming:

- **`core_kit` has no Flutter dependency.** It is testable with `dart test`, and
  the same validation and `Result` plumbing can run in a script or a server.
- **No feature depends on another feature.** Two features that need to
  communicate do so through a contract in a core package, which means either can
  be deleted, extracted, or reused in another app.
- **Nothing depends on `app`.** The host is where wiring happens and where the
  product-specific decisions live; it is the only package that is not reusable,
  and that is on purpose.

---

## The data flow

```
Widget ──event──▶ Bloc ──params──▶ UseCase ──▶ Repository ──▶ Retrofit API
   ▲                │                              │              │
   └──ViewState─────┘                              │           DioException
   └──Effect────────┘                              ▼              │
                                            Result<Entity> ◀──Failure◀──┘
                                                          DioFailureMapper
```

Read it as one rule: **exceptions stop at the repository.** Below that line Dio,
plugins and JSON decoding throw as they please; above it every fallible
operation returns `Result<T>`, and because `Failure` is sealed the compiler
checks that a `switch` handles every case.

This is what removes `try/catch` from use cases and blocs entirely. If you find
yourself writing one above the data layer, something has escaped its boundary.

---

## Failure handling end to end

1. `DioException` reaches `DioFailureMapper` (`core_network`), the *only* place
   HTTP semantics are interpreted.
2. It becomes a `Failure` — `NetworkFailure`, `UnauthorizedFailure`,
   `BusinessFailure(code:)`, and so on.
3. `BaseRepository.guard` wraps it in `Err<T>` and returns it.
4. The use case may rewrite it (`mapErr`) or compose past it (`flatMapAsync`).
5. The bloc `switch`es on the result and emits `ViewFailed(failure)` and/or an
   effect.
6. `FailurePresenter` (`core_ui`) turns the failure *type* into localized copy.

Note what step 6 does not do: it does not print the server's `message`. That
string is written for developers, is rarely translated, and sometimes leaks
internal detail. The exception is `BusinessFailure`, where the rule that was
violated is only known to the backend — override `FailurePresenter.businessMessage`
to map specific codes to your own copy.

---

## State

Two shapes, and the difference between them is deliberate.

**`ViewState<T>` is sealed** — a screen showing one thing is in exactly one
condition:

```dart
switch (state) {
  ViewIdle() || ViewLoading() => const AppLoader(),
  ViewEmpty(:final message)   => AppEmptyView(description: message),
  ViewFailed(:final failure)  => AppErrorView(failure: failure, onRetry: retry),
  ViewData(:final data)       => _Content(data),
}
```

This replaces the `status` enum + nullable `data` + nullable `error` triple,
which permitted states that cannot exist (`status: error` with data and no
error) and forced every widget to re-check nullability the compiler could not
verify.

**`PagedViewState<T>` is not sealed** — a list genuinely holds several
conditions at once: 40 items loaded, page 3 in flight, page 2 failed. Sealing it
would just be an enum crossed with itself. The invariants that matter (never
lose loaded items while loading more; never load more twice) are enforced by its
transition methods instead.

---

## Side effects

One-shot outcomes — navigate, toast, close sheet — go out on a stream:

```dart
emitEffect(const LoginSucceeded());
```

```dart
BlocEffectListener<LoginBloc, LoginEffect>(
  onEffect: (context, effect) => switch (effect) {
    LoginSucceeded()            => onAuthenticated(),
    LoginFailed(:final failure) => context.showFailureToast(failure),
  },
  child: const _LoginForm(),
)
```

Modelled as state, an effect has to be cleared after it fires; if the clear is
missed the toast reappears on the next rebuild, and on every rebuild after that.
A stream retains nothing, so the bug is not expressible.

---

## Dependency injection

Each package declares its own module:

```dart
@InjectableInit.microPackage()
void initCoreStoragePackage() {}
```

The composition root composes them in dependency order:

```dart
@InjectableInit(
  externalPackageModulesBefore: [
    ExternalModule(CoreStoragePackageModule),
    ExternalModule(CoreNetworkPackageModule),
    ExternalModule(FeatureAuthPackageModule),
  ],
)
Future<GetIt> configureDependencies() => getIt.init();
```

Anything that spans packages — `ApiClient` needs the auth delegate from
`feature_auth` *and* the request context from `app` — is wired in
`app/lib/app/di/app_module.dart`, because only the root can see all the pieces.

`app/test/injection_test.dart` resolves the whole graph. A DI mistake otherwise
surfaces at runtime, on a device, in whichever flow nobody opened before release.

---

## Auth without a cycle

The naive wiring is circular: the repository needs `Dio`, `Dio` needs a token,
the token lives in the session, and the session refreshes it through the
repository.

It is broken in three places:

1. **`AuthSessionDelegate`** (`core_network`) — an interface. The transport
   knows there is a token; it does not know what a user is.
2. **`SessionAuthDelegate`** (`feature_auth`) — implements it. The arrow points
   from the feature to the transport, never back.
3. **`TokenRefreshApi`** — builds its own bare `Dio` from the environment config.
   Refresh must not go through the authenticated client anyway: a 401 there
   would re-enter the auth interceptor and recurse.

`AuthInterceptor` collapses concurrent 401s into a single refresh. Without that,
every in-flight request fires its own refresh, the backend rotates the refresh
token N times, and the session is invalidated — a bug that only appears under
load and is covered by a test in `core/core_network/test/auth_interceptor_test.dart`.

---

## Routing

Each feature exposes a `RouteModule`; the host composes them:

```dart
AppRouterBuilder(
  modules: [_SplashRouteModule(), ShellRouteModule(...), AuthRouteModule(...), miniApps],
  guards: [SessionGuard(...)],
  shellBuilder: (context, state, child) => AppShell(child: child),
).build();
```

The alternative — one `app_routers.dart` importing every screen — makes the host
depend on every feature's internals, turns the router into a permanent merge
conflict, and grows without bound. Here a feature contributes a module; the host
never imports a screen.

Redirect policies are `RouteGuard` objects, evaluated in order, first non-null
wins. Each guard's decision is a pure function (`SessionGuard.resolve`) so it can
be tested without a widget tree, a router, or a container.

---

## Mini-apps

A mini-app depends on `mini_app_contract` and nothing else that belongs to the
host. The contract has two halves:

- `MiniApp` — what the mini-app offers: routes, entry points, DI registration.
- `MiniAppHost` — what it may ask for: an anonymous user id, the locale,
  navigation by route name, feature flags.

The second half is what makes the isolation real. Without it, any mini-app that
needs the signed-in user imports the host's state object, and at that point it
is a folder with extra steps rather than a package that can ship elsewhere.

Installing one is a line in `app/lib/app/bootstrap.dart` plus a pubspec entry.
Removing one is deleting that line.

---

## Connectivity and retry

Two separate mechanisms, deliberately not merged.

**`RetryInterceptor`** handles the transient case: a request that failed to
connect, timed out, or hit a 5xx. It retries with exponential backoff and
jitter, and only for idempotent methods — replaying a POST can create two
orders. A caller with an idempotency key opts in per request via
`RetryInterceptor.retryableExtraKey`.

Jitter is not decoration: without it every device that lost connectivity at the
same moment retries in lockstep and stampedes the server as it recovers.

**`ConnectivityMonitor`** answers a different question — can we reach the
backend at all. Note that this is *not* what the OS reports. `connectivity_plus`
says an interface exists; hotel captive portals, corporate wifi behind a VPN and
cellular with no data allowance all report "connected" while every request
fails. The monitor therefore combines three inputs:

1. the OS interface stream — instant, but only proves an interface exists;
2. hints from real traffic (`ConnectivityInterceptor`) — a response is proof of
   reachability, and the app makes those anyway, so they cost nothing;
3. an explicit probe, only when the first two disagree.

Two behaviours worth knowing about:

- **Offline is debounced.** A wifi-to-cellular handoff drops the interface for a
  few hundred milliseconds; publishing immediately makes the banner flicker
  every time someone walks out of the office, which trains users to ignore it.
- **Online is immediate.** A successful response is proof, so it cancels any
  pending offline transition rather than waiting for a probe.

The UI is `ConnectivityBanner`, mounted **once, above the router**, next to
`LoadingOverlayHost`. Not a mixin and not a base screen:

- a mixin has to be applied to every screen, and the one somebody forgets is the
  one where the user is stuck wondering why nothing loads;
- a per-screen banner reflows that screen and renders twice inside a nested
  navigator or a bottom sheet;
- connectivity is one global value; rendering it per screen means N listeners
  for it.

That banner is *only* the global connection indicator. "This screen failed to
load" stays with the screen: its bloc receives a `NetworkFailure` and renders
`AppErrorView` with a retry. Conflating the two is how you end up with a
full-screen error over a working app during a two-second tunnel.

---

## Testing

| Layer | How | Example |
|---|---|---|
| `core_kit` | `dart test`, no Flutter | `result_test.dart` |
| Failure mapping | stub `DioException`s | `dio_failure_mapper_test.dart` |
| Interceptors | stub `HttpClientAdapter` | `auth_interceptor_test.dart`, `retry_interceptor_test.dart` |
| Connectivity | fake `Connectivity` + injected probe | `connectivity_monitor_test.dart` |
| Use cases | hand-written fake repository | `login_bloc_test.dart` |
| Blocs | `bloc_test` + fakes | `login_bloc_test.dart` |
| Router policy | pure function | `session_guard_test.dart` |
| DI graph | resolve everything | `injection_test.dart` |

Hand-written fakes are preferred over generated mocks: for interfaces this
small they are shorter than the mock setup, they read as documentation of what
the collaborator does, and they do not require codegen to run before the tests.
