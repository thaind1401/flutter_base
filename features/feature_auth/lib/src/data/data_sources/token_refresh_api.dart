import 'package:core_kit/core_kit.dart';
import 'package:core_network/core_network.dart';
import 'package:feature_auth/src/data/models/auth_dtos.dart';
import 'package:feature_auth/src/domain/entities/auth_session.dart';
import 'package:injectable/injectable.dart';

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
  TokenRefreshApi(AppEnvironmentConfig config, this._failureMapper)
    : _dio = Dio(
        BaseOptions(
          baseUrl: config.baseUrl,
          connectTimeout: config.connectTimeout,
          receiveTimeout: config.receiveTimeout,
          headers: const {'Accept': 'application/json'},
        ),
      );

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
