# 0009 — Every screen extends one of three bases

**Status:** Accepted

## Context

Page chrome is a list of things that are individually small and collectively
easy to forget: dismissing the keyboard when the user taps outside a field,
`resizeToAvoidBottomInset` so a form is not covered by the keyboard, safe-area
handling, a bottom action bar that clears the home indicator on iOS, and the
back-button policy.

`AppScaffold` already collected all of that. What it could not do is make a
screen use it. A screen wrote `AppScaffold(...)` or it wrote `Scaffold(...)`, and
nothing failed if it wrote the second — `SplashScreen` did exactly that. The
defaults existed; using them was a convention, and a convention is a thing people
forget on the screen they write in a hurry.

There is a second, quieter problem. Pagination is subtle: load-more has to fire
from a scroll threshold rather than the last item's builder, must not fire while
a request is in flight or past the last page, and must not wipe loaded rows when
page three fails. `PagedListView` got that right. Nothing said a list screen had
to use it, so the second list screen could reimplement it slightly wrong and look
fine in review.

## Decision

Three abstract bases in `core_ui`, and every screen extends exactly one:

| Screen | Base | It implements |
|---|---|---|
| One block of data, or a form | `BaseScreen` | `buildBody` |
| A paginated list | `BaseListScreen<B, T>` | `buildItem`, `onLoadMore`, `onRefresh` |
| A paginated grid | `BaseGridScreen<B, T>` | the same, plus `maxCrossAxisExtent` |

`BaseScreen.build` assembles `AppScaffold` from hooks — `title`, `appBar`,
`actions`, `bottomBar`, `floatingActionButton`, `backgroundColor`, `onBack`,
`padded`, `showBackButton`, `dismissKeyboardOnTap`, `safeAreaBottom` — and is
`@nonVirtual`. A screen cannot override it and quietly go back to a hand-written
scaffold.

**Pagination decides the base, not the widget.** `HomeScreen` renders a
`ListView` and extends `BaseScreen`, because its data arrives complete from the
mini-app registry: there is no page to load and nothing to refresh. Choosing
`BaseListScreen` there would force an `onLoadMore` with nothing to do.

### The constraint that makes this safe

`buildBody` is called from `build` and its result is handed straight to the
scaffold. **The base wraps it in no builder and subscribes to nothing.** ADR-0008
therefore applies inside `buildBody` exactly as it did before: a tree of small
`const` widgets, one `BlocSelector` per region that changes independently.

That is not a detail, it is the whole reason this ADR does not overturn ADR-0008.
A base that wrapped the body in a `BlocBuilder` would decide rebuild scope for
every screen that ever derives from it, and a keystroke in one field would
rebuild the other field, both buttons and the scaffold — the exact cost ADR-0008
exists to avoid, reintroduced in a place no individual screen could opt out of.

`BaseListScreen` and `BaseGridScreen` *do* subscribe, via one `BlocBuilder` with
no `buildWhen`. That is ADR-0008's documented exception rather than a
contradiction: for a paginated collection the whole state is the one thing on
screen, and the paged view reads all of it.

### Paging hooks are not on `BaseScreen`

`onLoadMore`, `onRefresh`, `onRetry`, `buildItem` and `enablePullToRefresh` live
on a private `_BasePagedScreen` that only the two paged bases extend. A
`BaseScreen` subclass cannot see them — not "should not", cannot: the names do
not resolve and the code does not compile.

The `buildBody` that installs paging is `@nonVirtual` too. Overriding it would
keep the class name while silently dropping the scroll listener, the load-more
guards and the retry footer.

## Consequences

**Good**

- The chrome is decided once. A screen that forgets keyboard dismissal is no
  longer expressible.
- A list screen gets correct pagination by extending the right class, rather than
  by remembering to compose the right widget.
- The three names document the three shapes a screen can take, which is a real
  question a new contributor otherwise answers by copying whichever screen they
  opened first.

**Costs**

- **Inheritance spends the one superclass slot.** A screen that needs to extend
  something else cannot. Nothing in this codebase does, and the hooks cover the
  cases a screen would otherwise subclass for, but it is a real constraint and it
  is why `build` had to be `@nonVirtual` rather than merely documented.
- **A hybrid screen falls out of the taxonomy.** A list with an independent
  filter bar or a header that reloads on its own no longer qualifies for
  `BaseListScreen` — that screen extends `BaseScreen` and composes
  `PagedListView` inside a body whose regions each have their own selector. The
  escape hatch is deliberate; the failure mode to avoid is forcing such a screen
  into `BaseListScreen` and adding a `BlocBuilder` around a region that should
  have had a selector.
- `BaseListScreen` and `BaseGridScreen` have **no consumer in this repository**.
  They are covered by tests using fake screens, but no real screen exercises
  them, because the only paginated screen this base ever had lived in the
  reference mini-app that ADR-0007 removed. The first real list screen is the one
  that will find whatever these got wrong.

## Rejected alternatives

- **Composition only — keep `AppScaffold` and `PagedListView` as widgets, with
  no base classes.** This was the status quo and it is the better default in
  general: composition does not spend the superclass slot, does not risk a base
  owning rebuild scope, and is the idiom Flutter itself uses. It was rejected for
  one reason, and it is worth being honest that the reason is not technical
  elegance: nothing enforced it. `SplashScreen` wrote a raw `Scaffold` and no
  check objected. The base classes trade some flexibility for a guarantee, and
  the guarantee is what was wanted. Composition remains available and documented
  for the hybrid case above.

- **One base with optional paging hooks.** Simpler to name — one class, a
  `isPaginated` flag or nullable `onLoadMore`. Rejected because every plain
  screen would then carry a paging surface it must not use, and "must not" is
  the weakest form of enforcement there is. `core_arch`'s `BaseBloc` carries a
  comment about the same mistake made one layer down: the previous generation
  registered a `WidgetsBindingObserver` in the bloc base, so every bloc in the
  app received every lifecycle callback whether it cared or not. A base class
  taxes every subclass for every feature it takes on.

- **A mixin instead of a superclass.** `with ScreenChrome` leaves the superclass
  slot free, but a mixin cannot make `build` final, so the guarantee evaporates —
  a screen could mix it in and still write its own scaffold, which is the status
  quo with extra ceremony.

- **A lint rule that bans `Scaffold` outside `core_ui`.** Enforces the chrome
  without touching the type hierarchy, and was the closest competitor. Rejected
  because it enforces only the negative: it stops a raw `Scaffold`, but says
  nothing about which of the three shapes a screen is, and does nothing at all
  for the pagination half of the problem. A custom lint is also a build-time
  dependency and a plugin to maintain, for one rule.
