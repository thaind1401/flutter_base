# Architecture decisions

Each file records one decision: what was chosen, what was rejected, and what it
costs. The rejected options matter most — without them a future reader has no
way to tell a considered choice from an accident, and re-litigates it.

| # | Decision | Status |
|---|---|---|
| [0001](0001-result-instead-of-exceptions.md) | `Result<T>` instead of thrown exceptions | Accepted |
| [0002](0002-package-per-layer-and-feature.md) | One package per layer and per feature | Accepted |
| [0003](0003-di-micro-packages.md) | Per-package DI modules, not a host ignore list | Accepted |
| [0004](0004-sealed-view-state.md) | Sealed `ViewState`, unsealed `PagedViewState` | Accepted |
| [0005](0005-modular-routing.md) | Route modules and guard objects | Accepted |
| [0006](0006-dart-define-environments.md) | Environments via dart-define, not platform flavors | Accepted |
| [0007](0007-mini-app-contract.md) | Mini-apps talk to the host through a contract only | Accepted |
| [0008](0008-rebuild-scope.md) | A screen is a tree of small widgets, each selecting one slice of state | Accepted |
| [0009](0009-screen-bases.md) | Every screen extends one of three bases | Accepted |
| [0010](0010-accessibility-and-goldens.md) | Accessible names and golden snapshots belong to the design system | Accepted |
