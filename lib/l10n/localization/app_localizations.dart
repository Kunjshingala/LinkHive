import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'localization/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('gu'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'LinkHive'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get homeTitle;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @addLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Link'**
  String get addLinkTitle;

  /// No description provided for @homeEmptyStateTitle.
  ///
  /// In en, this message translates to:
  /// **'No Links yet!'**
  String get homeEmptyStateTitle;

  /// No description provided for @homeEmptyStateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get started by saving your first Web Link.'**
  String get homeEmptyStateSubtitle;

  /// No description provided for @addLinkButton.
  ///
  /// In en, this message translates to:
  /// **'Add Link'**
  String get addLinkButton;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search links...'**
  String get searchHint;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// No description provided for @homeCategoriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get homeCategoriesLabel;

  /// No description provided for @homePrioritiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Priorities'**
  String get homePrioritiesLabel;

  /// No description provided for @catDev.
  ///
  /// In en, this message translates to:
  /// **'Dev'**
  String get catDev;

  /// No description provided for @catDesign.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get catDesign;

  /// No description provided for @catRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get catRead;

  /// No description provided for @catTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get catTools;

  /// No description provided for @catDocs.
  ///
  /// In en, this message translates to:
  /// **'Docs'**
  String get catDocs;

  /// No description provided for @catAI.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get catAI;

  /// No description provided for @catFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get catFinance;

  /// No description provided for @catNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get catNews;

  /// No description provided for @addLinkUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get addLinkUrlLabel;

  /// No description provided for @addLinkUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com'**
  String get addLinkUrlHint;

  /// No description provided for @addLinkPageTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get addLinkPageTitleLabel;

  /// No description provided for @addLinkPageTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Page title'**
  String get addLinkPageTitleHint;

  /// No description provided for @addLinkDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get addLinkDescLabel;

  /// No description provided for @addLinkDescHint.
  ///
  /// In en, this message translates to:
  /// **'Optional description'**
  String get addLinkDescHint;

  /// No description provided for @addLinkPriorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get addLinkPriorityLabel;

  /// No description provided for @addLinkCategoriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get addLinkCategoriesLabel;

  /// No description provided for @saveLinkButton.
  ///
  /// In en, this message translates to:
  /// **'Save Link'**
  String get saveLinkButton;

  /// No description provided for @linkSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Link saved!'**
  String get linkSavedSuccess;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @priorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get priorityNormal;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @navLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get navLinks;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get accountTitle;

  /// No description provided for @accountSignInPromo.
  ///
  /// In en, this message translates to:
  /// **'Sign in to backup your links'**
  String get accountSignInPromo;

  /// No description provided for @accountSignInDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep your collection safe and synced across devices.'**
  String get accountSignInDesc;

  /// No description provided for @accountStatSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced to Cloud'**
  String get accountStatSynced;

  /// No description provided for @accountStatLocal.
  ///
  /// In en, this message translates to:
  /// **'Local Only'**
  String get accountStatLocal;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get accountSettings;

  /// No description provided for @accountTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get accountTheme;

  /// No description provided for @accountThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get accountThemeDark;

  /// No description provided for @accountThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get accountThemeLight;

  /// No description provided for @accountThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get accountThemeSystem;

  /// No description provided for @accountExport.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get accountExport;

  /// No description provided for @accountExportDesc.
  ///
  /// In en, this message translates to:
  /// **'Download a backup'**
  String get accountExportDesc;

  /// No description provided for @accountAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get accountAbout;

  /// No description provided for @accountVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0'**
  String get accountVersion;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get accountSignOut;

  /// No description provided for @accountSignOutDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose what to clear after signing out.'**
  String get accountSignOutDesc;

  /// No description provided for @accountDeleteRemoteData.
  ///
  /// In en, this message translates to:
  /// **'Clear cloud data (delete synced links)'**
  String get accountDeleteRemoteData;

  /// No description provided for @accountSignedOutSuccess.
  ///
  /// In en, this message translates to:
  /// **'Signed out successfully'**
  String get accountSignedOutSuccess;

  /// No description provided for @authWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back!'**
  String get authWelcome;

  /// No description provided for @authSignInDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get authSignInDesc;

  /// No description provided for @authEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailHint;

  /// No description provided for @authEmailError.
  ///
  /// In en, this message translates to:
  /// **'Please enter email'**
  String get authEmailError;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordHint;

  /// No description provided for @authPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authPasswordError;

  /// No description provided for @authSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignInButton;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get authOr;

  /// No description provided for @authGoogleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get authGoogleSignIn;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get authNoAccount;

  /// No description provided for @authSignUpLink.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignUpLink;

  /// No description provided for @signupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signupTitle;

  /// No description provided for @signupDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign up to get started'**
  String get signupDesc;

  /// No description provided for @signupConfirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get signupConfirmPasswordHint;

  /// No description provided for @signupConfirmPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Please confirm password'**
  String get signupConfirmPasswordError;

  /// No description provided for @signupPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get signupPasswordMismatch;

  /// No description provided for @signupButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signupButton;

  /// No description provided for @pressBackAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get pressBackAgainToExit;

  /// No description provided for @accountLocalUser.
  ///
  /// In en, this message translates to:
  /// **'Local User'**
  String get accountLocalUser;

  /// No description provided for @accountStatsActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get accountStatsActivities;

  /// No description provided for @accountStatsStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get accountStatsStreak;

  /// No description provided for @accountStatsDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get accountStatsDays;

  /// No description provided for @accountLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get accountLanguage;

  /// No description provided for @accountSyncData.
  ///
  /// In en, this message translates to:
  /// **'Sync Data'**
  String get accountSyncData;

  /// No description provided for @accountDeleteLocalData.
  ///
  /// In en, this message translates to:
  /// **'Delete Local Data'**
  String get accountDeleteLocalData;

  /// No description provided for @accountHelpFeedback.
  ///
  /// In en, this message translates to:
  /// **'Help & Feedback'**
  String get accountHelpFeedback;

  /// No description provided for @accountSelectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get accountSelectLanguage;

  /// No description provided for @accountSelectTheme.
  ///
  /// In en, this message translates to:
  /// **'Select Theme'**
  String get accountSelectTheme;

  /// No description provided for @accountSyncSignInMsg.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync data'**
  String get accountSyncSignInMsg;

  /// No description provided for @accountSyncingMsg.
  ///
  /// In en, this message translates to:
  /// **'Syncing data...'**
  String get accountSyncingMsg;

  /// No description provided for @accountSyncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data synced successfully'**
  String get accountSyncSuccess;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Local Data?'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will clear all links saved locally. Links synced continuously with the cloud will be restored on next sync.'**
  String get accountDeleteConfirm;

  /// No description provided for @accountCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get accountCancel;

  /// No description provided for @accountDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get accountDelete;

  /// No description provided for @accountDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Local data functionally deleted. Restart or Sync.'**
  String get accountDeleteSuccess;

  /// No description provided for @accountDeleteFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear local data.'**
  String get accountDeleteFail;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get langHindi;

  /// No description provided for @langGujarati.
  ///
  /// In en, this message translates to:
  /// **'Gujarati'**
  String get langGujarati;

  /// No description provided for @langArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get langArabic;

  /// No description provided for @authErrUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No user found for that email.'**
  String get authErrUserNotFound;

  /// No description provided for @authErrWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password provided for that user.'**
  String get authErrWrongPassword;

  /// No description provided for @authErrEmailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'The account already exists for that email.'**
  String get authErrEmailAlreadyInUse;

  /// No description provided for @authErrWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'The password provided is too weak.'**
  String get authErrWeakPassword;

  /// No description provided for @authErrInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'The email address is malformed.'**
  String get authErrInvalidEmail;

  /// No description provided for @authErrDefault.
  ///
  /// In en, this message translates to:
  /// **'An authentication error occurred: {message}'**
  String authErrDefault(Object message);

  /// No description provided for @newCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get newCategoryTitle;

  /// No description provided for @newCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Category name (e.g. Gaming)'**
  String get newCategoryHint;

  /// No description provided for @newCategoryAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get newCategoryAdd;

  /// No description provided for @deleteCategoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this category? Saved links will keep the tag but it will no longer appear as a filter.'**
  String get deleteCategoryConfirm;

  /// No description provided for @linkEditLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get linkEditLabel;

  /// No description provided for @linkDeleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get linkDeleteLabel;

  /// No description provided for @linkDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Link?'**
  String get linkDeleteTitle;

  /// No description provided for @linkDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get linkDeleteMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'gu', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
