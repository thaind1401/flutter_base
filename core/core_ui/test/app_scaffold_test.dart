import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Page chrome exists to stop every screen re-deriving the same defaults. The
/// two worth guarding are the ones a screen author forgets: tapping outside a
/// field dismisses the keyboard, and the bottom action bar clears the home
/// indicator instead of sitting under it.

void main() {
  Widget host(Widget child) => MaterialApp(theme: AppTheme.light(), home: child);

  testWidgets('renders its body', (tester) async {
    await tester.pumpWidget(host(const AppScaffold(body: Text('Body'))));

    expect(find.text('Body'), findsOneWidget);
  });

  group('app bar', () {
    testWidgets('a title builds a standard app bar', (tester) async {
      await tester.pumpWidget(host(const AppScaffold(title: 'Profile', body: SizedBox.shrink())));

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('no title and no override means no app bar', (tester) async {
      await tester.pumpWidget(host(const AppScaffold(body: SizedBox.shrink())));

      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('an explicit appBar wins over the title', (tester) async {
      await tester.pumpWidget(
        host(
          const AppScaffold(
            title: 'Ignored',
            appBar: PreferredSize(preferredSize: Size.fromHeight(40), child: Text('Custom')),
            body: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Ignored'), findsNothing);
    });

    testWidgets('actions are rendered', (tester) async {
      await tester.pumpWidget(
        host(
          const AppScaffold(
            title: 'Profile',
            actions: [Icon(Icons.more_vert, key: Key('action'))],
            body: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.byKey(const Key('action')), findsOneWidget);
    });
  });

  group('back button', () {
    testWidgets('a root page shows no back button', (tester) async {
      // Nothing to pop to. Material's automaticallyImplyLeading is switched off
      // precisely so this decision is made here rather than guessed.
      await tester.pumpWidget(host(const AppScaffold(title: 'Home', body: SizedBox.shrink())));

      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    });

    testWidgets('a pushed page shows a back button that pops', (tester) async {
      await tester.pumpWidget(
        host(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const AppScaffold(title: 'Detail', body: Text('Detail body')),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Detail body'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(find.text('Detail body'), findsNothing);
    });

    testWidgets('onBack replaces the default pop', (tester) async {
      // A form with unsaved changes needs to intercept, not pop.
      var intercepted = false;
      await tester.pumpWidget(
        host(AppScaffold(title: 'Edit', onBack: () => intercepted = true, body: const SizedBox.shrink())),
      );

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pump();

      expect(intercepted, isTrue);
    });

    testWidgets('showBackButton false hides it even with a handler', (tester) async {
      await tester.pumpWidget(
        host(AppScaffold(title: 'Edit', showBackButton: false, onBack: () {}, body: const SizedBox.shrink())),
      );

      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    });
  });

  group('keyboard dismissal', () {
    testWidgets('tapping outside a focused field unfocuses it', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        host(
          AppScaffold(
            body: Column(
              children: [
                AppTextField(focusNode: node),
                const SizedBox(height: 200, key: Key('empty space')),
              ],
            ),
          ),
        ),
      );

      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);

      await tester.tap(find.byKey(const Key('empty space')));
      await tester.pump();

      expect(node.hasFocus, isFalse);
    });

    testWidgets('dismissKeyboardOnTap false leaves focus alone', (tester) async {
      // A screen with its own gesture handling — a map, a signature pad — has
      // to be able to opt out.
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        host(
          AppScaffold(
            dismissKeyboardOnTap: false,
            body: Column(
              children: [
                AppTextField(focusNode: node),
                const SizedBox(height: 200, key: Key('empty space')),
              ],
            ),
          ),
        ),
      );

      node.requestFocus();
      await tester.pump();

      await tester.tap(find.byKey(const Key('empty space')), warnIfMissed: false);
      await tester.pump();

      expect(node.hasFocus, isTrue);
    });
  });

  group('chrome', () {
    testWidgets('a bottom bar renders inside the safe area', (tester) async {
      await tester.pumpWidget(host(const AppScaffold(body: SizedBox.shrink(), bottomBar: Text('Continue'))));

      expect(find.text('Continue'), findsOneWidget);
      expect(find.byType(SafeArea), findsAtLeast(2), reason: 'body and bottom bar each get one');
    });

    testWidgets('no bottom bar means no bottom navigation slot', (tester) async {
      await tester.pumpWidget(host(const AppScaffold(body: SizedBox.shrink())));

      expect(tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar, isNull);
    });

    testWidgets('padded insets the body', (tester) async {
      await tester.pumpWidget(host(const AppScaffold(padded: true, body: Text('Body'))));
      final paddedLeft = tester.getTopLeft(find.text('Body')).dx;

      await tester.pumpWidget(host(const AppScaffold(body: Text('Body'))));

      expect(paddedLeft, greaterThan(tester.getTopLeft(find.text('Body')).dx));
    });

    testWidgets('a floating action button is passed through', (tester) async {
      await tester.pumpWidget(
        host(
          AppScaffold(
            body: const SizedBox.shrink(),
            floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
          ),
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('backgroundColor overrides the token default', (tester) async {
      await tester.pumpWidget(host(const AppScaffold(backgroundColor: Color(0xFF00FF00), body: SizedBox.shrink())));

      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, const Color(0xFF00FF00));
    });

    testWidgets('the keyboard never covers the body', (tester) async {
      await tester.pumpWidget(host(const AppScaffold(body: SizedBox.shrink())));

      expect(tester.widget<Scaffold>(find.byType(Scaffold)).resizeToAvoidBottomInset, isTrue);
    });
  });
}
