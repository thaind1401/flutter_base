import 'package:injectable/injectable.dart';

/// Declares this package as an injectable *micro package*.
///
/// This is what replaces the host app's old `ignoreUnregisteredTypes` list.
/// Each package generates its own module describing what it registers, and the
/// composition root composes them with `externalPackageModulesBefore`. The
/// generator then knows every type, so a genuinely missing registration is a
/// build error again instead of being suppressed by a hand-maintained
/// allowlist that nobody dares to delete from.
@InjectableInit.microPackage()
void initCoreStoragePackage() {}
