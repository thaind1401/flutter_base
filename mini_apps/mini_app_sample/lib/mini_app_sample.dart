/// Reference mini-app.
///
/// Copy this package to start a new one. The rules it demonstrates:
///   * `mini_app_contract` is the only dependency that touches the host;
///   * everything else — entity, repository, bloc, screen — is private to the
///     package and reachable only through [SampleMiniApp];
///   * it registers its own dependencies into the container it is handed, so
///     the host's DI file does not grow when a mini-app is added.
library mini_app_sample;

export 'src/sample_mini_app.dart' show SampleMiniApp;
