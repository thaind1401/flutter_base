import 'package:app/app/app.dart';
import 'package:app/app/bootstrap.dart';
import 'package:app/app/di/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/boot_harness.dart';

// Accessibility of assembled screens, which `core_ui/test/accessibility_test.dart`
// structurally cannot cover.
//
// That suite is thorough about widgets in isolation: it pumps one `AppButton`,
// one `AppTextField`, one `AppSwitchTile` through `testHost` and asserts the
// node each produces. Every guarantee it makes is real. None of them is about a
// *screen*.
//
// What only appears once widgets are assembled:
//   * a reading order that does not match the visual order, so a screen reader
//     announces the submit button before the field it submits — and nothing
//     about the screen looks wrong;
//   * chrome no component test pumps: the app bar, the navigation bar, the
//     overlay host, and a `SegmentedButton` that comes from Material rather
//     than from this design system;
//   * a control that is named in isolation and unnamed in place, because what
//     named it ended up in a sibling subtree.
//
// The four platform guidelines are re-run here rather than trusted from the
// component suite: passing them over a synthetic form proves the components,
// not the product.

/// Every node paired with where it actually sits on screen.
///
/// `SemanticsNode.transform` is relative to the parent, so the global position
/// is only available by accumulating down the walk — there is no ancestor query
/// on the node itself.
List<({SemanticsNode node, Rect rect})> _flatten(SemanticsNode root) {
  final found = <({SemanticsNode node, Rect rect})>[];

  void walk(SemanticsNode node, Matrix4 inherited) {
    final transform = node.transform == null ? inherited : (inherited.clone()..multiply(node.transform!));
    found.add((node: node, rect: MatrixUtils.transformRect(transform, node.rect)));
    node.visitChildren((child) {
      walk(child, transform);
      return true;
    });
  }

  walk(root, Matrix4.identity());
  return found;
}

/// Labels of the nodes carrying text, ordered the way the screen is drawn.
///
/// Zero-area nodes are dropped rather than filtered by the hidden flag: the
/// flag API is deprecated, and anything with no extent is not something a user
/// is being read either way.
List<String> _readingOrder(WidgetTester tester) {
  final entries =
      _flatten(tester.getSemantics(find.byType(App)))
          .where((entry) => !entry.rect.isEmpty)
          .where((entry) => entry.node.getSemanticsData().label.trim().isNotEmpty)
          .toList()
        ..sort((a, b) {
          final vertical = a.rect.top.compareTo(b.rect.top);
          return vertical != 0 ? vertical : a.rect.left.compareTo(b.rect.left);
        });

  return [for (final entry in entries) entry.node.getSemanticsData().label.trim()];
}

/// Index of the node one of whose announced lines is exactly [text], or -1.
///
/// Merged nodes join their children with newlines — a text field announces
/// `'Email\nyou@example.com'`, a tab announces `'Settings\nTab 2 of 2'` — so
/// neither whole-string equality nor `contains` works. Equality misses the
/// merged ones; `contains` matched 'Sign in' against the subtitle 'Sign in to
/// continue' and reported the submit button as being announced before the
/// fields, when the reading order was in fact correct.
int _indexOf(List<String> order, String text) =>
    order.indexWhere((label) => label.split('\n').map((line) => line.trim()).contains(text));

Future<void> _boot(WidgetTester tester, {bool signedIn = false}) async {
  if (signedIn) keychain['auth.session'] = storedSession();
  final bootstrap = await Bootstrap.run();
  await tester.pumpWidget(App(bootstrap: bootstrap));
  await tester.pumpAndSettle();
}

/// The four Flutter ships: 48x48 and 44x44 tap targets, text contrast, and
/// every tappable control having a name.
Future<void> _expectGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(installPlatformMocks);
  tearDown(getIt.reset);

  group('login', () {
    testWidgets('is read in the order it is drawn', (tester) async {
      // A screen reader walks the semantics tree; the user sees the layout. When
      // the two disagree there is nothing to notice visually — the screen looks
      // right and announces itself wrong.
      final handle = tester.ensureSemantics();
      await _boot(tester);

      final order = _readingOrder(tester);
      final title = _indexOf(order, 'Welcome back');
      final email = _indexOf(order, 'Email');
      final password = _indexOf(order, 'Password');
      final submit = _indexOf(order, 'Sign in');

      expect([title, email, password, submit], everyElement(isNonNegative), reason: 'order was $order');
      expect(title < email, isTrue, reason: 'the heading comes after a field: $order');
      expect(email < password, isTrue, reason: 'the fields are announced out of order: $order');
      expect(password < submit, isTrue, reason: 'submit is announced before the form: $order');

      handle.dispose();
    });

    testWidgets('meets the platform guidelines as an assembled screen', (tester) async {
      final handle = tester.ensureSemantics();
      await _boot(tester);
      await _expectGuidelines(tester);
      handle.dispose();
    });
  });

  group('home and its shell', () {
    testWidgets('meets the platform guidelines, navigation bar included', (tester) async {
      // The shell's chrome is covered nowhere else: no component test pumps a
      // NavigationBar, and its destinations are icons whose labels the shell
      // supplies rather than the design system.
      final handle = tester.ensureSemantics();
      await _boot(tester, signedIn: true);
      await _expectGuidelines(tester);
      handle.dispose();
    });

    testWidgets('announces the signed-in user before the tab bar', (tester) async {
      final handle = tester.ensureSemantics();
      await _boot(tester, signedIn: true);

      final order = _readingOrder(tester);
      final user = _indexOf(order, 'Signed In');
      final settingsTab = _indexOf(order, 'Settings');

      expect(user, isNonNegative, reason: 'order was $order');
      expect(settingsTab, isNonNegative, reason: 'order was $order');
      expect(user < settingsTab, isTrue, reason: 'the tab bar is announced before the content: $order');

      handle.dispose();
    });
  });

  group('settings', () {
    Future<void> open(WidgetTester tester) async {
      await _boot(tester, signedIn: true);
      await tester.tap(find.byIcon(Icons.settings_outlined).last);
      await tester.pumpAndSettle();
    }

    testWidgets('meets the platform guidelines', (tester) async {
      // The theme SegmentedButton is the interesting one here: three tap
      // targets from Material, not from this design system, so nothing in
      // core_ui's suite has ever measured them.
      final handle = tester.ensureSemantics();
      await open(tester);
      await _expectGuidelines(tester);
      handle.dispose();
    });
  });
}
