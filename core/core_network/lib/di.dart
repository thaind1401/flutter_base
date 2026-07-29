import 'package:injectable/injectable.dart';

/// See `core_storage/lib/di.dart` for why every package declares its own
/// micro-package module instead of the host app maintaining an ignore list.
///
/// This package registers exactly one thing — `DioFailureMapper`. `ApiClient`
/// and `ConnectivityMonitor` are wired by the composition root instead, because
/// their inputs are contracts implemented above this layer.
@InjectableInit.microPackage()
void initCoreNetworkPackage() {}
