import 'package:core_arch/core_arch.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mini_app_contract/mini_app_contract.dart';

/// A mini-app reduced to what the registry can observe about it.
final class _FakeMiniApp implements MiniApp {
  _FakeMiniApp(
    this.id, {
    this.entryPointPlacements = const {MiniAppPlacement.workspace},
    this.rootRouteCount = 1,
    this.shellRouteCount = 1,
    this.localizationsDelegates = const [],
  });

  @override
  final String id;

  @override
  final List<LocalizationsDelegate<Object?>> localizationsDelegates;

  final Set<MiniAppPlacement> entryPointPlacements;
  final int rootRouteCount;
  final int shellRouteCount;

  int registerCalls = 0;
  MiniAppHost? receivedHost;
  GetIt? receivedContainer;
  GlobalKey<NavigatorState>? receivedRootKey;

  @override
  void registerDependencies(GetIt getIt, MiniAppHost host) {
    registerCalls++;
    receivedContainer = getIt;
    receivedHost = host;
  }

  @override
  List<RouteBase> rootRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) {
    receivedRootKey = rootNavigatorKey;
    return [for (var i = 0; i < rootRouteCount; i++) GoRoute(path: '/$id/root$i', builder: (_, _) => const SizedBox())];
  }

  @override
  List<RouteBase> shellRoutes({GlobalKey<NavigatorState>? rootNavigatorKey}) => [
    for (var i = 0; i < shellRouteCount; i++) GoRoute(path: '/$id/shell$i', builder: (_, _) => const SizedBox()),
  ];

  @override
  List<MiniAppEntryPoint> entryPoints(BuildContext context) => [
    MiniAppEntryPoint(
      id: '$id.entry',
      title: id,
      icon: const IconData(0),
      placements: entryPointPlacements,
      onOpen: (_) {},
    ),
  ];
}

/// Stands in for a mini-app's generated localizations delegate. Only its
/// identity matters here — the registry's job is to carry it through, not to
/// resolve anything from it.
final class _StubDelegate extends LocalizationsDelegate<Object> {
  const _StubDelegate(this.name);

  final String name;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<Object> load(Locale locale) async => Object();

  @override
  bool shouldReload(_StubDelegate old) => false;
}

final class _StubHost implements MiniAppHost {
  @override
  String? get currentUserId => 'u1';

  @override
  Locale get locale => const Locale('en');

  @override
  bool isFeatureEnabled(String key) => false;

  @override
  void openHostRoute(String routeName, {Map<String, String> pathParameters = const {}}) {}
}

void main() {
  group('MiniAppRegistry', () {
    test('is empty and harmless with no mini-apps installed', () {
      final registry = MiniAppRegistry(const []);

      expect(registry.rootRoutes(), isEmpty);
      expect(registry.shellRoutes(), isEmpty);
      expect(registry.miniApps, isEmpty);
      expect(registry.id, 'mini_apps');
    });

    test('collects routes from every mini-app, keeping root and shell apart', () {
      final registry = MiniAppRegistry([_FakeMiniApp('a', shellRouteCount: 3), _FakeMiniApp('b', rootRouteCount: 2)]);

      // The registry is what makes "add a mini-app" one line in the composition
      // root. If it dropped a package's routes the app would still boot — those
      // screens would just be unreachable, with nothing failing.
      //
      // The two counts are deliberately different: equal ones would pass even
      // if the registry read shellRoutes for both.
      expect(registry.rootRoutes(), hasLength(3));
      expect(registry.shellRoutes(), hasLength(4));
    });

    test('preserves registration order', () {
      final registry = MiniAppRegistry([_FakeMiniApp('first'), _FakeMiniApp('second')]);

      expect(registry.miniApps.map((app) => app.id), ['first', 'second']);
    });

    test('the exposed list cannot be mutated from outside', () {
      final registry = MiniAppRegistry([_FakeMiniApp('a')]);

      // Otherwise a caller could add a mini-app after startup, past the point
      // where registerDependencies has already run.
      expect(() => registry.miniApps.add(_FakeMiniApp('b')), throwsUnsupportedError);
    });

    test('registerDependencies reaches every mini-app exactly once', () {
      final first = _FakeMiniApp('first');
      final second = _FakeMiniApp('second');
      final container = GetIt.asNewInstance();
      final host = _StubHost();

      MiniAppRegistry([first, second]).registerDependencies(container, host);

      expect(first.registerCalls, 1);
      expect(second.registerCalls, 1);
      expect(first.receivedContainer, same(container));
      expect(first.receivedHost, same(host));
      expect(second.receivedHost, same(host));
    });

    test('the root navigator key is passed through to each mini-app', () {
      final miniApp = _FakeMiniApp('a');
      final key = GlobalKey<NavigatorState>();

      MiniAppRegistry([miniApp]).rootRoutes(rootNavigatorKey: key);

      // A root route that lands inside the shell navigator renders under the
      // host's bottom bar instead of over it — a layout bug that only shows up
      // when the mini-app is opened.
      expect(miniApp.receivedRootKey, same(key));
    });

    test('collects the localization delegates of every mini-app', () {
      // A mini-app ships its own ARB, and the host cannot name a class from a
      // package it does not import — so the registry is the only path from a
      // mini-app's delegate into `MaterialApp`. Drop one here and that
      // mini-app's screens throw on `of(context)` the first time they open,
      // with nothing failing at build time.
      final first = _FakeMiniApp('first', localizationsDelegates: const [_StubDelegate('first')]);
      final second = _FakeMiniApp('second', localizationsDelegates: const [_StubDelegate('second')]);

      final delegates = MiniAppRegistry([first, second]).localizationsDelegates;

      expect(delegates, hasLength(2));
      expect(delegates.whereType<_StubDelegate>().map((delegate) => delegate.name), ['first', 'second']);
    });

    test('contributes no delegates when no mini-app has copy of its own', () {
      expect(MiniAppRegistry([_FakeMiniApp('a')]).localizationsDelegates, isEmpty);
    });

    test('a duplicate id is rejected rather than silently shadowing', () {
      // Ids are used in analytics and to detect exactly this. Two packages
      // claiming one id makes the metrics for both meaningless.
      expect(() => MiniAppRegistry([_FakeMiniApp('same'), _FakeMiniApp('same')]), throwsStateError);
    });

    testWidgets('entry points are filtered by placement', (tester) async {
      final registry = MiniAppRegistry([
        _FakeMiniApp('onHome', entryPointPlacements: const {MiniAppPlacement.home}),
        _FakeMiniApp('onProfile', entryPointPlacements: const {MiniAppPlacement.profile}),
        _FakeMiniApp('onBoth', entryPointPlacements: const {MiniAppPlacement.home, MiniAppPlacement.profile}),
      ]);

      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox.shrink();
          },
        ),
      );

      expect(registry.entryPointsFor(context, MiniAppPlacement.home).map((entry) => entry.title), ['onHome', 'onBoth']);
      expect(registry.entryPointsFor(context, MiniAppPlacement.profile).map((entry) => entry.title), [
        'onProfile',
        'onBoth',
      ]);
      expect(registry.entryPointsFor(context, MiniAppPlacement.more), isEmpty);
    });
  });

  group('MiniAppEntryPoint', () {
    test('defaults to the workspace placement only', () {
      final entry = MiniAppEntryPoint(id: 'e', title: 'T', icon: const IconData(0), onOpen: (_) {});

      expect(entry.appearsIn(MiniAppPlacement.workspace), isTrue);
      expect(entry.appearsIn(MiniAppPlacement.home), isFalse);
    });
  });
}
