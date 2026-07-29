// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'core_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class CoreL10nEn extends CoreL10n {
  CoreL10nEn([String locale = 'en']) : super(locale);

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonSeeAll => 'See all';

  @override
  String get commonSettings => 'Settings';

  @override
  String get emptyTitle => 'Nothing here yet';

  @override
  String get emptyDescription => 'When there is something to show, it will appear here.';

  @override
  String get emptySearchTitle => 'No results';

  @override
  String get emptySearchDescription => 'Try a different search term.';

  @override
  String get errorGenericTitle => 'Something went wrong';

  @override
  String get errorGenericMessage => 'Please try again in a moment.';

  @override
  String get errorNetworkTitle => 'No connection';

  @override
  String get errorNetworkMessage => 'Check your internet connection and try again.';

  @override
  String get errorTimeoutTitle => 'This is taking too long';

  @override
  String get errorTimeoutMessage => 'The server did not respond in time. Please try again.';

  @override
  String get errorServerTitle => 'Server error';

  @override
  String get errorServerMessage => 'We are having trouble on our side. Please try again shortly.';

  @override
  String get errorUnauthorizedTitle => 'Session expired';

  @override
  String get errorUnauthorizedMessage => 'Please sign in again to continue.';

  @override
  String get errorForbiddenTitle => 'Access denied';

  @override
  String get errorForbiddenMessage => 'You do not have permission to do this.';

  @override
  String get errorNotFoundTitle => 'Not found';

  @override
  String get errorNotFoundMessage => 'We could not find what you were looking for.';

  @override
  String get errorValidationTitle => 'Please check your details';

  @override
  String get errorValidationMessage => 'Some of the information you entered is not valid.';

  @override
  String get errorCacheTitle => 'Storage problem';

  @override
  String get errorCacheMessage => 'We could not read saved data on this device.';

  @override
  String get errorPermissionTitle => 'Permission needed';

  @override
  String get errorPermissionMessage => 'Grant the required permission to continue.';

  @override
  String get errorPermissionOpenSettings => 'Open settings';

  @override
  String errorTraceId(String traceId) {
    return 'Reference: $traceId';
  }

  @override
  String get formFieldRequired => 'This field is required';

  @override
  String formFieldTooShort(int min) {
    return 'Must be at least $min characters';
  }

  @override
  String formFieldTooLong(int max) {
    return 'Must be at most $max characters';
  }

  @override
  String get formEmailInvalid => 'Enter a valid email address';

  @override
  String formPasswordTooShort(int min) {
    return 'Password must be at least $min characters';
  }

  @override
  String get formPasswordMissingUppercase => 'Add at least one uppercase letter';

  @override
  String get formPasswordMissingDigit => 'Add at least one number';

  @override
  String get formPasswordMissingSymbol => 'Add at least one symbol';

  @override
  String get formPasswordMismatch => 'Passwords do not match';

  @override
  String get formPhoneInvalid => 'Enter a valid phone number';

  @override
  String get connectivityOffline => 'No internet connection';

  @override
  String get connectivityRestored => 'Back online';

  @override
  String get loadMoreFailed => 'Could not load more';

  @override
  String get pullToRefresh => 'Pull to refresh';
}
