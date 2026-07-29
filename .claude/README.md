# AI assistant configuration

Two assistants, one set of rules. `CLAUDE.md` at the repository root is the
contract; everything here and in `.cursor/` exists to make sure both tools
actually read it.

## Where the rules live

| File | Read by | Contains |
|---|---|---|
| `CLAUDE.md` | Claude Code, automatically | The contract: toolchain, structure, non-negotiables, definition of done |
| `docs/architecture.md`, `docs/adr/` | Both, on demand | Why each decision was made, and what was rejected |
| `.cursor/rules/00-project.mdc` | Cursor, always | Attaches `CLAUDE.md`, plus the working agreement and verification rules |
| `.cursor/rules/*.mdc` | Cursor, by glob | File-type specifics: Dart placement, pubspec, tooling, tests |

**Rules are not duplicated between these files.** Cursor does not load
`CLAUDE.md` on its own, so `00-project.mdc` references it with `@CLAUDE.md` and
instructs the model to open it if the reference does not resolve — rather than
restating the contents, which is how the two copies drift apart. A new rule goes
in exactly one of these files.

## `settings.json` vs `settings.local.json`

- **`.claude/settings.json`** — committed, shared by the team. Read-only and
  safe commands are pre-approved so nobody sits through a prompt for
  `make analyze`. Destructive and outward-facing commands are in `ask`; a short
  `deny` list covers force-push, `rm -rf`, and the gitignored files that hold
  real URLs and signing keys.
- **`.claude/settings.local.json`** — gitignored, personal. Put commands you
  individually trust here (your `adb` invocations, a local script). It is not
  in the repo and does not need to be.

Do not put architecture or coding rules in either file. They are permissions
only.

## The format hook

`.claude/hooks/format-dart.sh` runs `dart format --page-width=120` on every Dart
file Claude edits, immediately after the edit.

The width here is 120 and every tool's default is 80, so without this a session
lands at the wrong width and the failure surfaces minutes later as a red
`make fmt-check` inside a diff too large to attribute. It skips generated files,
falls back to a non-FVM `dart` if FVM is absent, and always exits 0 — it is a
convenience, not a gate. The gate is `make fmt-check`, in `.githooks/pre-push`
and in CI.

Cost is roughly one Dart VM start per edit. To disable it, delete the `hooks`
block from `settings.json`.

## Slash commands

- **`/verify`** — runs `make ci`, then walks the checks the gate cannot make:
  does the app still open, is a new DI module registered in all five places,
  does anything in the diff claim a guarantee that was not implemented. Use it
  before saying a change is done.
- **`/new-feature <name>`** — drives `docs/adding_a_feature.md` rather than
  improvising a package layout. Most of the registration steps fail silently
  when skipped, which is exactly the kind of thing a model does from memory.

## If this directory goes missing

It has happened once: the project was copied with `cp -r flutter_base/* …`,
which does not match dotfiles, and `.claude`, `.cursor`, `.vscode`, `.githooks`,
`.github`, `.gitignore` and `.fvmrc` were all silently left behind. Nothing
failed loudly — the build still worked, the assistants just quietly lost every
guardrail, and the missing `.gitignore` committed 575 MB of `build/test_cache`
`.dill` files and `.dart_tool` snapshots.

Copy the repository with `git clone`, or with `cp -a src/. dest/` — the trailing
`/.` is what includes hidden entries.
