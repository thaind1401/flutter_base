# 0007 — Mini-apps talk to the host through a contract only

**Status:** Accepted

## Context

The previous mini-app package depended on `app_domain` — the host's entire HR
domain — and the host imported the mini-app's widgets directly. It was described
as self-contained, but it could not be built, tested, or shipped into another
app without carrying the whole domain package along.

Nothing in the design prevented that. There was a `MiniAppModule` interface for
what the mini-app offered the host, and nothing at all for what the mini-app
needed *from* the host, so it reached for whatever it could import.

## Decision

`mini_app_contract` is a small package that both sides depend on and neither
side may bypass:

- `MiniApp` — routes, entry points, and its own DI registration.
- `MiniAppHost` — an anonymous user id, the locale, navigation by route name,
  and feature flags.

A mini-app's `pubspec.yaml` may name `mini_app_contract` and the `core_*`
packages. Naming a `feature_*` package, or the host, fails `make check-deps`.

## Consequences

**Good**

- A mini-app builds and tests in isolation.
- Installing one is a line in `bootstrap.dart`; removing one is deleting it.
- Two mini-apps cannot couple to each other.
- `MiniAppHost` makes the host surface explicit and reviewable — widening it is
  a deliberate change to one file.

**Costs**

- A mini-app that needs more from the host requires a contract change rather
  than an import. That review is the feature, not the bug.
- Passing an id instead of a user entity means a mini-app that needs profile
  data must fetch it. Correct: it should own its own data.
- **A mini-app registers its dependencies at runtime, and that is weaker than
  the path a feature gets.** `registerDependencies(GetIt, MiniAppHost)` is
  hand-written, so a mini-app is absent from `CODEGEN_PACKAGES` and never gets
  the injectable generator's "I cannot see this registration" warning — the
  build-time check ADR-0003 exists to preserve. This cost was not written down
  when this ADR was accepted; see *Closing the DI gap* below.

## When this is worth it, and when to delete it

The distinction only pays for itself under one condition: **the package is
written by someone who cannot see the host's source** — another team, another
repository, a versioned artifact, a separate release cadence. A mini-app
compiles against `mini_app_contract` and the `core_*` packages alone, which is
what lets you hand the contract to another team and receive back a package you
drop in. `feature_auth` cannot do that: it needs `core_network` and
`core_storage`, and the host must know its bloc types to wire it
(`AuthRouteModule(loginBlocFactory: …)`).

Three things commonly cited for mini-apps are **not** reasons to keep them:

- *"Installing one is a single line."* That follows from `SampleMiniApp` taking
  no host callbacks, not from it being a mini-app. `AuthRouteModule` takes two
  because login genuinely has to tell the host where to go next; a feature
  without that need is also one line.
- *"Modules stay isolated from each other."* Rule 5 in `CLAUDE.md` already
  forbids a feature importing a feature, and `tools/check_dependencies.dart`
  enforces it. The contract is not what buys that.
- *"Modules cannot reach the host's internals."* `allowedDependencies` already
  decides that per package, mini-app or not.

**Delete `mini_app_contract` and `mini_app_sample` if** one team ships from one
repository on one release train, and no third party will contribute a module.
`MiniAppHost` — an id, a locale, navigation by name, a flag lookup — becomes a
small interface in `core_arch` that any feature may take, `feature_*` plus
`RouteModule` does everything else, and the `mini_apps/` group disappears from
the dependency table.

That deletion costs about an hour today: two packages, a branch in
`_directoryFor`, one row in `allowedDependencies`. After ten mini-apps it is a
migration. Decide early rather than by default.

This repository keeps them because it is a base to `make rename` into several
apps, some of which will meet the condition and some of which will not. A
derived project should read this section and choose, instead of inheriting both
concepts because they were there.

## Closing the DI gap

The obvious fix — give a mini-app `@InjectableInit.microPackage()` like a
feature — was considered and rejected. It would require the host to name the
mini-app in `app/lib/app/di/injection.dart` as well as in `bootstrap.dart`,
which removes the independence this ADR is about and leaves a mini-app strictly
no better off than a feature.

What replaces the generator's warning is a test that opens the mini-app for
real: `app/test/app_smoke_test.dart` boots with a session, finds the entry point
on home, taps it, and asserts the screen renders. That exercises
`MiniAppRegistry.entryPointsFor`, the host's rendering of the entry, `onOpen`,
the route, and every dependency `registerDependencies` was supposed to provide.
A missing registration fails there with the production error.

**A new mini-app must extend that test.** Its own package tests cannot cover
this: they can assert what it registers, not that the host reached it.

## Rejected alternatives

- **Mini-apps as folders in the host.** Nothing to enforce, which is where the
  previous version ended up.
- **Mini-apps as separate Flutter modules / add-to-app.** Real isolation, but a
  different runtime, a plugin bridge, and a much larger build. Not warranted for
  code that ships in the same binary.
