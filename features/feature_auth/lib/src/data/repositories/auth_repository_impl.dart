import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:feature_auth/src/data/data_sources/auth_api.dart';
import 'package:feature_auth/src/data/models/auth_dtos.dart';
import 'package:feature_auth/src/domain/entities/auth_session.dart';
import 'package:feature_auth/src/domain/repositories/auth_repository.dart';
import 'package:injectable/injectable.dart';

/// Reference repository implementation.
///
/// Everything it does fits the same three lines: call the API inside [guard],
/// map the DTO to an entity, return. No `try/catch`, no error strings, no
/// `BuildContext`. Copy this shape for every new repository.
@LazySingleton(as: AuthRepository)
final class AuthRepositoryImpl extends BaseRepository implements AuthRepository {
  AuthRepositoryImpl(this._api, this._config, super.failureMapper);

  final AuthApi _api;
  final AppEnvironmentConfig _config;

  @override
  Future<Result<AuthSession>> signIn({required String email, required String password}) {
    // Dev-only: skips the network call entirely so the login button always
    // succeeds regardless of what was typed. Gated by `devAuthBypass`, which
    // is only ever true when `DEV_AUTH_BYPASS` is set in
    // `env_config/dev/dart_defines.json` — never in stg or prod.
    if (_config.devAuthBypass) return Future.value(Ok(AuthSession.devBypass()));
    return guard(() async => (await _api.signIn(SignInRequestDto(email: email, password: password))).toEntity());
  }

  @override
  Future<Result<Unit>> signOut() => guard(() async {
    await _api.signOut();
    return unit;
  });

  @override
  Future<Result<AuthUser>> currentUser() => guard(() async => (await _api.currentUser()).toEntity());
}
