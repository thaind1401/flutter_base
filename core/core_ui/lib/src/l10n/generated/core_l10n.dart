import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'core_l10n_en.dart';
import 'core_l10n_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of CoreL10n
/// returned by `CoreL10n.of(context)`.
///
/// Applications need to include `CoreL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/core_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: CoreL10n.localizationsDelegates,
///   supportedLocales: CoreL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the CoreL10n.supportedLocales
/// property.
abstract class CoreL10n {
  CoreL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static CoreL10n of(BuildContext context) {
    return Localizations.of<CoreL10n>(context, CoreL10n)!;
  }

  static const LocalizationsDelegate<CoreL10n> delegate = _CoreL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('vi')];

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get commonSeeAll;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyTitle;

  /// No description provided for @emptyDescription.
  ///
  /// In en, this message translates to:
  /// **'When there is something to show, it will appear here.'**
  String get emptyDescription;

  /// No description provided for @emptySearchTitle.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get emptySearchTitle;

  /// No description provided for @emptySearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term.'**
  String get emptySearchDescription;

  /// No description provided for @errorGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGenericTitle;

  /// No description provided for @errorGenericMessage.
  ///
  /// In en, this message translates to:
  /// **'Please try again in a moment.'**
  String get errorGenericMessage;

  /// No description provided for @errorNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get errorNetworkTitle;

  /// No description provided for @errorNetworkMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get errorNetworkMessage;

  /// No description provided for @errorTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'This is taking too long'**
  String get errorTimeoutTitle;

  /// No description provided for @errorTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The server did not respond in time. Please try again.'**
  String get errorTimeoutMessage;

  /// No description provided for @errorServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server error'**
  String get errorServerTitle;

  /// No description provided for @errorServerMessage.
  ///
  /// In en, this message translates to:
  /// **'We are having trouble on our side. Please try again shortly.'**
  String get errorServerMessage;

  /// No description provided for @errorUnauthorizedTitle.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get errorUnauthorizedTitle;

  /// No description provided for @errorUnauthorizedMessage.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to continue.'**
  String get errorUnauthorizedMessage;

  /// No description provided for @errorForbiddenTitle.
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get errorForbiddenTitle;

  /// No description provided for @errorForbiddenMessage.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do this.'**
  String get errorForbiddenMessage;

  /// No description provided for @errorNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get errorNotFoundTitle;

  /// No description provided for @errorNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not find what you were looking for.'**
  String get errorNotFoundMessage;

  /// No description provided for @errorValidationTitle.
  ///
  /// In en, this message translates to:
  /// **'Please check your details'**
  String get errorValidationTitle;

  /// No description provided for @errorValidationMessage.
  ///
  /// In en, this message translates to:
  /// **'Some of the information you entered is not valid.'**
  String get errorValidationMessage;

  /// No description provided for @errorCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage problem'**
  String get errorCacheTitle;

  /// No description provided for @errorCacheMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not read saved data on this device.'**
  String get errorCacheMessage;

  /// No description provided for @errorPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission needed'**
  String get errorPermissionTitle;

  /// No description provided for @errorPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Grant the required permission to continue.'**
  String get errorPermissionMessage;

  /// No description provided for @errorPermissionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get errorPermissionOpenSettings;

  /// Shown under an error so support can correlate a bug report with a server log.
  ///
  /// In en, this message translates to:
  /// **'Reference: {traceId}'**
  String errorTraceId(String traceId);

  /// No description provided for @formFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get formFieldRequired;

  /// No description provided for @formFieldTooShort.
  ///
  /// In en, this message translates to:
  /// **'Must be at least {min} characters'**
  String formFieldTooShort(int min);

  /// No description provided for @formFieldTooLong.
  ///
  /// In en, this message translates to:
  /// **'Must be at most {max} characters'**
  String formFieldTooLong(int max);

  /// No description provided for @formEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get formEmailInvalid;

  /// No description provided for @formPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least {min} characters'**
  String formPasswordTooShort(int min);

  /// No description provided for @formPasswordMissingUppercase.
  ///
  /// In en, this message translates to:
  /// **'Add at least one uppercase letter'**
  String get formPasswordMissingUppercase;

  /// No description provided for @formPasswordMissingDigit.
  ///
  /// In en, this message translates to:
  /// **'Add at least one number'**
  String get formPasswordMissingDigit;

  /// No description provided for @formPasswordMissingSymbol.
  ///
  /// In en, this message translates to:
  /// **'Add at least one symbol'**
  String get formPasswordMissingSymbol;

  /// No description provided for @formPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get formPasswordMismatch;

  /// No description provided for @formPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get formPhoneInvalid;

  /// No description provided for @connectivityOffline.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get connectivityOffline;

  /// No description provided for @connectivityRestored.
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get connectivityRestored;

  /// No description provided for @loadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load more'**
  String get loadMoreFailed;

  /// No description provided for @pullToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh'**
  String get pullToRefresh;
}

class _CoreL10nDelegate extends LocalizationsDelegate<CoreL10n> {
  const _CoreL10nDelegate();

  @override
  Future<CoreL10n> load(Locale locale) {
    return SynchronousFuture<CoreL10n>(lookupCoreL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_CoreL10nDelegate old) => false;
}

CoreL10n lookupCoreL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return CoreL10nEn();
    case 'vi':
      return CoreL10nVi();
  }

  throw FlutterError(
    'CoreL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
