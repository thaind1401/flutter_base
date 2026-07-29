import 'dart:async';

import 'package:core_arch/core_arch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The router is assembled here and nowhere else, so a mistake in this file is
/// a mistake in every route in the app. CLAUDE.md requires a test that builds
/// for any change to wiring or routing — this is that test for the wiring
/// itself, which had none.

/// A module contributing whatever routes a test hands it.
final class _Module implements RouteModule {
  _Module(this.id, {this.root = const [], this.shell = const []});

  @override
  final String id;
  final List<RouteBase> root;
  final List<RouteBase> shell;

  @override
  List<RouteBase> rootRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) => root;

  @override
  List<RouteBase> shellRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) => shell;
}

/// Records that it ran, so guard *ordering* can be asserted and not just the
/// destination that came out. Each entry is tagged with the location being
/// evaluated, because go_router re-runs every guard against the new location
/// after a redirect and an untagged log mixes the two passes together.
///
/// [onlyAt] mirrors how real guards behave — a policy that redirects
/// unconditionally, whatever the current location, bounces the router between
/// two destinations until it gives up on the redirect limit.
final class _Guard implements RouteGuard {
  _Guard(this.name, this.destination, {required this.log, this.onlyAt});

  final String name;
  final String? destination;
  final List<String> log;
  final String? onlyAt;

  @override
  String? redirect(BuildContext context, GoRouterState state) {
    log.add('$name@${state.matchedLocation}');
    if (onlyAt != null && state.matchedLocation != onlyAt) return null;
    return destination;
  }
}

GoRoute _page(String path, String label) => GoRoute(
  path: path,
  name: label,
  builder: (context, state) => Text(label, textDirection: TextDirection.ltr),
);

void main() {
  Future<void> pump(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  group('assembly', () {
    testWidgets('routes from every module reach the router', (tester) async {
      final router = AppRouterBuilder(
        initialLocation: '/a',
        modules: [
          _Module('one', root: [_page('/a', 'A')]),
          _Module('two', root: [_page('/b', 'B')]),
        ],
      ).build();
      addTearDown(router.dispose);

      await pump(tester, router);
      expect(find.text('A'), findsOneWidget);

      router.go('/b');
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('shell routes render inside the shell chrome', (tester) async {
      final router = AppRouterBuilder(
        initialLocation: '/home',
        modules: [
          _Module('shell', shell: [_page('/home', 'Home')]),
        ],
        shellBuilder: (context, state, child) => Column(
          children: [
            const Text('CHROME'),
            Expanded(child: child),
          ],
        ),
      ).build();
      addTearDown(router.dispose);

      await pump(tester, router);

      expect(find.text('CHROME'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('without a shellBuilder the same routes render bare', (tester) async {
      // The documented meaning of a null shellBuilder: the app has no shell and
      // every route is top level. The routes must still be reachable.
      final router = AppRouterBuilder(
        initialLocation: '/home',
        modules: [
          _Module('shell', shell: [_page('/home', 'Home')]),
        ],
      ).build();
      addTearDown(router.dispose);

      await pump(tester, router);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('CHROME'), findsNothing);
    });

    testWidgets('root routes stay outside the shell', (tester) async {
      // Login and full-screen modals must not inherit the bottom bar.
      final router = AppRouterBuilder(
        initialLocation: '/login',
        modules: [
          _Module('a', shell: [_page('/home', 'Home')], root: [_page('/login', 'Login')]),
        ],
        shellBuilder: (context, state, child) => Column(
          children: [
            const Text('CHROME'),
            Expanded(child: child),
          ],
        ),
      ).build();
      addTearDown(router.dispose);

      await pump(tester, router);

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('CHROME'), findsNothing);
    });
  });

  group('guards', () {
    testWidgets('run in order and the first destination wins', (tester) async {
      final log = <String>[];
      final router = AppRouterBuilder(
        initialLocation: '/a',
        modules: [
          _Module('m', root: [_page('/a', 'A'), _page('/b', 'B'), _page('/c', 'C')]),
        ],
        guards: [
          _Guard('first', null, log: log),
          _Guard('second', '/b', log: log, onlyAt: '/a'),
          _Guard('third', '/c', log: log, onlyAt: '/a'),
        ],
      ).build();
      addTearDown(router.dispose);

      await pump(tester, router);

      expect(find.text('B'), findsOneWidget);

      // Only the pass that started at /a says anything about ordering; the
      // pass go_router runs afterwards against /b visits all three by design.
      final firstPass = log.where((entry) => entry.endsWith('@/a'));
      expect(firstPass, ['first@/a', 'second@/a']);
      expect(firstPass, isNot(contains('third@/a')), reason: 'evaluation must stop at the first destination');
    });

    testWidgets('no guard returning a destination means no redirect', (tester) async {
      final log = <String>[];
      final router = AppRouterBuilder(
        initialLocation: '/a',
        modules: [
          _Module('m', root: [_page('/a', 'A')]),
        ],
        guards: [
          _Guard('first', null, log: log),
          _Guard('second', null, log: log),
        ],
      ).build();
      addTearDown(router.dispose);

      await pump(tester, router);

      expect(find.text('A'), findsOneWidget);
      expect(log, containsAll(['first@/a', 'second@/a']), reason: 'every guard runs when none redirects');
    });

    testWidgets('a guard pointing at the current location does not loop', (tester) async {
      // The `destination != state.matchedLocation` check. Without it go_router
      // re-runs the redirect against the same answer until it throws on the
      // redirect limit — an infinite loop on startup, not a subtle bug.
      final router = AppRouterBuilder(
        initialLocation: '/a',
        modules: [
          _Module('m', root: [_page('/a', 'A')]),
        ],
        guards: [_Guard('self', '/a', log: [])],
      ).build();
      addTearDown(router.dispose);

      await pump(tester, router);

      expect(find.text('A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('guards re-run when the refreshListenable fires', (tester) async {
      // This is what makes a sign-out kick the user off a protected screen
      // instead of leaving them there until they happen to navigate.
      final notifier = ValueNotifier<bool>(true);
      addTearDown(notifier.dispose);

      final router = AppRouterBuilder(
        initialLocation: '/private',
        modules: [
          _Module('m', root: [_page('/private', 'Private'), _page('/login', 'Login')]),
        ],
        refreshListenable: notifier,
        guards: [_SessionGuard(() => notifier.value)],
      ).build();
      addTearDown(router.dispose);

      await pump(tester, router);
      expect(find.text('Private'), findsOneWidget);

      notifier.value = false;
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Private'), findsNothing);
    });
  });

  group('failure modes', () {
    testWidgets('two modules claiming one path fail loudly', (tester) async {
      // go_router itself picks the first silently, leaving the second feature's
      // screen unreachable with nothing in the logs. The assert converts that
      // into a startup crash during development.
      expect(
        () => AppRouterBuilder(
          initialLocation: '/dup',
          modules: [
            _Module('one', root: [_page('/dup', 'One')]),
            _Module('two', root: [_page('/dup', 'Two')]),
          ],
        ).build(),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('a duplicate nested under a parent is caught too', (tester) async {
      // The walk recurses; a collision one level down is just as unreachable.
      expect(
        () => AppRouterBuilder(
          initialLocation: '/parent',
          modules: [
            _Module(
              'one',
              root: [
                GoRoute(
                  path: '/parent',
                  builder: (c, s) => const SizedBox.shrink(),
                  routes: [_page('child', 'C1'), _page('child', 'C2')],
                ),
              ],
            ),
          ],
        ).build(),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('an unknown location renders the errorBuilder', (tester) async {
      final router = AppRouterBuilder(
        initialLocation: '/a',
        modules: [
          _Module('m', root: [_page('/a', 'A')]),
        ],
        errorBuilder: (context, state) => Text('missing: ${state.uri}', textDirection: TextDirection.ltr),
      ).build();
      addTearDown(router.dispose);

      await pump(tester, router);
      router.go('/nowhere');
      await tester.pumpAndSettle();

      expect(find.text('missing: /nowhere'), findsOneWidget);
    });
  });

  testWidgets('navigator observers are attached', (tester) async {
    final observer = _RecordingObserver();
    final router = AppRouterBuilder(
      initialLocation: '/a',
      modules: [
        _Module('m', root: [_page('/a', 'A'), _page('/b', 'B')]),
      ],
      observers: [observer],
    ).build();
    addTearDown(router.dispose);

    await pump(tester, router);
    // Not awaited: push completes when the route pops, which never happens here.
    unawaited(router.push<void>('/b'));
    await tester.pumpAndSettle();

    expect(observer.pushes, greaterThan(0));
  });
}

final class _SessionGuard implements RouteGuard {
  _SessionGuard(this.authenticated);

  final bool Function() authenticated;

  @override
  String? redirect(BuildContext context, GoRouterState state) => authenticated() ? null : '/login';
}

final class _RecordingObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}
