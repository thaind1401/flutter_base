import 'package:app/app/router/guards/session_guard.dart';
import 'package:app/app/session/session_cubit.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/null_session.dart';

void main() {
  const login = '/login';
  const home = '/home';
  const splash = '/';

  final guard = SessionGuard(
    SessionCubit(NullSessionStore(), nullSignOutUseCase()),
    loginLocation: login,
    homeLocation: home,
    splashLocation: splash,
    publicRoutes: const {'/legal/terms'},
  );

  group('while the session is unknown', () {
    test('nothing is redirected', () {
      // Redirecting here would race the restore and flash login at a user who
      // is in fact signed in.
      expect(guard.resolve(location: splash, status: SessionStatus.unknown), isNull);
      expect(guard.resolve(location: '/secret', status: SessionStatus.unknown), isNull);
      expect(guard.resolve(location: login, status: SessionStatus.unknown), isNull);
    });
  });

  group('signed out', () {
    test('splash goes to login', () {
      expect(guard.resolve(location: splash, status: SessionStatus.unauthenticated), login);
    });

    test('a protected route goes to login', () {
      expect(guard.resolve(location: '/secret', status: SessionStatus.unauthenticated), login);
    });

    test('login itself is left alone, or the redirect loops', () {
      expect(guard.resolve(location: login, status: SessionStatus.unauthenticated), isNull);
    });

    test('a public route is reachable', () {
      expect(guard.resolve(location: '/legal/terms', status: SessionStatus.unauthenticated), isNull);
    });
  });

  group('signed in', () {
    test('splash goes home', () {
      expect(guard.resolve(location: splash, status: SessionStatus.authenticated), home);
    });

    test('login bounces home rather than showing a form to a signed-in user', () {
      expect(guard.resolve(location: login, status: SessionStatus.authenticated), home);
    });

    test('every other route is left alone', () {
      expect(guard.resolve(location: '/secret', status: SessionStatus.authenticated), isNull);
      expect(guard.resolve(location: home, status: SessionStatus.authenticated), isNull);
    });
  });
}
