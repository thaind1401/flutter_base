import 'dart:async';

import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounted once above the router, so its behaviour is the app's behaviour
/// everywhere. The rules that carry weight are all about *not* showing: hidden
/// on a cold start before the first check resolves, and no "back online"
/// confirmation for a drop the user never saw.

final class _FakeMonitor implements ConnectivityMonitor {
  _FakeMonitor([this._status = ConnectivityStatus.unknown]);

  final _controller = StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _status;
  int checks = 0;

  void send(ConnectivityStatus next) {
    _status = next;
    _controller.add(next);
  }

  Future<void> close() => _controller.close();

  @override
  ConnectivityStatus get status => _status;

  @override
  bool get isOffline => _status == ConnectivityStatus.offline;

  @override
  Stream<ConnectivityStatus> get changes => _controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<ConnectivityStatus> check() async {
    checks++;
    return _status;
  }

  /// The banner never reports transport hints — it consumes status, it does not
  /// produce it. Both stay unimplemented so a call from the widget would fail
  /// loudly rather than pass silently.
  @override
  void reportUnreachable() => throw UnimplementedError();

  @override
  void reportReachable() => throw UnimplementedError();

  @override
  Future<void> dispose() async {}
}

void main() {
  late _FakeMonitor monitor;

  setUp(() => monitor = _FakeMonitor());
  tearDown(() => monitor.close());

  Widget host(ConnectivityMonitor monitor, {Duration online = const Duration(seconds: 2)}) => MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: const [
      CoreL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: CoreL10n.supportedLocales,
    home: ConnectivityBanner(
      monitor: monitor,
      onlineDisplayDuration: online,
      child: const Scaffold(body: Text('App content')),
    ),
  );

  /// The banner is always in the tree — it slides and fades rather than being
  /// added and removed — so visibility is read from the opacity, not from
  /// whether the widget exists.
  bool visible(WidgetTester tester) => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity > 0;

  /// Null when nothing is on screen. The hidden banner still holds text — it is
  /// slid off the top at zero opacity, and `_Banner` renders the restored
  /// label for every state that is not offline, hidden included. Reading the
  /// text without checking visibility reports "restored" for a banner the user
  /// cannot see.
  String? bannerText(WidgetTester tester) {
    if (!visible(tester)) return null;
    final l10n = CoreL10n.of(tester.element(find.byType(ConnectivityBanner)));
    if (find.text(l10n.connectivityOffline).evaluate().isNotEmpty) return 'offline';
    if (find.text(l10n.connectivityRestored).evaluate().isNotEmpty) return 'restored';
    return null;
  }

  testWidgets('the child is always rendered', (tester) async {
    await tester.pumpWidget(host(monitor));

    expect(find.text('App content'), findsOneWidget);
  });

  group('cold start', () {
    testWidgets('unknown stays hidden rather than flashing offline', (tester) async {
      // Showing "no connection" before the first check resolves is worse than
      // showing nothing — the user sees an error that may not be true.
      await tester.pumpWidget(host(monitor));
      await tester.pump();

      expect(visible(tester), isFalse);
    });

    testWidgets('a monitor already offline shows the banner immediately', (tester) async {
      // No stream event is coming: the state was set before this widget existed.
      final offline = _FakeMonitor(ConnectivityStatus.offline);
      addTearDown(offline.close);

      await tester.pumpWidget(host(offline));
      await tester.pumpAndSettle();

      expect(visible(tester), isTrue);
      expect(bannerText(tester), 'offline');
    });
  });

  group('going offline and back', () {
    testWidgets('offline shows the banner with a retry', (tester) async {
      await tester.pumpWidget(host(monitor));

      monitor.send(ConnectivityStatus.offline);
      await tester.pumpAndSettle();

      expect(visible(tester), isTrue);
      expect(bannerText(tester), 'offline');
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('the retry button forces a check', (tester) async {
      // The monitor is debounced and cooled down; a user who has just fixed
      // their wifi should not have to wait for the next scheduled probe.
      await tester.pumpWidget(host(monitor));
      monitor.send(ConnectivityStatus.offline);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextButton));
      await tester.pump();

      expect(monitor.checks, 1);
    });

    testWidgets('coming back online confirms, then hides itself', (tester) async {
      await tester.pumpWidget(host(monitor, online: const Duration(seconds: 2)));

      monitor.send(ConnectivityStatus.offline);
      await tester.pumpAndSettle();

      monitor.send(ConnectivityStatus.online);
      await tester.pumpAndSettle();
      expect(bannerText(tester), 'restored', reason: 'a banner that just vanishes leaves the user unsure');

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(visible(tester), isFalse);
    });

    testWidgets('the restored banner has no retry button', (tester) async {
      await tester.pumpWidget(host(monitor));
      monitor.send(ConnectivityStatus.offline);
      await tester.pumpAndSettle();
      monitor.send(ConnectivityStatus.online);
      await tester.pumpAndSettle();

      expect(find.byType(TextButton), findsNothing);
    });
  });

  group('does not confirm a drop nobody saw', () {
    testWidgets('online without a preceding offline shows nothing', (tester) async {
      await tester.pumpWidget(host(monitor));

      monitor.send(ConnectivityStatus.online);
      await tester.pumpAndSettle();

      expect(visible(tester), isFalse);
    });

    testWidgets('unknown hides an offline banner without confirming', (tester) async {
      await tester.pumpWidget(host(monitor));
      monitor.send(ConnectivityStatus.offline);
      await tester.pumpAndSettle();

      monitor.send(ConnectivityStatus.unknown);
      await tester.pumpAndSettle();

      expect(visible(tester), isFalse);
      expect(bannerText(tester), isNot('restored'));
    });
  });

  group('lifecycle', () {
    testWidgets('a replaced monitor is the one listened to', (tester) async {
      final second = _FakeMonitor();
      addTearDown(second.close);

      await tester.pumpWidget(host(monitor));
      await tester.pumpWidget(host(second));
      await tester.pumpAndSettle();

      second.send(ConnectivityStatus.offline);
      await tester.pumpAndSettle();
      expect(visible(tester), isTrue);

      // The old monitor must no longer be able to drive the banner.
      monitor.send(ConnectivityStatus.online);
      await tester.pumpAndSettle();
      expect(bannerText(tester), 'offline');
    });

    testWidgets('disposal cancels the subscription and the pending timer', (tester) async {
      // The hide timer outliving the widget is a setState on a defunct state.
      await tester.pumpWidget(host(monitor));
      monitor.send(ConnectivityStatus.offline);
      await tester.pumpAndSettle();
      monitor.send(ConnectivityStatus.online);
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      monitor.send(ConnectivityStatus.offline);
      await tester.pump(const Duration(seconds: 5));

      expect(tester.takeException(), isNull);
    });
  });
}
