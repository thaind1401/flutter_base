# 0006 — Environments via dart-define, not platform flavors

**Status:** Accepted

## Context

The previous project used Android product flavors plus iOS schemes for
`dev`/`stg`/`prod`. That works, but it means a fresh clone does not run until
someone has duplicated three Xcode schemes and three build configurations by
hand — and `flutter run` without `--flavor` fails outright once Android product
flavors exist.

For a template that is cloned repeatedly, that setup cost is paid every time.

## Decision

Environments are selected with `--dart-define-from-file`. One bundle id, three
config files under `app/env_config/`. `AppEnvironmentConfig.fromEnvironment()`
is the only place `String.fromEnvironment` is called.

`docs/flavors.md` documents how to add real platform flavors for projects that
need all three installed side by side.

## Consequences

**Good**

- `make dev` works on a fresh clone on both platforms with no Xcode work.
- The full set of build-time inputs is one class.
- CI needs no scheme setup.

**Costs**

- Only one build can be installed on a device at a time. This is the main
  trade-off, and it is the reason `docs/flavors.md` exists.
- Per-environment Firebase config files need the platform-flavor setup anyway.

## Rejected alternatives

- **Ship with flavors configured.** Adds real value only to projects that need
  side-by-side installs, and makes the template fail to run out of the box for
  everyone else until iOS schemes are created.
- **Separate `main_dev.dart` entry points.** Duplicates bootstrap per flavor and
  diverges silently.
