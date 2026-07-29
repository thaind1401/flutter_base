import 'package:injectable/injectable.dart';

/// Micro-package module: this feature registers its own repository, use cases,
/// bloc and session store. The host composes it and never lists them.
///
/// About the ignore list — it names *packages*, not types, and only the ones
/// whose registrations belong to the composition root by design:
///
///   * `core_kit` — `AppEnvironmentConfig`, `AppLogger`, `FailureMapper`;
///   * `core_network` / `core_storage` — `Dio`, `SecureStore`, registered by
///     their own micro-package modules, which run before this one.
///
/// The generator cannot see across package boundaries, so without this it warns
/// on every build and the warnings stop being read. What it is *not* is the
/// previous generation's 30-entry list of the app's own domain types: if a use
/// case or repository in this package is missing a registration, that is still
/// a build warning here, which is the whole point of splitting DI per package.
@InjectableInit.microPackage(
  // Package names, not import URIs — the generator compares against the first
  // path segment of the import.
  ignoreUnregisteredTypesInPackages: ['core_kit', 'core_network', 'core_storage'],
)
void initFeatureAuthPackage() {}
