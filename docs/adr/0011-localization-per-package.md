# ADR-0011: Localization lives in the package that owns the copy

## Status

Accepted.

## Context

The base shipped `flutter_localizations`, a `CoreL10n` generated from
`core_en.arb` / `core_vi.arb`, and a delegate registered in `App.build`. It had
74 keys, all of them design-system chrome: errors, empty states, form
validation.

Every string a user actually read was a hardcoded English literal.
`login_screen.dart` said `'Welcome back'`, `'Email'`, `'Sign in'`;
`settings_screen.dart` said `'Appearance'` and `'Sign out'`; `app_shell.dart`
carried its tab labels in a `const` list.

That is worse than having no localization, for one specific reason:
`login_screen.dart` is the file CLAUDE.md rule 11 tells every new feature to
copy, and rule 13 tells authors to *"add the string to `core_en.arb`/`core_vi.arb`
rather than hardcoding it"*. The reference implementation contradicted the rule
it was meant to demonstrate, so the rule lost every argument it was in.

The question was not whether to translate the strings. It was where a feature's
strings live.

## Decision

**Each package that owns copy owns an ARB and generates its own localizations
class.** `core_ui` keeps `CoreL10n`; `feature_auth` gets `AuthL10n`; `app` gets
`AppL10n`. Access is through a per-package extension — `context.coreL10n`,
`context.authL10n`, `context.appL10n`.

**A package may read another package's localizations, downward only.** A feature
reading `CoreL10n.commonCancel` is correct and needs no new rule: doing so
requires `import 'package:core_ui/...'`, and `make check-deps` already arbitrates
that import. `core_ui` reading `AuthL10n`, or one feature reading another's,
fails the existing check for exactly the same reason. **Localization inherits
the layer graph rather than getting one of its own.**

**The app declares the supported locale set**, in its own ARB. Every other l10n
package must ship exactly that set.

**Mini-apps contribute delegates through the contract**
(`MiniApp.localizationsDelegates`, aggregated by `MiniAppRegistry`), because the
host names mini-app packages in one line of bootstrap and cannot name a class
inside one.

## Rejected: one ARB in `core_ui`

Cheapest by a wide margin — the generation, the delegate and the wiring already
existed, and this would have been a single file of new keys. Rejected because it
inverts the dependency story ADR-0002 exists to protect:

- changing one word of a feature's copy becomes a commit against a core package;
- every feature contends for one file, so every feature branch conflicts in it;
- `core_ui`'s ARB fills with domain vocabulary, and the package's one rule is
  that it knows nothing about the domain;
- a mini-app, which by ADR-0007 may only touch `mini_app_contract`, has no way
  to add a string at all.

The saving is real and it is paid back in full the second time two features need
copy in the same sprint.

## Consequences, and the three failures this creates

Per-package localization has one sharp edge, and it is worth stating plainly
because none of it is a compile error: **`Localizations.of<T>` resolves by type
at runtime, and a type that is not in the tree throws.**

There are exactly three ways to get that wrong:

1. **A package owns an ARB but is missing from `L10N_PACKAGES`.** `make l10n`
   never generates it, and the barrel exports a file nobody produced.
2. **A package is short a locale.** Its delegate answers `isSupported: false`,
   the type is absent, and `of(context)` throws. **There is no fallback to
   English.** One missing `.arb` is a crash in that language and nothing else.
3. **A generated class's delegate is never registered by the host.** Same crash,
   in every language, the first time one of that package's screens opens.

This is the same shape as the missing DI micro-package module that once
white-screened this app while `analyze`, `test` and `check-deps` all reported
success, so it gets the same treatment rather than a paragraph of advice:

- **`make check-l10n`** (in `make ci`) reads the ARB files and the Makefile and
  fails on all three, plus any key present in the template and missing from a
  translation.
- **`app/test/localization_test.dart`** boots the real app under `vi` and
  asserts each package's copy resolves in a real tree — the half the static
  check cannot see, because it only knows what the files say, not what
  `MaterialApp` installed.
- **`AppLocalizationsSetup`** is the single place delegates are listed. Spelling
  them out inside `MaterialApp` is how one gets dropped.

Goldens cover none of this: `flutter test` ships no font, so text renders as
boxes and a Vietnamese screenshot is byte-identical to an English one. That
limitation is already written at the top of `golden_test.dart`; it is repeated
here because it is the reason the locale test is a widget test and not a golden.

`make l10n` now runs `gen-l10n` once per l10n package instead of once, which
costs a few seconds. `L10N_PACKAGES` lives in the Makefile, like every other
package list, and `check-l10n` compares it against the tree in both directions.
