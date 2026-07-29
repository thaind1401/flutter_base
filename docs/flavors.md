# Platform flavors

The base ships **without** Android product flavors or iOS schemes. Environments
are `--dart-define-from-file` only — see
[ADR 0006](adr/0006-dart-define-environments.md) for why.

Add platform flavors when you need a real per-environment bundle id: all three
builds installed side by side on one device, separate Firebase projects, or
separate push certificates. Until then, do not — every added flavor is three
more build configurations to maintain on each platform.

## Android

`app/android/app/build.gradle.kts`:

```kotlin
android {
    flavorDimensions += "env"

    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "MyApp Dev")
        }
        create("stg") {
            dimension = "env"
            applicationIdSuffix = ".stg"
            resValue("string", "app_name", "MyApp Staging")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "MyApp")
        }
    }
}
```

Then point the manifest at the generated string:

```xml
android:label="@string/app_name"
```

Move `google-services.json` to
`app/android/app/src/{dev,stg,prod}/google-services.json` if you use Firebase.

**Once product flavors exist, `flutter run` requires `--flavor`.** Update the
Makefile:

```makefile
dev:
	cd app && $(FLUTTER) run --flavor dev --dart-define-from-file=env_config/dev/dart_defines.json
```

## iOS

Xcode work, roughly 15 minutes:

1. **Build configurations** — in the project settings, duplicate `Debug`,
   `Release` and `Profile` into `Debug-dev`, `Release-dev`, `Profile-dev`, and
   the same for `stg` and `prod`. Flutter expects exactly this naming.
2. **Schemes** — duplicate the `Runner` scheme into `dev`, `stg`, `prod` and
   point each at its matching configurations. Mark them **Shared**, or they stay
   in your local `xcuserdata` and CI cannot see them.
3. **Bundle identifier** — set `PRODUCT_BUNDLE_IDENTIFIER` per configuration,
   e.g. `com.acme.myapp.dev`.
4. **Display name** — set `PRODUCT_NAME` per configuration and make `Info.plist`
   read `$(PRODUCT_NAME)`.
5. **Firebase** — add a build phase script that copies the matching
   `GoogleService-Info.plist` into the bundle.

Then:

```bash
flutter run --flavor dev --dart-define-from-file=env_config/dev/dart_defines.json
```

## Verify

```bash
make dev                       # installs and runs
adb shell pm list packages | grep myapp    # three ids, side by side
```

If iOS reports `The Xcode project does not define custom schemes`, the schemes
exist but are not marked Shared.
