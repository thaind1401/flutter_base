/// Authentication feature — the reference vertical slice.
///
/// Read this package first when adding a feature. It is deliberately small but
/// complete: entities, a repository interface and its implementation, use
/// cases, a Retrofit data source, a bloc, a screen, and a route module.
///
/// The public surface is narrow on purpose. Everything under `src/` that is not
/// exported here is private to the feature: other packages get the entities,
/// the session contract and the route module — never the repository
/// implementation, the DTOs or the API class.
library feature_auth;

export 'di.module.dart' show FeatureAuthPackageModule;
export 'src/domain/entities/auth_session.dart';
export 'src/domain/repositories/auth_repository.dart';
export 'src/domain/session/session_store.dart';
export 'src/domain/use_cases/auth_use_cases.dart';
// The host has to register `AuthL10n.delegate` — a generated class that is not
// exported is a delegate the host cannot name, and an unregistered delegate is a
// null crash the first time one of these screens opens. ADR-0011.
export 'src/l10n/generated/auth_l10n.dart';
export 'src/l10n/l10n_context_x.dart';
export 'src/presentation/auth_route_module.dart';
export 'src/presentation/login/login_bloc.dart' show LoginBloc;
// The effect subtypes travel with the sealed base: a caller switching over
// LoginEffect needs every branch in scope or the switch cannot be exhaustive.
export 'src/presentation/login/login_state.dart' show LoginEffect, LoginFailed, LoginState, LoginSucceeded;
