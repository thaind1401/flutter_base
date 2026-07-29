import 'package:feature_auth/src/domain/entities/auth_session.dart';
import 'package:json_annotation/json_annotation.dart';

part 'auth_dtos.g.dart';

/// Wire format. DTOs stay in `data/` and never leave it — the repository maps
/// them to entities.
///
/// Why the split is worth the extra class: a backend that renames `full_name`
/// to `display_name`, or starts sending `expires_in` instead of `expires_at`,
/// changes this file only. Using the DTO as the entity means that rename
/// reaches every widget that reads the field.
@JsonSerializable(createToJson: false)
final class AuthUserDto {
  const AuthUserDto({required this.id, required this.email, this.displayName, this.avatarUrl, this.roles});

  factory AuthUserDto.fromJson(Map<String, dynamic> json) => _$AuthUserDtoFromJson(json);

  final String id;
  final String email;

  @JsonKey(name: 'display_name')
  final String? displayName;

  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  final List<String>? roles;

  /// Fills the gaps the domain does not tolerate: an entity has a non-null
  /// display name, so a user without one falls back to the local part of their
  /// email rather than rendering "null" on the profile screen.
  AuthUser toEntity() => AuthUser(
    id: id,
    email: email,
    displayName: (displayName == null || displayName!.trim().isEmpty) ? email.split('@').first : displayName!,
    avatarUrl: avatarUrl,
    roles: {...?roles},
  );
}

@JsonSerializable(createToJson: false)
final class AuthSessionDto {
  const AuthSessionDto({
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn,
    this.expiresAt,
    this.user,
  });

  factory AuthSessionDto.fromJson(Map<String, dynamic> json) => _$AuthSessionDtoFromJson(json);

  @JsonKey(name: 'access_token')
  final String accessToken;

  @JsonKey(name: 'refresh_token')
  final String refreshToken;

  /// Seconds until expiry — the OAuth-style field.
  @JsonKey(name: 'expires_in')
  final int? expiresIn;

  /// Absolute expiry — the other common convention.
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;

  final AuthUserDto? user;

  /// Accepts either expiry convention, and neither. A missing expiry becomes a
  /// short window rather than "never expires": treating an unknown expiry as
  /// infinite means the app never refreshes and every request 401s once the
  /// token really does lapse.
  AuthSession toEntity() => AuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: expiresAt ?? DateTime.now().add(Duration(seconds: expiresIn ?? 3600)),
    user: user?.toEntity() ?? const AuthUser(id: '', email: '', displayName: ''),
  );
}

@JsonSerializable(createFactory: false)
final class SignInRequestDto {
  const SignInRequestDto({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => _$SignInRequestDtoToJson(this);
}

@JsonSerializable(createFactory: false)
final class RefreshRequestDto {
  const RefreshRequestDto({required this.refreshToken});

  @JsonKey(name: 'refresh_token')
  final String refreshToken;

  Map<String, dynamic> toJson() => _$RefreshRequestDtoToJson(this);
}
