# 0010 — Accessible names and golden snapshots belong to the design system

**Status:** Accepted

## Context

`core_ui` owns every button, field and state view in the app, and it had two
gaps that shared a property: **nothing visible changes when they break.**

The first was accessibility. A grep for `Semantics`, `semanticLabel` and
`tooltip` across `core_ui/lib` returned zero hits, while `AppColors` claimed in
its own doc comment that an accessibility pass was "a change to this one file".
Colour was never the hard part. The gaps were structural, and each one produced
a control that a screen reader could not name:

- `AppButton` swaps its `Text` for a spinner while loading, so a loading button
  announced as "button, dimmed" with no name at all — at the exact moment the
  user needs to know their tap was accepted and is running. "Dimmed" reads as
  *unavailable*, which tells them to give up rather than to wait.
- `AppTextField`'s reveal toggle is an `IconButton` with no tooltip. An icon is
  its entire content, so there is nothing to infer a name from: it announced as
  "button".
- `AppSwitchTile` is an `InkWell` containing a `Switch`, which is two nodes for
  one setting: an unnamed tappable region, then a switch with no label.
- `AppLoader` is a bare `CircularProgressIndicator`, which contributes no
  semantics whatsoever. A loading screen read as an empty, silent page —
  indistinguishable from a broken one.

The second gap was visual regression. Every test in the package asserted
*behaviour*: a button disables while loading, a field shows the error it was
handed. None could fail when a spacing token moved from 12 to 16, when a dark
surface stopped lifting, or when a status colour lost contrast against it —
and `AppColors`, `AppDimens` and `AppTypography` are each one edit away from
every screen in the app.

## Decision

**Accessible names are part of a widget's contract, and are asserted.**
`core_ui/test/accessibility_test.dart` pins each name and state, and runs
Flutter's `androidTapTargetGuideline`, `iOSTapTargetGuideline`,
`textContrastGuideline` and `labeledTapTargetGuideline` over a representative
form in **both** themes. Strings go in the ARB files like any other copy.

**Golden snapshots cover the design system, always in both themes.** Each case
in `golden_test.dart` renders once light and once dark from a single
declaration, so a widget cannot be added to one set and forgotten in the other.
They are tagged `golden`, excluded from `make test`, and run as their own step
in `make ci`.

## Consequences

Writing `Semantics` in these widgets required getting the *structure* right, not
just adding labels, and two attempts were wrong in ways only the tests caught:

- Wrapping `AppButton` in `Semantics(button: true)` produced two **nested**
  button nodes with the outer one unnamed. The label has to go *inside* the
  button, because `FilledButton` already publishes the node and takes its name
  from whatever the child contributes.
- `Semantics(label: …)` around `AppSwitchTile` did not replace the inner `Text`,
  it *added* to it — the row announced "Notifications Notifications". The
  subtree has to be excluded wholesale, not merged.

Both are invisible on screen. Neither would have been found by looking.

The golden tests have a stated limit rather than an implied guarantee: `flutter
test` ships no font, so text renders as boxes. They catch layout, spacing,
alignment, colour, contrast, control heights, radii and text *metrics*; they do
not catch font family or weight. Closing that means committing a font binary and
a `FontLoader`, which is the right move once a project picks a brand font and
the wrong one for a base that ships none — a baseline baked against whatever
Roboto a runner happened to have is worse than an honest box.

`make golden-update` rewrites the baselines and prints a reminder to open the
images, because **a regenerated golden nobody looked at is worse than no
golden**: it launders the regression into the baseline, and every later diff is
measured against the broken picture.

## Rejected

**A lint or a CI script that greps for missing `Semantics`.** It can see that an
annotation exists, not that the resulting node is correct — and both real bugs
here were *present* annotations producing wrong trees.

**`golden_toolkit` or another snapshot package.** `matchesGoldenFile` plus a
tagged group is roughly twenty lines and no dependency; the package's main draw,
device-size matrices, is not what this suite is for.

**Running goldens inside `make test`.** They are the one kind of test whose
result depends on the renderer rather than on the change. A developer whose
machine disagrees with CI would be blocked by a diff they cannot act on, and the
reliable outcome of that is people learning to pass `--update-goldens` without
looking — the exact failure mode the whole approach depends on avoiding.
