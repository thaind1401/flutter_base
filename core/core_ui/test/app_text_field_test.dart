import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/host.dart';

/// The field takes [AppTextField.errorText] from the bloc's FormzInput rather
/// than running its own validator, so the submit button's enabled state and the
/// field's error come from one source. The tests below pin that direction: the
/// widget displays what it is told and never decides.

void main() {
  Widget host(Widget child) => testHost(child);

  testWidgets('renders label, hint and helper', (tester) async {
    await tester.pumpWidget(
      host(const AppTextField(label: 'Email', hint: 'you@example.com', helperText: 'Work address')),
    );

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('you@example.com'), findsOneWidget);
    expect(find.text('Work address'), findsOneWidget);
  });

  testWidgets('no label omits the label row above the field', (tester) async {
    // Counted rather than asserted absent: the hint is itself a Text inside the
    // decoration, so "no Text at all" is never true for a field with a hint.
    await tester.pumpWidget(host(const AppTextField(hint: 'Search')));
    final withoutLabel = tester.widgetList<Text>(find.byType(Text)).length;

    await tester.pumpWidget(host(const AppTextField(label: 'Query', hint: 'Search')));
    final withLabel = tester.widgetList<Text>(find.byType(Text)).length;

    expect(find.text('Query'), findsOneWidget);
    expect(withLabel, withoutLabel + 1);
  });

  group('errors come from outside', () {
    testWidgets('errorText is displayed as given', (tester) async {
      await tester.pumpWidget(host(const AppTextField(label: 'Email', errorText: 'Not a valid email')));

      expect(find.text('Not a valid email'), findsOneWidget);
    });

    testWidgets('a null errorText shows nothing, however bad the input', (tester) async {
      // The widget has no validator by design. If it ever grows one, a pristine
      // field starts showing errors before the user has finished typing.
      await tester.pumpWidget(host(const AppTextField(label: 'Email')));

      await tester.enterText(find.byType(TextField), 'obviously not an email');
      await tester.pump();

      expect(find.textContaining('valid'), findsNothing);
    });
  });

  group('callbacks', () {
    testWidgets('onChanged fires per keystroke', (tester) async {
      final seen = <String>[];
      await tester.pumpWidget(host(AppTextField(onChanged: seen.add)));

      await tester.enterText(find.byType(TextField), 'abc');
      expect(seen, ['abc']);
    });

    testWidgets('onSubmitted fires on the action key', (tester) async {
      String? submitted;
      await tester.pumpWidget(host(AppTextField(onSubmitted: (value) => submitted = value)));

      await tester.enterText(find.byType(TextField), 'done');
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(submitted, 'done');
    });

    testWidgets('an external controller drives the text', (tester) async {
      final controller = TextEditingController(text: 'preset');
      addTearDown(controller.dispose);

      await tester.pumpWidget(host(AppTextField(controller: controller)));

      expect(find.text('preset'), findsOneWidget);
    });
  });

  group('obscured input', () {
    testWidgets('starts obscured and offers a reveal toggle', (tester) async {
      await tester.pumpWidget(host(const AppTextField(label: 'Password', obscureText: true)));

      expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('the toggle reveals and re-hides', (tester) async {
      // Built in rather than hand-rolled per screen, which is how one login
      // form ends up without it.
      await tester.pumpWidget(host(const AppTextField(label: 'Password', obscureText: true)));

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    });

    testWidgets('an obscured field is always single line', (tester) async {
      // maxLines is ignored when obscuring — a multi-line obscured field throws
      // in the framework rather than rendering.
      await tester.pumpWidget(host(const AppTextField(obscureText: true, maxLines: 4)));

      expect(tester.widget<TextField>(find.byType(TextField)).maxLines, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a custom suffix is dropped in favour of the reveal toggle', (tester) async {
      await tester.pumpWidget(
        host(const AppTextField(obscureText: true, suffix: Icon(Icons.star, key: Key('suffix')))),
      );

      expect(find.byKey(const Key('suffix')), findsNothing);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('a custom suffix shows on a plain field', (tester) async {
      await tester.pumpWidget(host(const AppTextField(suffix: Icon(Icons.star, key: Key('suffix')))));

      expect(find.byKey(const Key('suffix')), findsOneWidget);
    });
  });

  group('input configuration', () {
    testWidgets('disabled rejects input', (tester) async {
      var changed = false;
      await tester.pumpWidget(host(AppTextField(enabled: false, onChanged: (_) => changed = true)));

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await tester.enterText(find.byType(TextField), 'nope');
      expect(changed, isFalse);
    });

    testWidgets('formatters are applied', (tester) async {
      final seen = <String>[];
      await tester.pumpWidget(
        host(AppTextField(onChanged: seen.add, inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
      );

      await tester.enterText(find.byType(TextField), 'a1b2c3');

      expect(seen.single, '123');
    });

    testWidgets('maxLength hides the counter', (tester) async {
      // counterText is blanked deliberately; the default counter collides with
      // helperText and errorText in the same slot.
      await tester.pumpWidget(host(const AppTextField(maxLength: 10, helperText: 'Up to ten')));

      expect(find.text('0/10'), findsNothing);
      expect(find.text('Up to ten'), findsOneWidget);
    });

    testWidgets('prefix icon and keyboard type are passed through', (tester) async {
      await tester.pumpWidget(
        host(const AppTextField(prefixIcon: Icons.mail_outline, keyboardType: TextInputType.emailAddress)),
      );

      expect(find.byIcon(Icons.mail_outline), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).keyboardType, TextInputType.emailAddress);
    });

    testWidgets('an external focus node can focus the field', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(host(AppTextField(focusNode: node)));
      node.requestFocus();
      await tester.pump();

      expect(node.hasFocus, isTrue);
    });
  });
}
