# 0008 — A screen is a tree of small widgets, each selecting one slice of state

**Status:** Accepted

## Context

A bloc emits a new state object. Every widget subscribed to that bloc rebuilds.
With one `BlocBuilder` at the top of a screen, a keystroke in a text field
rebuilds the field, the other fields, the buttons, the scaffold and every
decoration in between — because they all sit inside the one builder.

That is invisible on a login form and expensive on a real screen: a list behind
a filter bar, a form with fifteen inputs, a dashboard with six cards fed by one
bloc. It is also the kind of cost that is never paid down later, because by then
it is spread across forty screens rather than concentrated in one pattern.

`bloc` already suppresses an emit of an equal state, so the question is not
"does the state change" — it is **how much of the tree a change is allowed to
touch**.

Two mechanisms exist. They are not equivalent:

```dart
// buildWhen: the rebuild condition and the data the builder reads are two
// separate expressions, and nothing keeps them in agreement.
BlocBuilder<LoginBloc, LoginState>(
  buildWhen: (p, c) => p.canSubmit != c.canSubmit,
  builder: (context, state) => AppButton(isLoading: state.isSubmitting, ...),
  //                                                      ^ not in buildWhen
)

// BlocSelector: the selector is the rebuild condition *and* the only thing the
// builder can see. They cannot drift.
BlocSelector<LoginBloc, LoginState, bool>(
  selector: (state) => state.canSubmit,
  builder: (context, canSubmit) => AppButton(...),
)
```

The `buildWhen` failure mode is the worst kind: the widget silently stops
updating. No exception, no analyzer warning, no failing test — just a button
that stays disabled, or a name that stays stale.

## Decision

**Default to `BlocSelector` over a small `const` widget.** A screen is composed
of private `StatelessWidget`s, one per region that changes independently, each
subscribing to the narrowest slice it renders.

Where a region needs more than one field, select a **record** — Dart records
have value equality, so `(canSubmit: …, isSubmitting: …)` compares correctly and
keeps the guarantee. Reaching for `BlocBuilder` because "it's two fields" throws
away the property for no gain.

`BlocBuilder` without `buildWhen` remains correct in exactly one case: **the
whole state is the one thing on screen.** `ArticleListScreen` is the example —
`PagedListView` reads items, `hasMore`, `isRefreshing` and the failure, so
selecting field by field would rebuild the same widget for the same reasons with
more code. The test is whether anything on the screen is independent of the
state; the moment a header or a filter bar appears, it is not, and the screen
splits.

`BlocBuilder` **with** `buildWhen` is a last resort, not a middle ground. If a
selector cannot express the condition, that is usually a signal the state shape
is wrong.

Two corollaries:

- **State must contain what the view renders.** A field displayed on screen but
  read from outside the state — a getter on the cubit, a service locator — is a
  stale-UI bug waiting for the right timing, because nothing makes the widget
  rebuild when it changes.
- **Every state class uses `Equatable` and lists every field in `props`.** Both
  `BlocSelector` and `buildWhen` decide by `==`. A state without value equality
  rebuilds everything on every emit; a `props` missing a field never rebuilds
  for that field. `core_arch` re-exports `Equatable` so this needs no extra
  dependency.

## Consequences

**Good**

- A keystroke rebuilds one field. This holds by construction, not by discipline.
- The slice a widget depends on is visible in its type argument, so a reviewer
  can see the blast radius without reading the builder.
- `const` constructors on the small widgets stop the parent's rebuild from
  propagating at all.

**Costs**

- More classes per screen. `login_screen.dart` is four widgets for one form.
  That is the trade: each is a few lines, named after what it shows, and the
  alternative is one build method nobody can reason about after it grows.
- Nothing enforces this mechanically. `make check-deps` cannot tell a legitimate
  whole-state `BlocBuilder` from a lazy one without parsing Dart and guessing
  intent, and a check with false positives gets switched off. This one is held
  by review and by `login_screen.dart` being the file everyone copies.

## Rejected alternatives

- **`context.select` from provider.** Equivalent granularity, but it rebuilds
  the enclosing widget rather than a subtree the type system delimits, so the
  blast radius depends on where the call sits rather than on what it selects.
- **One `BlocBuilder` per screen, optimise later.** "Later" means auditing forty
  screens for a problem that shows as jank in a profiler, not as a failing test.
- **Splitting into more blocs so each is narrow.** Solves rebuild scope by
  multiplying the thing that is expensive to wire, and it does not help a form
  whose fields genuinely share one validation state.
- **A tool check banning `BlocBuilder` outside `core_ui`.** Considered and
  rejected: it would have flagged `ArticleListScreen`, which is correct as
  written, and a rule that cries wolf is a rule that gets suppressed.

## Applying it

`docs/adding_a_feature.md` §4 has the checklist. `login_screen.dart` is the
reference: three selectors, one of them a record, over three `const` widgets.
