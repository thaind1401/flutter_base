import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Category { news, tutorial }

void main() {
  const items = [
    AppDropdownItem(value: _Category.news, label: 'News'),
    AppDropdownItem(value: _Category.tutorial, label: 'Tutorial'),
  ];

  Widget host({
    _Category? value,
    ValueChanged<_Category?>? onChanged,
    String? label,
    String? errorText,
    bool enabled = true,
  }) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: AppDropdownField<_Category>(
        items: items,
        value: value,
        onChanged: onChanged,
        label: label,
        errorText: errorText,
        enabled: enabled,
      ),
    ),
  );

  testWidgets('renders the label and the selected item', (tester) async {
    await tester.pumpWidget(host(value: _Category.news, label: 'Category'));

    expect(find.text('Category'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);
  });

  testWidgets('shows nothing selected when value is null', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('News'), findsNothing);
    expect(find.text('Tutorial'), findsNothing);
  });

  testWidgets('opening the menu and picking an item calls onChanged with its value', (tester) async {
    _Category? picked;
    await tester.pumpWidget(host(value: _Category.news, onChanged: (value) => picked = value));

    await tester.tap(find.text('News'));
    await tester.pumpAndSettle();
    // The menu now shows both items; tap the one not currently selected.
    await tester.tap(find.text('Tutorial').last);
    await tester.pumpAndSettle();

    expect(picked, _Category.tutorial);
  });

  testWidgets('errorText renders in the error state', (tester) async {
    await tester.pumpWidget(host(errorText: 'Pick a category'));
    expect(find.text('Pick a category'), findsOneWidget);
  });

  testWidgets('disabled ignores taps', (tester) async {
    var called = false;
    await tester.pumpWidget(host(value: _Category.news, enabled: false, onChanged: (_) => called = true));

    await tester.tap(find.text('News'));
    await tester.pumpAndSettle();

    // A disabled dropdown does not even open, so there is no second item to
    // tap — the absence of a menu is the assertion.
    expect(find.text('Tutorial'), findsNothing);
    expect(called, isFalse);
  });
}
