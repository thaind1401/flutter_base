/// The host <-> mini-app boundary, and nothing else.
///
/// Both sides depend on this package; neither depends on the other. That is the
/// whole design. In the previous generation the mini-app package depended on
/// the host's domain package and the host imported the mini-app's widgets
/// directly, which meant a "self-contained" mini-app could not be built,
/// tested, or shipped to another app without dragging the entire HR domain
/// along with it.
library mini_app_contract;

export 'src/mini_app.dart';
export 'src/mini_app_registry.dart';
