import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// The signed-in user, as the app understands them.
///
/// A domain entity, not a DTO: no `fromJson`, no nullable soup, no field that
/// exists only because one endpoint returns it. The data layer maps its
/// response models into this, which is what lets a backend rename a field
/// without touching a single screen.
@immutable
final class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.roles = const {},
  });

  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;

  /// Role checks belong on the entity so authorisation logic cannot drift
  /// between the screens that need it.
  final Set<String> roles;

  bool hasRole(String role) => roles.contains(role);

  @override
  List<Object?> get props => [id, email, displayName, avatarUrl, roles];
}

/// Tokens plus the user they belong to.
@immutable
final class AuthSession extends Equatable {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  /// The fixed session used only when `AppEnvironmentConfig.devAuthBypass` is
  /// true — seeded at bootstrap to skip the login screen, and returned by
  /// `AuthRepositoryImpl.signIn` so the login button always succeeds. Never
  /// constructed otherwise.
  factory AuthSession.devBypass() => AuthSession(
    accessToken: 'dev-bypass-token',
    refreshToken: 'dev-bypass-refresh',
    expiresAt: DateTime.now().add(const Duration(days: 1)),
    user: const AuthUser(id: 'dev-bypass', email: 'dev@bypass.local', displayName: 'Dev Bypass'),
  );

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final AuthUser user;

  /// Refreshed slightly before the real expiry. Without the skew, a request
  /// sent at expiry-minus-one-second arrives expired and costs a round trip.
  bool isExpired({Duration skew = const Duration(seconds: 30)}) => DateTime.now().add(skew).isAfter(expiresAt);

  AuthSession copyWith({String? accessToken, String? refreshToken, DateTime? expiresAt, AuthUser? user}) => AuthSession(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    expiresAt: expiresAt ?? this.expiresAt,
    user: user ?? this.user,
  );

  Map<String, Object?> toStorageJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
    'user': {
      'id': user.id,
      'email': user.email,
      'displayName': user.displayName,
      'avatarUrl': user.avatarUrl,
      'roles': user.roles.toList(),
    },
  };

  /// Reads back a persisted session. Returns null rather than throwing when the
  /// stored shape is from an older build — a failed restore must land the user
  /// on the login screen, not crash the splash.
  static AuthSession? fromStorageJson(Map<String, Object?>? json) {
    if (json == null) return null;
    try {
      final user = json['user']! as Map<String, Object?>;
      return AuthSession(
        accessToken: json['accessToken']! as String,
        refreshToken: json['refreshToken']! as String,
        expiresAt: DateTime.parse(json['expiresAt']! as String),
        user: AuthUser(
          id: user['id']! as String,
          email: user['email']! as String,
          displayName: user['displayName']! as String,
          avatarUrl: user['avatarUrl'] as String?,
          roles: {...?(user['roles'] as List<Object?>?)?.map((Object? r) => '$r')},
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // The tokens must never reach a log, a crash report or a `print`.
  @override
  List<Object?> get props => [accessToken, refreshToken, expiresAt, user];

  @override
  String toString() => 'AuthSession(user: ${user.id}, expiresAt: $expiresAt)';
}
