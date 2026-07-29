# 0003 — Per-package DI modules, not a host ignore list

**Status:** Accepted — see the correction at the end, which withdraws one of the
claims below.

## Context

The previous host app carried this:

```dart
@InjectableInit(
  ignoreUnregisteredTypes: [
    app_domain.FileStorage, app_ui.ThemeManager, app_domain.UserSession,
    /* …30 more… */
  ],
  ignoreUnregisteredTypesInPackages: ['package:app_domain/app_domain.dart', ...],
)
```

Every entry suppressed a real "I cannot see this registration" warning from the
generator, because packages did not declare their own DI. The list only ever
grew: nobody could tell which entries were still needed, and removing one to
find out risked a runtime failure on a device.

The net effect was that DI verification was switched off for the whole app.

## Decision

Every package declares its own module:

```dart
@InjectableInit.microPackage()
void initCoreStoragePackage() {}
```

The composition root composes them in dependency order with
`externalPackageModulesBefore`. Wiring that genuinely spans packages —
`ApiClient` needs `feature_auth`'s delegate and `app`'s request context — lives
in `app/lib/app/di/app_module.dart`, because only the root can see all of it.

`app/test/injection_test.dart` resolves the entire graph.

## Consequences

**Good**

- A missing registration inside a package is a build warning again.
- `injection.dart` reads as a list of packages, which is the architecture.
- The DI graph is verified by a test rather than by launching the app.

**Costs**

- A feature package still needs `ignoreUnregisteredTypesInPackages: ['core_kit',
  'core_network', 'core_storage']`, because the generator cannot see across
  package boundaries. This is three package *names*, not thirty types, and it
  does not hide anything the package itself owns.

## Rejected alternatives

- **Manual registration, no codegen.** Explicit, but a 100-entry `registerX`
  file is a merge conflict on every branch and drifts from the constructors.
- **Constructor injection with no container.** Workable in a small app; the
  wiring for nine packages would be several hundred lines in `main`.

## Correction

Two claims above were false when written.

> `app/test/injection_test.dart` resolves the entire graph.

> The DI graph is verified by a test rather than by launching the app.

The test was a hand-written list of nine assertions, not a traversal of the
graph. It omitted `core_ui` entirely — and `core_ui` had no `lib/di.dart`, was
absent from `externalPackageModulesBefore`, and was absent from
`CODEGEN_PACKAGES`. `LoadingOverlayController` therefore carried a
`@lazySingleton` that generated no registration, and `App.build` threw
`GetIt: ... not registered` on the first frame. The app showed a white screen
while `analyze`, `test` and `check-deps` all passed.

The decision in this ADR is sound and stands. What failed was the enforcement:
the ignore list was replaced, but nothing checked that every annotated package
actually declared a module. A hand-maintained list of assertions has the same
failure mode as the hand-maintained ignore list it replaced — it drifts, and it
drifts silently.

What now holds the invariant:

- `app/test/app_smoke_test.dart` runs the real `Bootstrap.run()` and pumps the
  real `App`. It fails with the production error if any registration the first
  frame needs is missing. Verified by reverting the fix and watching it fail.
- `injection_test.dart` asserts one resolvable type per external module, so a
  package left out of `externalPackageModulesBefore` fails a test.
- `tools/check_dependencies.dart` compares `CODEGEN_PACKAGES` against the tree:
  a package carrying an injectable annotation and missing from the list fails
  `make check-deps`. This is the piece that was missing — the three items above
  it all depend on somebody having remembered to run codegen for the package in
  the first place. Verified by removing `core_ui` from the list and watching the
  check name it.
- The checklist in `CLAUDE.md` names the four places a new injectable package
  must be registered.

One more instance of the same drift surfaced while fixing this: the CI workflow
kept its own copy of the codegen package list, and that copy was never updated.
CI would have failed to generate `core_ui/lib/di.module.dart` even after the
white screen was fixed locally. The workflow now calls `make` targets and holds
no package list of its own.

The general lesson is recorded in `CLAUDE.md`: do not write a comment or an ADR
asserting a guarantee that has not been implemented. Confident prose about a
safety net that does not exist is worse than no prose, because it stops the next
reader from checking.
