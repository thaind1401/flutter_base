import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/src/data/models/auth_dtos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final expiry = DateTime(2026, 6, 1, 12);

  AuthSession session({DateTime? expiresAt}) => AuthSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresAt: expiresAt ?? expiry,
    user: const AuthUser(id: 'u1', email: 'a@b.com', displayName: 'Tester', roles: {'admin'}),
  );

  group('AuthSession', () {
    test('round-trips through storage json', () {
      final restored = AuthSession.fromStorageJson(session().toStorageJson());
      expect(restored, session());
      expect(restored!.user.roles, {'admin'});
    });

    test('returns null for a payload written by an older schema', () {
      // A restore failure must land the user on login, not crash the splash.
      expect(AuthSession.fromStorageJson({'accessToken': 'only-this'}), isNull);
      expect(AuthSession.fromStorageJson({'accessToken': 1, 'refreshToken': 2}), isNull);
      expect(AuthSession.fromStorageJson(null), isNull);
    });

    test('expiry uses a skew so a request is not sent with a just-dead token', () {
      final almost = DateTime.now().add(const Duration(seconds: 10));
      expect(session(expiresAt: almost).isExpired(), isTrue);
      expect(session(expiresAt: almost).isExpired(skew: Duration.zero), isFalse);
      expect(session(expiresAt: DateTime.now().add(const Duration(hours: 1))).isExpired(), isFalse);
    });

    test('toString does not leak the tokens', () {
      // This string reaches logs and crash reports.
      final text = session().toString();
      expect(text, isNot(contains('access')));
      expect(text, isNot(contains('refresh')));
      expect(text, contains('u1'));
    });

    test('hasRole reads the entity rather than each screen re-deriving it', () {
      expect(session().user.hasRole('admin'), isTrue);
      expect(session().user.hasRole('owner'), isFalse);
    });
  });

  group('AuthUserDto', () {
    test('falls back to the email local part when the name is missing', () {
      // The entity's displayName is non-null; rendering "null" on a profile
      // screen is the failure this prevents.
      final entity = AuthUserDto.fromJson(const {'id': 'u1', 'email': 'thai.nguyen@corp.com'}).toEntity();
      expect(entity.displayName, 'thai.nguyen');
    });

    test('falls back when the name is present but blank', () {
      final entity = AuthUserDto.fromJson(const {'id': 'u1', 'email': 'a@b.com', 'display_name': '   '}).toEntity();
      expect(entity.displayName, 'a');
    });

    test('maps the snake_case wire fields', () {
      final entity = AuthUserDto.fromJson(const {
        'id': 'u1',
        'email': 'a@b.com',
        'display_name': 'Real Name',
        'avatar_url': 'https://cdn/x.png',
        'roles': ['admin', 'staff'],
      }).toEntity();
      expect(entity.displayName, 'Real Name');
      expect(entity.avatarUrl, 'https://cdn/x.png');
      expect(entity.roles, {'admin', 'staff'});
    });

    test('a missing roles array is an empty set, not null', () {
      expect(AuthUserDto.fromJson(const {'id': 'u1', 'email': 'a@b.com'}).toEntity().roles, isEmpty);
    });
  });

  group('AuthSessionDto', () {
    Map<String, dynamic> base() => {'access_token': 'a', 'refresh_token': 'r'};

    test('accepts the absolute-expiry convention', () {
      final entity = AuthSessionDto.fromJson({...base(), 'expires_at': '2026-06-01T12:00:00.000'}).toEntity();
      expect(entity.expiresAt, expiry);
    });

    test('accepts the OAuth expires_in convention', () {
      final entity = AuthSessionDto.fromJson({...base(), 'expires_in': 60}).toEntity();
      expect(entity.expiresAt.difference(DateTime.now()).inSeconds, closeTo(60, 2));
    });

    test('treats a missing expiry as short-lived, never as never-expiring', () {
      // "Never expires" means the app never refreshes and every request 401s
      // once the token really does lapse.
      final entity = AuthSessionDto.fromJson(base()).toEntity();
      expect(entity.expiresAt.isAfter(DateTime.now()), isTrue);
      expect(entity.expiresAt.difference(DateTime.now()).inHours, lessThanOrEqualTo(1));
    });

    test('survives a response with no user object', () {
      final entity = AuthSessionDto.fromJson(base()).toEntity();
      expect(entity.user.id, isEmpty);
      expect(entity.accessToken, 'a');
    });
  });
}
