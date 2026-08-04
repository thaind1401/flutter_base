# Flutter Base

A production-shaped Flutter application base: clean architecture, one package
per layer, one package per feature, and a composition root that wires them
together.

It is meant to be **copied**, not depended on. Clone it, run `make rename`, and
start deleting what you do not need.

```bash
git clone <this repo> my_app && cd my_app
make rename NAME="My App" ORG=com.acme.myapp
make setup      # SDK + env files + deps + l10n + codegen
make dev        # or press F5 in VS Code
```

---

## Repository layout

Packages are grouped by **what kind of thing they are**, and each directory
keeps its full package name:

```
flutter_base/
├── app/                        host application — DI, router, shell, session
│
├── core/                       shared layers, no business domain
│   ├── core_arch/              use case · repository · bloc · view state · routing
│   ├── core_kit/               pure Dart — Result, Failure, extensions, forms
│   ├── core_network/           Dio, interceptors, failure mapping, connectivity
│   ├── core_storage/           secure / preference / in-memory stores
│   └── core_ui/                design tokens, themes, widgets, overlays, l10n
│
├── features/                   vertical slices — domain + data + presentation
│   └── feature_auth/           reference implementation — read this first
│
├── mini_apps/                  pluggable apps, contract-only coupling
│   └── mini_app_contract/      host ↔ mini-app boundary (no mini-app ships)
│
├── docs/                       architecture, ADRs, theming, flavors
├── tools/                      rename, dependency guard, coverage
│
├── Makefile                    every workflow; CI runs these exact targets
├── analysis_options.yaml       one lint config for the whole workspace
└── pubspec.yaml                the pub workspace — one resolution, one lockfile
```

Two conventions keep this navigable as the repo grows:

- **The directory name is the package name.** `package:core_ui/…` lives in
  `core/core_ui/`, so a grep for the package name finds the directory. The mild
  stutter in `core/core_kit` is what buys that; shortening it to `core/kit`
  would mean every import needs a translation step in your head.
- **The name prefix decides the group**, and `make check-deps` derives the path
  from it. A package called `shared_utils` resolves to no group, fails to be
  found, and is reported — so a fourth, unnamed category cannot appear quietly.

Of the eight packages, six are infrastructure. `feature_auth` is a reference
implementation meant to be replaced, and `app` is your application. Starting a
real project is closer to "six packages plus your code" than to eight.

---

## What is in the box

| Package | Role | Depends on |
|---|---|---|
| `core_kit` | `Result`, `Failure`, extensions, form inputs, logging. **Pure Dart** | — |
| `core_storage` | Secure / preference / in-memory key-value stores behind interfaces | `core_kit` |
| `core_network` | Dio client, interceptors, the one place exceptions become `Failure` | `core_kit` |
| `core_arch` | Use case, repository, bloc, view-state and routing bases | `core_kit` |
| `core_ui` | Design tokens, themes, shared widgets, overlays, l10n | `core_kit`, `core_arch` |
| `mini_app_contract` | The host ↔ mini-app boundary — kept so one can be added later; no mini-app ships (ADR-0007) | `core_kit`, `core_arch` |
| `feature_auth` | **Reference vertical slice** — read this first | core packages |
| `app` | Composition root: DI, router, shell, session gate | everything |

The dependency table is enforced, not documented: `make check-deps` fails the
build if a package imports across a forbidden boundary.

---

## Daily commands

```bash
make setup        # fresh clone: SDK + env files + pub get + l10n + codegen
make dev          # run the dev flavor
make codegen      # after changing a model, an API or a DI annotation
make test         # every package (golden snapshots excluded)
make golden       # design-system snapshots, light and dark
make integration  # on a booted device/emulator — not part of `make ci`
make ci           # the full gate — what CI runs
make check-deps   # architecture boundaries
make l10n         # regenerate localizations after editing an ARB
make check-l10n   # locales, keys and delegates agree across l10n packages
make help         # everything else
```

Flutter is pinned with FVM (`.fvmrc`). Every command goes through `fvm`, so a
teammate on a different SDK cannot produce a different build.

### VS Code

`.vscode/` is tracked, so a clone gets working launch configurations, the right
SDK path and the 120-column formatter without anyone configuring it:

| Configuration | Use it for |
|---|---|
| `app · dev` / `stg` / `prod` | Everyday debugging against each environment |
| `app · prod (profile)` | Measuring jank — debug-mode frame timings are fiction |
| `app · prod (release)` | Reproducing a bug that only appears with obfuscation |
| `app · attach` | Attaching to an app already running from `make dev` |

Two details these depend on and that `make setup` handles: the working
directory is `app/` (the app package is not at the root, and
`--dart-define-from-file` resolves relative to it), and
`app/env_config/*/dart_defines.json` must exist — it is gitignored, so
`make env` creates it from the tracked samples.

### Claude Code and Cursor

`.claude/` and `.cursor/` are tracked too, so both assistants pick up the same
guardrails on a fresh clone: pre-approved read-only commands, a `deny` list over
the files holding real URLs and signing keys, a hook that formats edited Dart at
120 columns, and `/verify` and `/new-feature` commands.

`CLAUDE.md` is the single contract — the Cursor rules attach it rather than
restating it, because two copies of a rule become two different rules. See
`.claude/README.md` for what lives where.

---

## Where to start reading

1. **`feature_auth`** — a complete feature: entity, repository
   interface, implementation, use cases, Retrofit data source, bloc, screen,
   route module. Every new feature is this shape.
2. **`app/lib/app/di/injection.dart`** — how the packages are composed.
3. **`docs/architecture.md`** — the rules and the reasoning behind them.
4. **`docs/adr/`** — why each significant decision was made, including the ones
   that were rejected.

---

## Adding things

| Task | Where |
|---|---|
| A new feature | `docs/adding_a_feature.md` |
| A new mini-app | read ADR-0007 first — a `feature_*` is usually right; if not, write against `mini_app_contract` and add one line in `app/lib/app/bootstrap.dart` |
| A new screen in an existing feature | that feature's `presentation/` + its `RouteModule` |
| Brand colours, fonts | `docs/theming.md` |
| A new environment variable | `core/core_kit/lib/src/config/app_environment.dart` + `app/env_config/*` |

---

## The rules, in one screen

- **Nothing above the data layer throws.** Repositories return `Result<T>`;
  `Failure` is a sealed type so `switch` is exhaustive.
- **Use case parameters are typed records**, never `Map<String, dynamic>`.
- **A bloc depends on use cases only** — never a repository, Dio, or storage.
- **One-shot outcomes are effects, not state.** A "show toast" flag that must be
  cleared will eventually fire twice.
- **A feature never imports another feature.** Cross-feature needs go through a
  contract in a core package.
- **Widgets ask for meaning, not values**: `context.colors.danger`, never
  `Colors.red`; `context.dimens.space16`, never `16`.
- **Generated code is not committed.** A fresh clone runs `make setup`.
- **Retry is transport-level and idempotent-only.** Non-idempotent requests opt
  in per call; nothing retries a POST by default.
- **Connectivity is one global value**, rendered by one banner above the router
  — never a per-screen mixin.

---

## Platform flavors

Environments are selected with `--dart-define-from-file`, not with Android
product flavors or iOS schemes. One bundle id, three configurations:

```bash
make dev     # app/env_config/dev/dart_defines.json
make stg
make prod
```

`app/env_config/*/dart_defines.json` is gitignored; the `*.sample.json` files
next to them are the tracked templates. If a project genuinely needs separate
bundle ids per environment — so all three can be installed side by side — see
`docs/flavors.md`; it is a platform change, not a Dart one.

---

## Known gaps

Deliberately absent, because they are project decisions rather than base
architecture: a crash *reporter*, analytics, push notifications, deep links, and
biometric login. `Bootstrap.runDeferredStartup` is where they belong, and it
already runs after the first frame so adding one will not slow cold start.

The *collection* side is not absent. `GlobalErrorHandler` installs
`FlutterError.onError` and `PlatformDispatcher.onError` and reports both through
the registered `AppLogger`, so adopting Crashlytics or Sentry is the one-line
`AppModule` change `AppLogger` always advertised — not a hunt for the places
Flutter hands out errors. See "Failure handling end to end" in
`docs/architecture.md`.

**Transport security is the platform default, and that is a decision you have
not made yet.** There is no certificate pinning: `ApiClient` leaves Dio on its
default adapter, so the app trusts whatever the OS trusts, and a device with a
user-installed CA — a corporate MDM profile, or an attacker who talked someone
through installing one — can read every request. There is no root/jailbreak
detection either.

Both are genuinely project decisions: a pin needs *your* certificate and a
rotation plan, and a pin that outlives the cert it names is an app that cannot
reach its own backend until the store approves an update. What is not a project
decision is knowing the gap exists — so it is written here rather than left to
be discovered during a penetration test.

**Worse than absent: `AppEnvironmentConfig.enableCertificatePinning` is `true`
in production and is read by nothing.** `core_network` never consults it, and
two tests assert its value in dev and staging, so it looks both wired and
covered. Anyone auditing this base by reading the config would conclude
production traffic is pinned. It is not. The field now carries a doc comment
saying so; the alternative is deleting it, which is a call for whoever owns
this project rather than something a base should decide.

Two more things to know before adding a pin, both easy to get wrong here:

- **There are two places to apply it, not one.** `ApiClient` holds two clients
  (`_dio` and `_raw`), and `resetConnectionPool()` *replaces* their adapters with
  a fresh `IOHttpClientAdapter` after a network change — VPN on, wifi to
  cellular. A pin installed only at construction is silently discarded the first
  time the user walks out of wifi, and every request after that is unpinned with
  nothing in the logs to say so.
- **`badCertificate` is already routed correctly.** `DioFailureMapper` maps it to
  a `ServerFailure` rather than a `NetworkFailure`, with a comment saying why: a
  certificate mismatch can be an interception attempt, and "check your
  connection" is the wrong thing to tell the user. So a pin that starts failing
  surfaces as an error rather than as a retry loop — the base notices bad
  certificates, it just does not pin.

Present but needing your values before they do anything:

- **`.github/CODEOWNERS.sample`** — copy to `CODEOWNERS` and replace the handles.
  It ships as a sample because a CODEOWNERS naming a team that does not exist
  fails *silently*: GitHub cannot request the review, and the file sits there
  looking like coverage while everything merges unreviewed.
- **Store upload** — `.github/workflows/release.yml` builds and attaches the AAB,
  APK and debug symbols, and stops there. Signing identities and store
  credentials are per-project secrets; the last comment block in that file is the
  job to add once they exist.
- **`make env` copies the *samples*.** They are placeholders. Point the release
  workflow at real secrets before shipping anything from it.

Genuinely partial:

- **Golden tests render text as boxes.** `flutter test` ships no font, so the
  snapshots catch layout, spacing, colour and contrast but not font family or
  weight. Closing that means committing a font binary and a `FontLoader` — worth
  doing once this project picks a brand font. `core_ui/test/golden_test.dart`
  spells out exactly what each snapshot does and does not prove.
- **`core_arch` is now the weakest package at 79% coverage.** `app` used to hold
  that spot, and the reason it moved is worth keeping: the workspace total was
  a healthy 87% while `settings_screen.dart` sat at *one covered line out of
  forty* — a whole screen, owning the sign-out confirmation and a banner that
  prints the backend URL, tested by nothing. A percentage averages that away.
  The per-package floor in `tools/coverage_summary.dart` is what makes a gap
  like that surface at all, and it is still worth reading the per-file numbers
  rather than the headline.
- **Rule 5 has never actually been tested.** "A feature never imports another
  feature — use a contract in a core package" is enforced by
  `tools/check_dependencies.dart`, but `features/` holds exactly one package, so
  the rule has never had to *stop* anything. What the tool proves is that the
  import is blocked. What nobody has proved is the other half — that routing the
  need through a core contract is actually sufficient — because that question
  only arises when a second feature needs something `feature_auth` owns.

  Deliberately not closed by adding a filler feature. That is the mistake
  ADR-0007 already corrected once: the sample mini-app was deleted because it
  did not earn its place, and a `feature_profile` written only to exercise a
  lint would be the same package every project inherits and deletes. The first
  real second feature is what closes this — expect to discover something then,
  and expect the fix to be an entry in `allowedDependencies` plus a contract,
  not a relaxed rule.
