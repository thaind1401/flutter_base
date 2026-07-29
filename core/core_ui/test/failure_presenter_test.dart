import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every [Failure] the domain can produce. Listed rather than derived, so a new
/// subtype added to `core_kit` without copy to match fails here — the switch in
/// `FailurePresenter` is exhaustive and would stop compiling, but this catches
/// the softer version where someone adds a case that returns an empty string.
const List<Failure> _everyFailure = [
  NetworkFailure(),
  TimeoutFailure(),
  ServerFailure(),
  UnauthorizedFailure(),
  ForbiddenFailure(),
  NotFoundFailure(),
  ValidationFailure(),
  BusinessFailure(debugMessage: 'Leave quota exceeded'),
  PermissionFailure(permission: 'camera'),
  CacheFailure(),
  CancelledFailure(),
  UnexpectedFailure(),
];

void main() {
  /// Pumps a context with the core localizations in place and hands it to
  /// [body]. The presenter needs a real `CoreL10n`, not a stub, because the
  /// thing most likely to break is a missing ARB key.
  Future<void> withContext(
    WidgetTester tester,
    void Function(BuildContext context) body, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          CoreL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: CoreL10n.supportedLocales,
        home: Builder(
          builder: (context) {
            body(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  group('FailurePresenter', () {
    for (final failure in _everyFailure) {
      testWidgets('${failure.runtimeType} gets a non-empty title and description', (tester) async {
        await withContext(tester, (context) {
          final message = const FailurePresenter().present(context, failure);

          expect(message.title, isNotEmpty, reason: 'a missing ARB key surfaces as blank copy, not a crash');
          expect(message.description, isNotEmpty);
        });
      });
    }

    testWidgets('only failures a retry can fix offer one', (tester) async {
      await withContext(tester, (context) {
        const presenter = FailurePresenter();
        bool retryable(Failure failure) => presenter.present(context, failure).canRetry;

        // Transient — retrying is the right advice.
        expect(retryable(const NetworkFailure()), isTrue);
        expect(retryable(const TimeoutFailure()), isTrue);
        expect(retryable(const ServerFailure()), isTrue);

        // Not transient. A retry button here is a lie: the user taps it, waits,
        // and gets the same error.
        expect(retryable(const UnauthorizedFailure()), isFalse);
        expect(retryable(const ForbiddenFailure()), isFalse);
        expect(retryable(const NotFoundFailure()), isFalse);
        expect(retryable(const ValidationFailure()), isFalse);
        expect(retryable(const PermissionFailure(permission: 'camera')), isFalse);
        expect(retryable(const CacheFailure()), isFalse);
      });
    });

    testWidgets('a traceId is surfaced so a support ticket can quote it', (tester) async {
      await withContext(tester, (context) {
        final message = const FailurePresenter().present(context, const ServerFailure(traceId: 'trace-123'));
        expect(message.reference, 'trace-123');
      });
    });

    testWidgets('a blank traceId is dropped rather than shown as empty text', (tester) async {
      await withContext(tester, (context) {
        expect(const FailurePresenter().present(context, const ServerFailure(traceId: '  ')).reference, isNull);
        expect(const FailurePresenter().present(context, const ServerFailure()).reference, isNull);
      });
    });

    testWidgets('the backend message is hidden for technical failures', (tester) async {
      await withContext(tester, (context) {
        // Server copy is written for developers and sometimes leaks internals.
        // Only BusinessFailure is allowed to show it.
        final message = const FailurePresenter().present(
          context,
          const ServerFailure(debugMessage: 'NullPointerException at UserService.java:412'),
        );

        expect(message.description, isNot(contains('NullPointerException')));
        expect(message.description, isNot(contains('UserService')));
      });
    });

    testWidgets('a business rule shows the server copy, which only it knows', (tester) async {
      await withContext(tester, (context) {
        final message = const FailurePresenter().present(
          context,
          const BusinessFailure(debugMessage: 'Leave quota exceeded for this period'),
        );

        expect(message.description, 'Leave quota exceeded for this period');
      });
    });

    testWidgets('a business rule with no copy falls back to generic wording', (tester) async {
      await withContext(tester, (context) {
        final message = const FailurePresenter().present(context, const BusinessFailure());
        expect(message.description, isNotEmpty);
      });
    });

    testWidgets('copy follows the locale', (tester) async {
      late String english;
      late String vietnamese;

      await withContext(tester, (context) {
        english = const FailurePresenter().present(context, const NetworkFailure()).title;
      });
      await withContext(tester, (context) {
        vietnamese = const FailurePresenter().present(context, const NetworkFailure()).title;
      }, locale: const Locale('vi'));

      // If the vi ARB falls back to en for a key, this catches it — the two
      // strings being identical means the translation never landed.
      expect(vietnamese, isNot(english));
    });
  });

  group('context.messageFor', () {
    testWidgets('maps form input errors to localized copy', (tester) async {
      await withContext(tester, (context) {
        expect(context.messageFor(null), isNull);
        expect(context.messageFor(EmailError.invalid), isNotEmpty);
        expect(context.messageFor(PasswordError.tooShort), isNotEmpty);
        expect(context.messageFor(ConfirmPasswordError.mismatch), isNotEmpty);
        expect(context.messageFor(PhoneError.invalid), isNotEmpty);
      });
    });

    testWidgets('distinguishes the password rules from one another', (tester) async {
      await withContext(tester, (context) {
        final messages = {
          context.messageFor(PasswordError.tooShort),
          context.messageFor(PasswordError.missingUppercase),
          context.messageFor(PasswordError.missingDigit),
          context.messageFor(PasswordError.missingSymbol),
        };

        // Four rules sharing one message tells the user a password is wrong
        // without telling them which rule to fix.
        expect(messages, hasLength(4));
      });
    });

    testWidgets('an unknown error still produces something readable', (tester) async {
      await withContext(tester, (context) {
        expect(context.messageFor(Object()), isNotEmpty);
      });
    });
  });
}
