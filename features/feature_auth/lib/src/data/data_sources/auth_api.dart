import 'package:core_network/core_network.dart';
import 'package:feature_auth/src/data/models/auth_dtos.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

part 'auth_api.g.dart';

/// The HTTP surface of this feature.
///
/// One `@RestApi` per feature keeps endpoint definitions next to the code that
/// uses them instead of in a shared file every team edits. It takes a [Dio] —
/// not an `ApiClient` — so a test can construct it against a stub adapter.
@RestApi()
@injectable
abstract class AuthApi {
  @factoryMethod
  factory AuthApi(Dio dio) = _AuthApi;

  @POST('/auth/login')
  Future<AuthSessionDto> signIn(@Body() SignInRequestDto body);

  @POST('/auth/logout')
  Future<void> signOut();

  @GET('/auth/me')
  Future<AuthUserDto> currentUser();
}
