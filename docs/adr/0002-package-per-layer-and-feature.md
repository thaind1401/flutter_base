# 0002 — One package per layer and per feature

**Status:** Accepted

## Context

The previous structure was four large packages: `app` (476 files), `app_domain`
(282), `app_ui` (123) and `core` (51). Every feature's screens lived in `app`,
and every feature's domain lived in `app_domain`.

The effects:

- Nothing prevented a screen from importing another feature's repository, and
  several did.
- `core` had become a grab bag: network, DI bootstrap, routing, dialog and toast
  managers, base blocs, extensions. Anything that needed one of those pulled in
  all of them, including Flutter, so no part of it could be unit-tested without
  a widget binding.
- Touching one feature invalidated the whole `app` package's build.
- Extracting a feature for another product meant untangling it by hand.

## Decision

- **A package per core concern**: `core_kit` (pure Dart), `core_storage`,
  `core_network`, `core_arch`, `core_ui`.
- **A package per feature**, containing its own domain, data and presentation.
- **A package per mini-app**.
- The host `app` is the composition root and owns almost no logic.
- Boundaries are enforced by `tools/check_dependencies.dart` in CI.

## Layout

Packages are grouped by kind — `core/`, `features/`, `mini_apps/` — with `app/`
at the root. Two rules make the grouping hold:

- **Directory name = package name.** `package:core_ui/...` lives in
  `core/core_ui/`. The stutter is deliberate: shortening it to `core/ui/` makes
  every import require a translation step, and a grep for the package name stops
  finding the directory.
- **The prefix decides the group**, and `tools/check_dependencies.dart` derives
  the path from it rather than reading a configured map. A package named
  `shared_utils` therefore resolves to no group, is not found, and is reported —
  so a fourth, unnamed category cannot appear without someone noticing.

Two alternatives were tried and rejected in practice. A **single `packages/`
directory** hides the distinction between a core layer, a feature and a
mini-app, which is the distinction the dependency rules are about. A **flat
root** removes one path level but puts nine sibling directories next to `docs/`
and `tools/`, and the grouping then exists only in the naming.

`make check-deps` also compares the pubspec's `workspace:` list against the
dependency table in both directions, because a package missing from the table
would otherwise be exempt from every rule here.

## Consequences

**Good**

- A forbidden import fails the build instead of being found in review, or not.
- `core_kit` has no Flutter dependency, so its tests run under `dart test`.
- A feature can be deleted, extracted or reused by moving one directory.
- Incremental builds only recompile the packages that changed.

**Costs**

- More `pubspec.yaml` files. Mitigated by the pub workspace: one resolution, one
  lockfile, no version drift.
- Adding a feature touches several registration points. They are listed in
  `docs/adding_a_feature.md`, and the alternative is a host that imports
  everything.
- Cross-feature communication needs a contract in a core package rather than a
  direct import. This is the intended friction.

## Rejected alternatives

- **Folder-based feature separation in one package.** Costs nothing to violate;
  the previous codebase is the evidence.
- **A package per feature *and* per layer** (`feature_auth_domain`,
  `feature_auth_data`, …). Triples the package count for a boundary that is
  already enforced by the directory structure and reviewed in the same PR.
