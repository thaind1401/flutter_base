import 'package:core_kit/core_kit.dart';
import 'package:core_ui/src/l10n/generated/core_l10n.dart';
import 'package:flutter/widgets.dart';

/// A [Failure] turned into words a user can read.
@immutable
final class FailureMessage {
  const FailureMessage({required this.title, required this.description, this.canRetry = false, this.reference});

  final String title;
  final String description;

  /// Whether to offer a retry button — false for failures retrying cannot fix.
  final bool canRetry;

  /// The server's traceId, shown small so a support ticket can quote it.
  final String? reference;
}

/// The only place a [Failure] becomes user-facing copy.
///
/// The domain layer must not carry localized strings — it has no locale and no
/// `BuildContext` — so it reports a *type* of failure and this maps that type
/// to the current language. A backend `message` is deliberately **not** shown
/// by default: it is written for developers, is rarely translated, and
/// sometimes leaks internal detail.
///
/// The exception is [BusinessFailure]: a rule the domain rejected usually has
/// copy that only the backend knows, so the server message is preferred there
/// and a project overrides [businessMessage] to map specific codes.
class FailurePresenter {
  const FailurePresenter();

  FailureMessage present(BuildContext context, Failure failure) {
    final l10n = CoreL10n.of(context);
    final reference = failure.traceId.isNotNullOrBlank ? failure.traceId : null;

    return switch (failure) {
      NetworkFailure() => FailureMessage(
        title: l10n.errorNetworkTitle,
        description: l10n.errorNetworkMessage,
        canRetry: true,
        reference: reference,
      ),
      TimeoutFailure() => FailureMessage(
        title: l10n.errorTimeoutTitle,
        description: l10n.errorTimeoutMessage,
        canRetry: true,
        reference: reference,
      ),
      ServerFailure() => FailureMessage(
        title: l10n.errorServerTitle,
        description: l10n.errorServerMessage,
        canRetry: true,
        reference: reference,
      ),
      UnauthorizedFailure() => FailureMessage(
        title: l10n.errorUnauthorizedTitle,
        description: l10n.errorUnauthorizedMessage,
        reference: reference,
      ),
      ForbiddenFailure() => FailureMessage(
        title: l10n.errorForbiddenTitle,
        description: l10n.errorForbiddenMessage,
        reference: reference,
      ),
      NotFoundFailure() => FailureMessage(
        title: l10n.errorNotFoundTitle,
        description: l10n.errorNotFoundMessage,
        reference: reference,
      ),
      ValidationFailure() => FailureMessage(
        title: l10n.errorValidationTitle,
        description: l10n.errorValidationMessage,
        reference: reference,
      ),
      BusinessFailure() => businessMessage(context, failure),
      PermissionFailure() => FailureMessage(title: l10n.errorPermissionTitle, description: l10n.errorPermissionMessage),
      CacheFailure() => FailureMessage(title: l10n.errorCacheTitle, description: l10n.errorCacheMessage),
      // A cancellation is the user's own doing; nothing should be shown. The
      // widget layer checks for this before calling the presenter, but a
      // sensible message is here in case something slips through.
      CancelledFailure() => FailureMessage(title: l10n.errorGenericTitle, description: l10n.errorGenericMessage),
      UnexpectedFailure() => FailureMessage(
        title: l10n.errorGenericTitle,
        description: l10n.errorGenericMessage,
        canRetry: true,
        reference: reference,
      ),
    };
  }

  /// Override per project to map known business codes to specific copy.
  ///
  /// ```dart
  /// final class MyFailurePresenter extends FailurePresenter {
  ///   @override
  ///   FailureMessage businessMessage(BuildContext context, BusinessFailure f) => switch (f.code) {
  ///     'LEAVE_QUOTA_EXCEEDED' => FailureMessage(title: ..., description: ...),
  ///     _ => super.businessMessage(context, f),
  ///   };
  /// }
  /// ```
  @protected
  FailureMessage businessMessage(BuildContext context, BusinessFailure failure) {
    final l10n = CoreL10n.of(context);
    return FailureMessage(
      title: l10n.errorGenericTitle,
      // The server's copy is the only source that knows this rule.
      description: failure.debugMessage.isNotBlank ? failure.debugMessage : l10n.errorGenericMessage,
      reference: failure.traceId.isNotNullOrBlank ? failure.traceId : null,
    );
  }
}

/// Localized copy for a form input error.
///
/// Lives here rather than on the input so `core_kit` stays Flutter-free and the
/// same validation runs in a non-UI context (a background sync, a CLI).
extension FormErrorPresenterX on BuildContext {
  String? messageFor(Object? error) {
    final l10n = CoreL10n.of(this);
    return switch (error) {
      null => null,
      RequiredTextError.empty => l10n.formFieldRequired,
      RequiredTextError.tooShort => l10n.formFieldTooShort(1),
      RequiredTextError.tooLong => l10n.formFieldTooLong(255),
      EmailError.empty => l10n.formFieldRequired,
      EmailError.invalid => l10n.formEmailInvalid,
      PasswordError.empty => l10n.formFieldRequired,
      PasswordError.tooShort => l10n.formPasswordTooShort(8),
      PasswordError.missingUppercase => l10n.formPasswordMissingUppercase,
      PasswordError.missingDigit => l10n.formPasswordMissingDigit,
      PasswordError.missingSymbol => l10n.formPasswordMissingSymbol,
      ConfirmPasswordError.empty => l10n.formFieldRequired,
      ConfirmPasswordError.mismatch => l10n.formPasswordMismatch,
      PhoneError.empty => l10n.formFieldRequired,
      PhoneError.invalid => l10n.formPhoneInvalid,
      _ => l10n.errorValidationMessage,
    };
  }
}
