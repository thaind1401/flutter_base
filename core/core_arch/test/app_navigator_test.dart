import 'dart:async';

import 'package:core_arch/core_arch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Navigation for code with no BuildContext — a push handler, a session expiry,
/// a deep link. The alternative it replaces is a global navigator key, so the
/// value here is that it can be driven and asserted from a test at all.

const _home = RouteSpec(name: 'home', path: '/');
const _details = RouteSpec(name: 'details', path: '/details/:id');

GoRouter _buildRouter() => GoRouter(
  initialLocation: _home.path,
  routes: [
    GoRoute(
      name: _home.name,
      path: _home.path,
      builder: (context, state) => Scaffold(
        body: Column(
          children: [
            const Text('Home'),
            // The extensions are what widgets use; the interface above is for
            // everything else. Both are exercised.
            TextButton(
              onPressed: () => _details.go(context, pathParameters: {'id': '7'}),
              child: const Text('go'),
            ),
            TextButton(
              onPressed: () => unawaited(_details.push<void>(context, pathParameters: {'id': '9'})),
              child: const Text('push'),
            ),
          ],
        ),
      ),
    ),
    GoRoute(
      name: _details.name,
      path: _details.path,
      builder: (context, state) => Scaffold(body: Text('Details ${state.pathParameters['id']}')),
    ),
  ],
);

void main() {
  Future<(GoRouter, AppNavigator)> pump(WidgetTester tester) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return (router, GoRouterNavigator(router));
  }

  group('GoRouterNavigator', () {
    testWidgets('goNamed resolves path parameters', (tester) async {
      final (_, navigator) = await pump(tester);

      navigator.goNamed(_details.name, pathParameters: {'id': '42'});
      await tester.pumpAndSettle();

      expect(find.text('Details 42'), findsOneWidget);
    });

    testWidgets('go navigates by raw location', (tester) async {
      final (_, navigator) = await pump(tester);

      navigator.go('/details/3');
      await tester.pumpAndSettle();

      expect(find.text('Details 3'), findsOneWidget);
    });

    testWidgets('pushNamed stacks a route that pop returns from', (tester) async {
      final (_, navigator) = await pump(tester);

      unawaited(navigator.pushNamed<void>(_details.name, pathParameters: {'id': '5'}));
      await tester.pumpAndSettle();
      expect(find.text('Details 5'), findsOneWidget);
      expect(navigator.canPop(), isTrue);

      navigator.pop<void>();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('pushNamed completes with the value passed to pop', (tester) async {
      final (_, navigator) = await pump(tester);

      final result = navigator.pushNamed<String>(_details.name, pathParameters: {'id': '1'});
      await tester.pumpAndSettle();

      navigator.pop<String>('picked');
      await tester.pumpAndSettle();

      expect(await result, 'picked');
    });

    testWidgets('pop on an empty stack is a no-op rather than a crash', (tester) async {
      // The documented reason this override exists: a dialog dismissed while a
      // request was still in flight pops twice, and go_router throws on the
      // second. Callers fire this from async callbacks that cannot know.
      final (_, navigator) = await pump(tester);

      expect(navigator.canPop(), isFalse);
      expect(navigator.pop, returnsNormally);
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('currentLocation tracks navigation', (tester) async {
      final (_, navigator) = await pump(tester);
      expect(navigator.currentLocation, '/');

      navigator.go('/details/8');
      await tester.pumpAndSettle();

      expect(navigator.currentLocation, '/details/8');
    });
  });

  group('RouteSpec extensions', () {
    testWidgets('go navigates from a widget context', (tester) async {
      await pump(tester);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Details 7'), findsOneWidget);
    });

    testWidgets('push stacks from a widget context', (tester) async {
      final (_, navigator) = await pump(tester);

      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      expect(find.text('Details 9'), findsOneWidget);
      expect(navigator.canPop(), isTrue, reason: 'push must stack, unlike go');
    });
  });

  test('RouteSpec prints its name and path', () {
    // Used in router logs; a spec that stringifies to Instance of 'RouteSpec'
    // makes every one of those lines useless.
    expect(_details.toString(), 'RouteSpec(details -> /details/:id)');
  });
}
