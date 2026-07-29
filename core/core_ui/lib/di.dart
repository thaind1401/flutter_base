import 'package:injectable/injectable.dart';

/// See `core_storage/lib/di.dart` for why every package declares its own
/// micro-package module instead of the host app maintaining an ignore list.
///
/// This package registers exactly one thing — `LoadingOverlayController`. It is
/// a design-system primitive with no constructor dependencies, which is why
/// there is no ignore list here.
///
/// This file's absence was a real outage: `LoadingOverlayController` carried a
/// `@lazySingleton` annotation, but with no micro-package module the generator
/// never emitted a registration, `core_ui` never appeared in the composition
/// root, and `getIt<LoadingOverlayController>()` in `App.build` threw on the
/// first frame — a white screen, with `analyze`, `test` and `check-deps` all
/// green. A package that carries injectable annotations must be in
/// `CODEGEN_PACKAGES` and must declare this module; neither is optional.
@InjectableInit.microPackage()
void initCoreUiPackage() {}
