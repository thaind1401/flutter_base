import 'package:core_kit/core_kit.dart';
import 'package:core_network/core_network.dart';
import 'package:feature_auth/src/data/models/auth_dtos.dart';
import 'package:feature_auth/src/domain/entities/auth_session.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

/// The refresh call, on its own bare HTTP client.
///
/// Separate from [AuthApi] for two reasons that are easy to get wrong:
///   * it must **not** go through the authenticated client — a 401 on refresh
///     would re-enter the auth interceptor and recurse until the stack blows;
///   * it must not depend on `AuthRepository`, or the dependency graph becomes
///     a cycle: repository -> Dio -> ApiClient -> AuthSessionDelegate ->
///     SessionStore -> repository.
///
/// Building its own `Dio` from the environment config breaks both problems at
/// once, which is why this class exists rather than a method on the repository.
@lazySingleton
final class TokenRefreshApi {
  /// The only constructor injectable is allowed to see.
  ///
  /// `@factoryMethod` is not decoration here. The seam below started life as an
  /// optional `{Dio? client}` on this constructor, and injectable did the
  /// obvious thing with a named parameter it could resolve: it generated
  /// `client: gh<Dio>()` and handed this class the **authenticated** client —
  /// the one thing the whole design exists to avoid, since a 401 on refresh then
  /// re-enters the auth interceptor and recurses until the stack blows. The
  /// analyzer caught it as a `@visibleForTesting` violation in the generated
  /// module; the real defect was the injected client, not the annotation.
  @factoryMethod
  TokenRefreshApi(AppEnvironmentConfig config, this._failureMapper)
    : _dio = Dio(
        BaseOptions(
          baseUrl: config.baseUrl,
          connectTimeout: config.connectTimeout,
          receiveTimeout: config.receiveTimeout,
          headers: const {'Accept': 'application/json'},
        ),
      );

  /// The refresh path against a caller-supplied [Dio]. Tests only.
  ///
  /// Building its own client is the point of this class, and it also meant
  /// nothing depending on it could be tested without a socket:
  /// `SessionAuthDelegate` sits directly on top, which is how the public-endpoint
  /// list — the one this codebase calls the classic auth bug — ended up with no
  /// coverage at all. A separate constructor keeps the seam out of the graph
  /// injectable walks, so the production path cannot accidentally use it.
  @visibleForTesting
  TokenRefreshApi.withClient(Dio client, this._failureMapper) : _dio = client;

  final Dio _dio;
  final FailureMapper _failureMapper;

  Future<Result<AuthSession>> refresh(String refreshToken) => Result.guardAsync(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: RefreshRequestDto(refreshToken: refreshToken).toJson(),
    );
    return AuthSessionDto.fromJson(response.data!).toEntity();
  }, onError: _failureMapper.map);
}
