import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    DateTime? value,
    ValueChanged<DateTime>? onChanged,
    String? label,
    String? hint,
    String? errorText,
    bool enabled = true,
  }) => MaterialApp(
    theme: AppTheme.light(),
    // Localizations are required by showDatePicker itself, not by AppDateField —
    // omitting them here would fail on the tap, not on the render, which is a
    // confusing place to discover a missing dependency.
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(
      body: AppDateField(
        value: value,
        onChanged: onChanged ?? (_) {},
        label: label,
        hint: hint,
        errorText: errorText,
        enabled: enabled,
      ),
    ),
  );

  testWidgets('renders the label and the formatted date', (tester) async {
    await tester.pumpWidget(host(value: DateTime(2026, 3, 5), label: 'Due date'));

    expect(find.text('Due date'), findsOneWidget);
    expect(find.text('05 Mar 2026'), findsOneWidget);
  });

  testWidgets('shows the hint instead of a date when value is null', (tester) async {
    await tester.pumpWidget(host(hint: 'Select a date'));

    expect(find.text('Select a date'), findsOneWidget);
  });

  testWidgets('tapping opens the date picker', (tester) async {
    await tester.pumpWidget(host(value: DateTime(2026, 3, 5)));

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('confirming the picker calls onChanged with the picked date', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(host(value: DateTime(2026, 3, 5), onChanged: (value) => picked = value));

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // The dialog's default selection is the initialDate we opened it with,
    // confirming it round-trips through onChanged unchanged.
    expect(picked, DateTime(2026, 3, 5));
  });

  testWidgets('errorText renders in the error state', (tester) async {
    await tester.pumpWidget(host(errorText: 'A date is required'));
    expect(find.text('A date is required'), findsOneWidget);
  });

  testWidgets('disabled does not open the picker', (tester) async {
    await tester.pumpWidget(host(value: DateTime(2026, 3, 5), enabled: false));

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
  });
}
