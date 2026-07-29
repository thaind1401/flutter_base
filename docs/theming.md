# Theming

## The rule

Widgets ask for **meaning**, never for a value.

```dart
// yes
color: context.colors.danger,
padding: EdgeInsets.all(context.dimens.space16),
style: context.textStyles.titleMd,

// no
color: const Color(0xFFDC2626),
padding: const EdgeInsets.all(16),
style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
```

A literal in a widget is invisible to a rebrand, breaks in dark mode, and cannot
be adjusted for an accessibility pass. If a token you need is missing, add it to
the token class — that is the intended response, not a one-off literal.

## Rebranding a new project

1. **Colours** — `core/core_ui/lib/src/theme/app_colors.dart`. Edit the two
   factories, `AppColors.light()` and `AppColors.dark()`. Nothing else changes.

   The dark palette is not a mechanical inversion of the light one: surfaces
   lift as they get closer to the user, and status colours are lightened to hold
   contrast against a dark background. Check both.

2. **Typography** — `app_typography.dart`. Add the font to `app/pubspec.yaml`
   and pass its family to `AppTheme.light(fontFamily: 'Inter')`.

   Line heights are unitless multiples on purpose: a fixed pixel height clips
   when the user raises the system font size to 200%.

3. **Spacing and radius** — `app_dimens.dart`. The scale exists so screens line
   up without anyone measuring; prefer adjusting the scale to introducing a new
   value.

4. **Component defaults** — `app_theme.dart` maps the tokens onto Material's own
   themes (`inputDecorationTheme`, `filledButtonTheme`, …), so stock widgets
   match without being restyled one at a time.

## Adding a token

```dart
// 1. field + constructor parameter
final Color chartPositive;

// 2. a value in both factories
chartPositive: const Color(0xFF16A34A),   // light
chartPositive: const Color(0xFF4ADE80),   // dark

// 3. copyWith and lerp
```

`lerp` matters: without it the colour snaps instead of animating during a theme
change, which looks like a bug.

## Dark mode

`AppTheme.dark()` is a first-class theme, not an afterthought. `ThemeMode` is
owned by the root widget and surfaced in Settings.

Two things worth checking when you add a screen:

- **Contrast on status colours.** `onStatus` is the foreground for text sitting
  on `success` / `warning` / `danger`; it is near-white in light mode and
  near-black in dark, because a light red needs dark text.
- **Elevation.** In dark mode, lift is expressed with `surface` vs
  `surfaceVariant` rather than with shadows, which are invisible on a dark
  background.

## Localization

Copy lives in `core/core_ui/lib/src/l10n/arb/`. After editing an ARB file:

```bash
make l10n
```

Generated output is gitignored, so a fresh clone regenerates it via `make setup`.

Feature-specific copy belongs in that feature's own ARB, not in `core_ui` —
`core_ui` holds only what every app needs (errors, empty states, common actions,
form validation).

`FailurePresenter` maps a `Failure` *type* to localized copy. To give a business
error code its own message:

```dart
final class MyFailurePresenter extends FailurePresenter {
  @override
  FailureMessage businessMessage(BuildContext context, BusinessFailure failure) => switch (failure.code) {
    'ORDER_ALREADY_SHIPPED' => FailureMessage(
      title: context.l10n.orderShippedTitle,
      description: context.l10n.orderShippedBody,
    ),
    _ => super.businessMessage(context, failure),
  };
}
```
