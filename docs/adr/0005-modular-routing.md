# 0005 — Route modules and guard objects

**Status:** Accepted

## Context

The previous router was one 243-line file importing sixty screens. It made the
host package depend on every feature's internals, it was a merge conflict on
every branch, and every redirect rule lived in one growing closure.

## Decision

- Each feature exposes a `RouteModule` with `rootRoutes` and `shellRoutes`.
- `AppRouterBuilder` composes modules and a list of `RouteGuard`s.
- Guards run in order; the first non-null location wins.
- Each guard's decision is a pure function so it is testable without a widget
  tree — `SessionGuard.resolve(location:, status:)`.
- Duplicate route paths trip an assert at startup instead of silently making one
  feature's screen unreachable.

## Consequences

**Good**

- The host names modules, never screens.
- Adding a feature does not touch a shared router file.
- "Signed out → login" and "terms not accepted → consent" are separate objects
  with separate tests.

**Costs**

- One extra file per feature.
- Guard order is significant and implicit in a list. Documented at the call site.

## Rejected alternatives

- **`go_router_builder` typed routes.** Type-safe navigation is attractive, but
  it adds a codegen step to every feature and the generated extension methods
  still need a central registry.
- **Keeping one router file, splitting only the imports.** Does not remove the
  host-to-feature dependency, which was the actual problem.
