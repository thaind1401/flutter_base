import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({required bool value, ValueChanged<bool>? onChanged, String? subtitle, bool enabled = true}) =>
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppSwitchTile(
            title: 'Notifications',
            subtitle: subtitle,
            value: value,
            onChanged: onChanged,
            enabled: enabled,
          ),
        ),
      );

  testWidgets('renders the title, subtitle and current value', (tester) async {
    await tester.pumpWidget(host(value: true, subtitle: 'Email me about updates'));

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Email me about updates'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('tapping the switch toggles the value', (tester) async {
    bool? result;
    await tester.pumpWidget(host(value: false, onChanged: (v) => result = v));

    await tester.tap(find.byType(Switch));
    expect(result, isTrue);
  });

  testWidgets('tapping anywhere in the row toggles the value, not just the thumb', (tester) async {
    // The whole row is one tap target — this is the point of the widget over
    // a bare Switch, which is a target too small for the platform's own
    // accessibility guidance.
    bool? result;
    await tester.pumpWidget(host(value: false, subtitle: 'x', onChanged: (v) => result = v));

    await tester.tap(find.text('Notifications'));
    expect(result, isTrue);
  });

  testWidgets('disabled ignores taps', (tester) async {
    var called = false;
    await tester.pumpWidget(host(value: false, enabled: false, onChanged: (_) => called = true));

    await tester.tap(find.byType(Switch), warnIfMissed: false);
    await tester.tap(find.text('Notifications'), warnIfMissed: false);

    expect(called, isFalse);
  });
}
