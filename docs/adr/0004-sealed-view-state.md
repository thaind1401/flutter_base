# 0004 — Sealed `ViewState`, unsealed `PagedViewState`

**Status:** Accepted

## Context

The previous base state was:

```dart
class BaseBlocState<T> {
  final BaseStateEnums status;  // init|loading|refreshing|success|empty|error|…
  final T data;
  final Object? error;
  final String? message;
}
```

It permits states that cannot exist — `status: error` with data and no error
object — and every widget re-checked nullability the compiler could not verify.
`error` being `Object?` meant error rendering was a chain of `is` checks.

## Decision

`ViewState<T>` is sealed: `ViewIdle`, `ViewLoading`, `ViewData`, `ViewEmpty`,
`ViewFailed`. If you have a `ViewData` you have data; if you have a `ViewFailed`
you have a `Failure`.

`PagedViewState<T>` is **not** sealed. A paginated list is genuinely in several
conditions at once — 40 items loaded, page 3 in flight, page 2 failed — so a
closed set of states would be an enum crossed with itself. Its invariants are
enforced by transition methods (`refreshing()`, `appended()`, `failed()`)
instead.

## Consequences

**Good**

- `switch` over a `ViewState` is exhaustive and checked.
- Impossible states are unrepresentable.
- `ViewFailed.lastData` lets a screen keep stale content under an error banner
  rather than replacing what the user was reading.
- `ViewStateBuilder` renders all five branches, so a screen's build method is
  its content and nothing else.

**Costs**

- Two shapes to learn. The asymmetry is the point, and it is documented at the
  top of both files.
- `ViewData.isRefreshing` is a flag on a sealed state, which is a small
  compromise — a separate `ViewRefreshing` state would force screens to handle
  "refreshing over data" and "loading with no data" identically.

## Rejected alternatives

- **`freezed` unions.** Equivalent ergonomics, plus a codegen step. Dart 3 sealed
  classes cover it without one.
- **Sealing `PagedViewState` too.** Attempted; it produced
  `PagedLoadingMoreWithItemsAndPreviousError`, which is a sign the model is wrong.
