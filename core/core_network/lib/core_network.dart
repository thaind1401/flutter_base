/// HTTP transport. The only layer that knows Dio exists.
///
/// Two boundaries make this reusable across projects:
///   * [AuthSessionDelegate] — the session is injected, not imported;
///   * [DioFailureMapper] — exceptions become `Failure` here and nowhere else.
///
/// [ApiClient] is deliberately **not** self-registered. Its inputs (the session
/// delegate, the request context, the logger) are contracts implemented above
/// this layer, so wiring it belongs in the composition root — see
/// `app/lib/app/di/network_module.dart`. A package that self-registers
/// dependencies it cannot see is exactly how the previous generation ended up
/// with a 30-entry `ignoreUnregisteredTypes` list.
library core_network;

// The slice of Dio that data sources and `AuthSessionDelegate` implementers
// legitimately need. Anything beyond this — adapters, transformers, interceptor
// internals — is transport detail and stays inside this package.
export 'package:dio/dio.dart'
    show
        BaseOptions,
        CancelToken,
        Dio,
        DioException,
        DioExceptionType,
        FormData,
        Headers,
        MultipartFile,
        Options,
        RequestOptions,
        Response,
        ResponseType;

export 'di.module.dart' show CoreNetworkPackageModule;
export 'src/api_client.dart';
export 'src/api_error_envelope.dart';
export 'src/auth_session_delegate.dart';
export 'src/connectivity/connectivity_monitor_impl.dart';
export 'src/dio_failure_mapper.dart';
export 'src/interceptors/auth_interceptor.dart';
export 'src/interceptors/connectivity_interceptor.dart';
export 'src/interceptors/logging_interceptor.dart';
export 'src/interceptors/request_context_interceptor.dart';
export 'src/interceptors/retry_interceptor.dart';
