# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## Toolchain

- **FVM** pins the Flutter SDK (`.fvmrc`: 3.41.9). Every command goes through
  `fvm flutter` / `fvm dart`, or the `make` targets which already do.
- Dart `>=3.8.0`, Java 17 for Android builds.
- **Formatter page width is 120**, set in the root `analysis_options.yaml`.
  Always `make fmt`, never a bare `dart format`.

## Commands

```bash
make setup        # fresh clone: SDK + env files + pub get + l10n + codegen + hooks
make sdk          # materialise the FVM symlink pinned in .fvmrc
make env          # env_config/*/dart_defines.json from the tracked samples
make get          # resolve the workspace
make hooks        # point git at .githooks/ (pre-push: fmt-check + analyze)
make codegen      # build_runner in every package that needs it
make codegen-watch PKG=app
make l10n         # regenerate core_ui localizations from ARB
make analyze
make fmt          # apply
make fmt-check    # verify — this is what CI runs
make test                              # every package
make test PKG=core/core_storage        # one package
make test PKG=app ARGS="--name boots"  # one test
make test-coverage # per-package floor + workspace threshold
make check-deps   # architecture boundaries + the Makefile package lists
make check-artifacts # fail if build output or generated code is tracked by git
make ci           # the full gate
make dev|stg|prod
make rename NAME="My App" ORG=com.acme.myapp
```

**The Makefile is the only place package lists live.** `.github/workflows/ci.yml`
runs `make` targets and overrides `FLUTTER=flutter DART=dart`, because runners
install the SDK directly instead of through FVM. It used to inline its own
`for pkg in ...` loops; they drifted from `CODEGEN_PACKAGES`, and CI stopped
generating `core_ui/lib/di.module.dart` while the barrel still exported it.
Do not reintroduce a package list anywhere outside this Makefile.

VS Code launch configurations live in `.vscode/launch.json` (tracked). They set
`cwd` to `app` because `--dart-define-from-file` resolves relative to the
working directory, and use `toolArgs` rather than `args` so the flags reach the
`flutter` tool instead of the Dart program.

Run one test file:

```bash
cd features/feature_auth && fvm flutter test test/login_bloc_test.dart
```

## Structure

Pub workspace: one resolution, one `pubspec.lock` at the root, every package
declares `resolution: workspace`.

Packages are grouped by kind, and each directory keeps its full package name —
`package:core_ui/...` lives in `core/core_ui/`.

| Path | Role |
|---|---|
| `core/core_kit` | Pure Dart: `Result`, `Failure`, extensions, form inputs, logging |
| `core/core_storage` | Secure / preference / in-memory stores behind interfaces |
| `core/core_network` | Dio, interceptors, `DioFailureMapper`, connectivity |
| `core/core_arch` | `UseCase`, `BaseRepository`, `BaseBloc`, `ViewState`, routing bases |
| `core/core_ui` | Tokens, themes, widgets, overlays, l10n |
| `mini_apps/mini_app_contract` | Host ↔ mini-app boundary |
| `features/feature_auth` | Reference vertical slice |
| `app` | Composition root: DI, router, shell, session |

The group is derived from the name prefix, not configured: `core_*` → `core/`,
`feature_*` → `features/`, `mini_app_*` → `mini_apps/`. A package that does not
follow the convention fails `make check-deps`.

Dependencies flow downward only and are **enforced** by
`tools/check_dependencies.dart`. Adding an edge means editing
`allowedDependencies` deliberately, in the same commit as the import.

## Rules that are not negotiable

1. **Nothing above the data layer throws.** Repositories return `Result<T>` via
   `BaseRepository.guard`. A `try/catch` in a use case or a bloc is a bug.
2. **Use case parameters are typed records** — `typedef P = ({String id});` —
   never `Map<String, dynamic>`.
3. **Blocs depend on use cases only.** Never a repository, `Dio`, or storage.
4. **One-shot outcomes are effects**, emitted with `emitEffect`, not state flags.
5. **A feature never imports another feature.** Use a contract in a core package.
6. **No literals in widgets.** `context.colors.*`, `context.dimens.*`,
   `context.textStyles.*`. Missing token → add it to the token class.
7. **`core_kit` never imports Flutter.**
8. **Choose bloc event transformers deliberately** — `droppable()` for submit and
   load-more, `restartable()` for refresh and search. The default is wrong for
   all of them.
9. **Generated code is not committed** (`*.g.dart`, `*.config.dart`,
   `*.module.dart`, `l10n/generated/`). Enforced by `make check-artifacts`,
   which is in `make ci`. `.gitignore` alone does not enforce it — it applies
   only to files git is not already tracking, so anything committed before its
   rule existed stays tracked and no amount of ignoring removes it. That is how
   ten generated files, 197 build outputs and a whole FVM SDK got in here.
10. **Every screen extends one of three bases**, and never writes its own
    scaffold: `BaseScreen` for one block of data or a form, `BaseListScreen<B,T>`
    for a paginated list, `BaseGridScreen<B,T>` for a paginated grid. All three
    are in `core_ui`. The base owns the chrome — keyboard dismissal, safe area,
    bottom bar above the home indicator, back-button policy — so a screen cannot
    forget it. Override `buildBody`; `build` is `@nonVirtual`.

    Pagination, not the widget, decides the base. A `ListView` of data that
    arrives complete is a `BaseScreen` (`HomeScreen`) — reaching for
    `BaseListScreen` there demands an `onLoadMore` with nothing to load. A plain
    screen has no paging API at all: those hooks live on a private intermediate
    class, so `onLoadMore` does not compile on a `BaseScreen` subclass.
11. **Inside `buildBody`, a screen is a tree of small `const` widgets, each on
    its own `BlocSelector`.** One per region that changes independently,
    selecting the narrowest slice it renders; a **record** when it needs two
    fields, because records have value equality. The base wraps `buildBody` in
    no builder and subscribes to nothing, so this rule is unchanged by rule 10.
    `BlocBuilder` without `buildWhen` only when the whole state is the one thing
    on screen — which is why `BaseListScreen` may use one internally;
    `BlocBuilder` with `buildWhen` is a last resort, because the condition and
    the data the builder reads are separate expressions that drift silently.
    Copy `login_screen.dart`. ADR-0008.
12. **State carries what the view renders.** A field shown on screen but read
    from outside the state — a getter on the cubit, `getIt`, a service — never
    triggers a rebuild when it changes. `HomeScreen` displayed
    `context.read<SessionCubit>().user` while rebuilding on `SessionStatus`, so
    a profile change at a steady status never appeared.
13. **Every state class extends `Equatable` and lists every field in `props`.**
    `BlocSelector` and `buildWhen` both decide by `==`. A missing field means
    that field never rebuilds anything. `core_arch` re-exports `Equatable`.

## Code generation

Run `make codegen` after changing:

- `@JsonSerializable` models, `@RestApi` data sources → that package
- `@injectable` / `@lazySingleton` annotations → that package
- ARB files → `make l10n`

## Before saying a change is done

`make fmt` + `make analyze` + `make test` + `make check-deps` +
`make check-artifacts` — or just `make ci`. A change is not done until that is
green.

**Green is necessary, not sufficient.** This whole gate once passed while the
app could not open: `core_ui` carried a `@lazySingleton` but had no
micro-package module, so `LoadingOverlayController` went unregistered and
`App.build` threw on the first frame — a white screen, with `analyze`, `test`
and `check-deps` all reporting success. Nothing in the gate built a widget.

So, in addition:

- **Run the app** (`make dev`, or a VS Code launch configuration) and look at
  it. If you cannot, say so plainly rather than reporting the change as done.
- **A change to wiring, routing, theming, or startup needs a test that
  builds.** `app/test/app_smoke_test.dart` runs the real `Bootstrap.run()` and
  pumps the real `App` — extend it rather than trusting a unit test to notice
  that the tree no longer renders.
- **A new package carrying injectable annotations** must declare
  `@InjectableInit.microPackage()` in its `lib/di.dart`, export its generated
  module from its barrel, appear in `externalPackageModulesBefore`, and be
  listed in `CODEGEN_PACKAGES` in the `Makefile`. Miss any one and the
  registration is silently absent. `injection_test.dart` asserts one type per
  module, and `make check-deps` now fails if a package carrying a codegen
  annotation is missing from `CODEGEN_PACKAGES` — or is listed there while
  annotating nothing, which was costing a pointless `build_runner` run in
  `core_arch`.
- **This base ships no mini-app.** `mini_app_contract` and `MiniAppRegistry`
  remain, and `Bootstrap.run()` passes an empty list, so a package written
  against the contract drops in without rebuilding the mechanism. The reference
  implementation was deleted — the condition in ADR-0007 did not hold — so
  **read ADR-0007 before adding one at all**: it states the single condition
  under which a mini-app beats a plain feature, and a `feature_*` package with a
  `RouteModule` is the right answer unless that condition is met.
- **A new mini-app must extend `app/test/app_smoke_test.dart`** so its entry
  point is tapped and its screen renders. Mini-apps register at runtime through
  `registerDependencies(getIt, host)`, not through a micro-package module, so
  they get no build-time warning for a missing registration — opening the screen
  is the only thing that notices. That test does not exist right now, because
  there is no mini-app to tap; `app_smoke_test.dart` says so where it used to
  live. Restoring it is part of adding a mini-app, not optional follow-up.
- **A new package arrives with tests.** `make check-deps` fails if any workspace
  package has no `*_test.dart`, or has tests that `TEST_PACKAGES` never runs.
  There is a `packagesWithoutTests` escape hatch in
  `tools/check_dependencies.dart`; it is currently empty and an entry that later
  gains tests is reported as stale. `make test-coverage` adds a per-package
  floor on top, so a package cannot sit at 0% behind a healthy workspace total.
- **Do not write a comment or an ADR asserting a guarantee you have not
  implemented.** ADR-0003 claimed the DI graph was "verified by a test rather
  than by launching the app" while the test was a hand-written list that
  omitted `core_ui`. Confident prose about a safety net that does not exist is
  worse than no prose: it stops the next reader from checking.

## Context

- `docs/architecture.md` — the layer graph, data flow, failure handling, state.
- `docs/adding_a_feature.md` — the checklist for a new feature.
- `docs/adr/` — why each decision was made and what was rejected. **Read the
  relevant ADR before proposing a change to an architectural pattern.**
- `docs/theming.md`, `docs/flavors.md`.
- `.claude/README.md` — how this file, the permissions in
  `.claude/settings.json`, the Dart format hook and the Cursor rules fit
  together. This file is the contract and the Cursor rules attach it rather than
  restating it, so a new rule goes in exactly one place.

## Conventions

- Strict null safety; avoid `dynamic` and untyped `var`.
- Do not add packages or change `pubspec.yaml` versions without a stated reason.
- Do not relax `analysis_options.yaml` globally; scope an exception to the line.
- Before a broad multi-file change, summarize the plan in 2–4 bullets and note
  the risks.
- Never put credentials, tokens, or personal data in commit messages, comments,
  or generated docs. `LogRedactor` is a safety net, not a licence to log
  payloads.
