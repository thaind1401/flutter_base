---
description: Scaffold a new feature package following the repo's checklist
argument-hint: <feature_name, e.g. orders>
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(make codegen *), Bash(make check-deps), Bash(make get), Bash(make analyze)
---

Add a feature package for: **$ARGUMENTS**

Read `docs/adding_a_feature.md` first and follow it. Do not work from memory of
how Flutter features are usually laid out — the registration steps in that file
are the part people get wrong, and four of the five are silent when missed.

`features/feature_auth` is the worked example. Prefer copying its shape over
inventing one.

Two things the checklist assumes you already know:

- Read `docs/adr/` before deviating from a pattern. Each ADR records what was
  rejected and why, so a "simpler" alternative has usually already been tried.
- The layer boundaries in `tools/check_dependencies.dart` are enforced, not
  advisory. A feature may not import another feature. If the new package
  genuinely needs something a sibling owns, the answer is a contract in a core
  package — raise it rather than widening `allowedDependencies` quietly.

Finish with `make check-deps` and `make analyze`, then report which registration
steps you completed and which you left to me.
