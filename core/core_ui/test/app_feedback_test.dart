import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Toasts, confirmations and sheets as context extensions rather than a global
/// service, so the call site has to prove it is still mounted. The behaviours
/// worth pinning are the defensive ones: a dismissed confirmation is a "no", a
/// cancelled request produces no toast, and a new toast replaces the old one
/// instead of queueing behind it.

void main() {
  late BuildContext ctx;

  Future<void> pump(WidgetTester tester) async {
    final body = Builder(
      builder: (context) {
        ctx = context;
        return const Text('screen');
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          CoreL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: CoreL10n.supportedLocales,
        home: Scaffold(body: body),
      ),
    );
  }

  group('showToast', () {
    testWidgets('renders the message', (tester) async {
      await pump(tester);

      ctx.showToast('Saved');
      await tester.pump();

      expect(find.text('Saved'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('each kind picks its own colour and icon', (tester) async {
      final backgrounds = <Color>{};
      final icons = <IconData>{};

      // A fresh app per kind. Reusing one messenger leaves the previous
      // snackbar animating out while the next arrives, and the finder then
      // reads whichever of the two it reaches first.
      for (final kind in ToastKind.values) {
        await pump(tester);
        ctx.showToast(kind.name, kind: kind);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));

        backgrounds.add(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor!);
        icons.add(tester.widget<Icon>(find.descendant(of: find.byType(SnackBar), matching: find.byType(Icon))).icon!);
      }

      expect(backgrounds, hasLength(ToastKind.values.length), reason: 'kinds must be distinguishable by colour');
      expect(icons, hasLength(ToastKind.values.length), reason: 'and by icon, for anyone who cannot rely on colour');
    });

    testWidgets('a second toast replaces the first rather than queueing', (tester) async {
      // Several requests failing at once otherwise pile up snackbars and the
      // user reads a stale message for twelve seconds.
      await pump(tester);

      ctx.showToast('First');
      await tester.pump();
      ctx.showToast('Second');
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text('Second'), findsOneWidget);
      expect(find.text('First'), findsNothing);
    });

    testWidgets('an action is passed through', (tester) async {
      await pump(tester);
      var undone = false;

      ctx.showToast(
        'Deleted',
        action: SnackBarAction(label: 'Undo', onPressed: () => undone = true),
      );
      await tester.pump();
      // The snackbar has to finish sliding in before its action is hittable.
      await tester.pump(const Duration(milliseconds: 750));

      await tester.tap(find.text('Undo'));
      expect(undone, isTrue);
    });

    testWidgets('no messenger in the tree is a no-op, not a crash', (tester) async {
      // A toast fired from a screen being torn down would otherwise take the
      // app with it. This needs a tree with no MaterialApp at all: MaterialApp
      // installs a ScaffoldMessenger of its own, so `maybeOf` is never null
      // underneath one and the guard would go unexercised.
      late BuildContext bare;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              bare = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(() => bare.showToast('nowhere to go'), returnsNormally);
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('showFailureToast', () {
    testWidgets('presents a failure through the localized presenter', (tester) async {
      await pump(tester);

      ctx.showFailureToast(const NetworkFailure());
      await tester.pump();

      final expected = const FailurePresenter().present(ctx, const NetworkFailure()).description;
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('a cancelled request produces no toast at all', (tester) async {
      // The user caused it by navigating away; an error toast for their own
      // action is confusing.
      await pump(tester);

      ctx.showFailureToast(const CancelledFailure());
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('confirm', () {
    testWidgets('confirming resolves true', (tester) async {
      await pump(tester);

      final result = ctx.confirm(title: 'Delete this?');
      await tester.pumpAndSettle();
      expect(find.text('Delete this?'), findsOneWidget);

      await tester.tap(find.text(CoreL10n.of(ctx).commonConfirm));
      await tester.pumpAndSettle();

      expect(await result, isTrue);
    });

    testWidgets('cancelling resolves false', (tester) async {
      await pump(tester);

      final result = ctx.confirm(title: 'Delete this?');
      await tester.pumpAndSettle();

      await tester.tap(find.text(CoreL10n.of(ctx).commonCancel));
      await tester.pumpAndSettle();

      expect(await result, isFalse);
    });

    testWidgets('dismissing by tapping outside resolves false', (tester) async {
      // showDialog completes with null on a barrier tap. Treating null as true
      // would delete something the user never agreed to.
      await pump(tester);

      final result = ctx.confirm(title: 'Delete this?');
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(await result, isFalse);
    });

    testWidgets('custom labels and a message are rendered', (tester) async {
      await pump(tester);

      final result = ctx.confirm(
        title: 'Sign out?',
        message: 'You will need to log in again.',
        confirmLabel: 'Sign out',
        cancelLabel: 'Stay',
      );
      await tester.pumpAndSettle();

      expect(find.text('You will need to log in again.'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Stay'), findsOneWidget);

      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('destructive tints the confirm action', (tester) async {
      await pump(tester);

      Color? foregroundOfConfirm() {
        final button = tester.widget<TextButton>(
          find.ancestor(of: find.text(CoreL10n.of(ctx).commonConfirm), matching: find.byType(TextButton)),
        );
        return button.style?.foregroundColor?.resolve({});
      }

      final plain = ctx.confirm(title: 'x');
      await tester.pumpAndSettle();
      final normalColor = foregroundOfConfirm();
      await tester.tap(find.text(CoreL10n.of(ctx).commonCancel));
      await tester.pumpAndSettle();
      await plain;

      final destructive = ctx.confirm(title: 'x', isDestructive: true);
      await tester.pumpAndSettle();

      expect(foregroundOfConfirm(), isNot(normalColor));
      expect(foregroundOfConfirm(), Theme.of(ctx).extension<AppColors>()?.danger ?? ctx.colors.danger);

      await tester.tap(find.text(CoreL10n.of(ctx).commonCancel));
      await tester.pumpAndSettle();
      await destructive;
    });
  });

  group('showAppBottomSheet', () {
    testWidgets('renders the builder and an optional title', (tester) async {
      await pump(tester);

      final result = ctx.showAppBottomSheet<String>(
        title: 'Pick one',
        builder: (context) => TextButton(onPressed: () => Navigator.of(context).pop('picked'), child: const Text('A')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pick one'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);

      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();

      expect(await result, 'picked');
    });

    testWidgets('dismissing without a choice resolves null', (tester) async {
      await pump(tester);

      final result = ctx.showAppBottomSheet<String>(builder: (context) => const Text('body'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(await result, isNull);
    });

    testWidgets('a non-dismissible sheet ignores a barrier tap', (tester) async {
      await pump(tester);

      final result = ctx.showAppBottomSheet<String>(
        isDismissible: false,
        builder: (context) => TextButton(onPressed: () => Navigator.of(context).pop('done'), child: const Text('OK')),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('OK'), findsOneWidget, reason: 'the sheet must still be open');

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(await result, 'done');
    });
  });
}
