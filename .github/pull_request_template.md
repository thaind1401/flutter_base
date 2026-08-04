<!--
Keep this short. Everything mechanical is already checked by `make ci`, so the
boxes below are only the things a machine cannot verify. If a box does not
apply, delete the line rather than ticking it — an unticked box people have
learned to ignore is worse than no box.
-->

## What and why

<!-- What changes, and the problem it solves. Link the issue if there is one. -->

## How it was verified

<!--
`make ci` is necessary, not sufficient — the whole gate once passed while the
app could not open (a `@lazySingleton` in `core_ui` with no micro-package
module: white screen on the first frame, everything green). So say what you
actually ran.
-->

- [ ] `make ci` is green
- [ ] I ran the app (`make dev`, or a VS Code launch config) and looked at the change
- [ ] Touched wiring, routing, theming or startup → extended `app/test/app_smoke_test.dart`
- [ ] Touched a `core_ui` widget or a token → golden tests updated and reviewed as images

## Architecture

<!-- Delete any line that does not apply. -->

- [ ] New package → has tests, is in `CODEGEN_PACKAGES`/`TEST_PACKAGES`, declares
      `@InjectableInit.microPackage()` and appears in `externalPackageModulesBefore`
- [ ] New dependency edge → `allowedDependencies` in `tools/check_dependencies.dart`
      changed **in this PR**, so the reviewer sees the architecture change and not just the import
- [ ] New pub dependency → the reason is stated below
- [ ] Changed an architectural pattern → the relevant ADR in `docs/adr/` is read and updated

<!--
Nothing in a commit message, comment or generated doc contains a credential,
token or personal data. `LogRedactor` is a safety net, not a licence.
-->
