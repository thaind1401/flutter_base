# 0001 — `Result<T>` instead of thrown exceptions

**Status:** Accepted

## Context

The previous generation of this codebase had every repository extend a
`BaseRepository` whose `call()` caught exceptions and rethrew them as
`BaseException` subclasses. Callers were expected to `try/catch`.

Two problems showed up repeatedly in review:

- A thrown exception is invisible in a function signature. Nothing told a bloc
  author that `getAttendanceHistory()` could fail, so the `catch` was often
  missing and the failure surfaced as a red screen.
- New exception subclasses were added over time. Existing `catch` chains did not
  know about them, so they fell through to a generic "something went wrong"
  toast — sometimes for months, until QA hit the path.

## Decision

Anything fallible returns `Result<T>`, a sealed type with `Ok` and `Err`.
`Failure` is also sealed. Exceptions are converted exactly once, at the
repository boundary, by `BaseRepository.guard`.

## Consequences

**Good**

- The compiler reports a `switch` that misses a failure case.
- `try/catch` disappears above the data layer entirely — grep for it as a smell.
- Error paths are trivially testable: construct an `Err` and assert.
- `flatMapAsync` composes multi-step use cases without nested `switch`.

**Costs**

- More typing than `await repo.thing()`. Accepted: the verbosity is where the
  error handling used to be missing.
- Callers can ignore a `Result` (Dart has no `#[must_use]`). Mitigated by
  `unawaited_futures` being an error and by review.
- Third-party callbacks that must throw need `AppException` as an escape hatch.

## Rejected alternatives

- **`dartz`/`fpdart` `Either`.** `Either<L, R>` reads backwards to most Flutter
  developers, drags in a functional-programming vocabulary the team does not
  otherwise use, and adds a dependency for a 200-line type.
- **Keeping exceptions but making the hierarchy sealed.** Sealing helps, but the
  signature still does not say the call can fail, which was the main problem.
