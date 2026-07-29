---
description: Run the full quality gate, then the checks the gate cannot make
allowed-tools: Bash(make ci), Bash(make test *), Bash(make dev), Read, Grep, Glob
---

Verify the current change.

## 1. The gate

Run `make ci` (fmt-check + analyze + test + check-deps). If anything is red,
fix it and run again — do not report progress against a red gate.

## 2. The checks the gate cannot make

`make ci` has passed on a build that could not open. `core_ui` carried a
`@lazySingleton` with no micro-package module, `LoadingOverlayController` went
unregistered, and `App.build` threw on the first frame — analyze, test and
check-deps all green, because nothing in the gate built a widget.

So after the gate is green, confirm each of these or say plainly that you did
not:

- **Does the app still open?** If this change touched DI, routing, theming, or
  startup, that is not optional. Either run it, or extend
  `app/test/app_smoke_test.dart` — it boots the real `Bootstrap.run()` and pumps
  the real `App`.
- **New package with injectable annotations?** It needs all five:
  `@InjectableInit.microPackage()` in `lib/di.dart`, the generated module
  exported from the barrel, an entry in `externalPackageModulesBefore`, a line
  in `CODEGEN_PACKAGES`, and an assertion in `app/test/injection_test.dart`.
  Four out of five registers nothing, silently.
- **Does anything you wrote claim a guarantee you did not implement?** Re-read
  the comments and doc changes in this diff. ADR-0003 once described a DI test
  that did not check what it said it checked; confident prose about a
  non-existent safety net is worse than no prose, because it stops the next
  reader from looking.

## 3. Report

State what you ran, what passed, and what you could not verify. "I did not run
the app" is a complete and acceptable answer. "Done" without it is not.
