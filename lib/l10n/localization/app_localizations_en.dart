// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LinkHive';

  @override
  String get homeTitle => 'Links';

  @override
  String get profileTitle => 'Profile';

  @override
  String get addLinkTitle => 'Add Link';

  @override
  String get homeEmptyStateTitle => 'No Links yet!';

  @override
  String get homeEmptyStateSubtitle =>
      'Get started by saving your first Web Link.';

  @override
  String get addLinkButton => 'Add Link';

  @override
  String get searchHint => 'Search links...';

  @override
  String get categoryAll => 'All';

  @override
  String get homeCategoriesLabel => 'Categories';

  @override
  String get homePrioritiesLabel => 'Priorities';

  @override
  String get catDev => 'Dev';

  @override
  String get catDesign => 'Design';

  @override
  String get catRead => 'Read';

  @override
  String get catTools => 'Tools';

  @override
  String get catDocs => 'Docs';

  @override
  String get catAI => 'AI';

  @override
  String get catFinance => 'Finance';

  @override
  String get catNews => 'News';

  @override
  String get addLinkUrlLabel => 'URL';

  @override
  String get addLinkUrlHint => 'https://example.com';

  @override
  String get addLinkPageTitleLabel => 'Title';

  @override
  String get addLinkPageTitleHint => 'Page title';

  @override
  String get addLinkDescLabel => 'Description';

  @override
  String get addLinkDescHint => 'Optional description';

  @override
  String get addLinkPriorityLabel => 'Priority';

  @override
  String get addLinkCategoriesLabel => 'Categories';

  @override
  String get saveLinkButton => 'Save Link';

  @override
  String get linkSavedSuccess => 'Link saved!';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityNormal => 'Normal';

  @override
  String get priorityLow => 'Low';

  @override
  String get navLinks => 'Links';

  @override
  String get accountTitle => 'Profile';

  @override
  String get accountSignInPromo => 'Sign in to backup your links';

  @override
  String get accountSignInDesc =>
      'Keep your collection safe and synced across devices.';

  @override
  String get accountStatSynced => 'Synced to Cloud';

  @override
  String get accountStatLocal => 'Local Only';

  @override
  String get accountSettings => 'Settings';

  @override
  String get accountTheme => 'Theme';

  @override
  String get accountThemeDark => 'Dark Mode';

  @override
  String get accountThemeLight => 'Light Mode';

  @override
  String get accountThemeSystem => 'System Default';

  @override
  String get accountExport => 'Export Data';

  @override
  String get accountExportDesc => 'Download a backup';

  @override
  String get accountAbout => 'About';

  @override
  String get accountVersion => 'Version 1.0.0';

  @override
  String get accountSignOut => 'Sign Out';

  @override
  String get accountSignedOutSuccess => 'Signed out successfully';

  @override
  String get authWelcome => 'Welcome Back!';

  @override
  String get authSignInDesc => 'Sign in to your account';

  @override
  String get authEmailHint => 'Email';

  @override
  String get authEmailError => 'Please enter email';

  @override
  String get authPasswordHint => 'Password';

  @override
  String get authPasswordError => 'Password must be at least 6 characters';

  @override
  String get authSignInButton => 'Sign In';

  @override
  String get authOr => 'OR';

  @override
  String get authGoogleSignIn => 'Sign in with Google';

  @override
  String get authNoAccount => 'Don\'t have an account? ';

  @override
  String get authSignUpLink => 'Sign Up';

  @override
  String get signupTitle => 'Create Account';

  @override
  String get signupDesc => 'Sign up to get started';

  @override
  String get signupConfirmPasswordHint => 'Confirm Password';

  @override
  String get signupConfirmPasswordError => 'Please confirm password';

  @override
  String get signupPasswordMismatch => 'Passwords do not match';

  @override
  String get signupButton => 'Sign Up';

  @override
  String get pressBackAgainToExit => 'Press back again to exit';

  @override
  String get accountLocalUser => 'Local User';

  @override
  String get accountStatsActivities => 'Activities';

  @override
  String get accountStatsStreak => 'Streak';

  @override
  String get accountStatsDays => 'days';

  @override
  String get accountLanguage => 'Language';

  @override
  String get accountSyncData => 'Sync Data';

  @override
  String get accountDeleteLocalData => 'Delete Local Data';

  @override
  String get accountHelpFeedback => 'Help & Feedback';

  @override
  String get accountSelectLanguage => 'Select Language';

  @override
  String get accountSelectTheme => 'Select Theme';

  @override
  String get accountSyncSignInMsg => 'Sign in to sync data';

  @override
  String get accountSyncingMsg => 'Syncing data...';

  @override
  String get accountSyncSuccess => 'Data synced successfully';

  @override
  String get accountDeleteTitle => 'Delete Local Data?';

  @override
  String get accountDeleteConfirm =>
      'This will clear all links saved locally. Links synced continuously with the cloud will be restored on next sync.';

  @override
  String get accountCancel => 'Cancel';

  @override
  String get accountDelete => 'Delete';

  @override
  String get accountDeleteSuccess =>
      'Local data functionally deleted. Restart or Sync.';

  @override
  String get accountDeleteFail => 'Failed to clear local data.';

  @override
  String get langEnglish => 'English';

  @override
  String get langHindi => 'Hindi';

  @override
  String get langGujarati => 'Gujarati';

  @override
  String get langArabic => 'Arabic';

  @override
  String get authErrUserNotFound => 'No user found for that email.';

  @override
  String get authErrWrongPassword => 'Wrong password provided for that user.';

  @override
  String get authErrEmailAlreadyInUse =>
      'The account already exists for that email.';

  @override
  String get authErrWeakPassword => 'The password provided is too weak.';

  @override
  String get authErrInvalidEmail => 'The email address is malformed.';

  @override
  String authErrDefault(Object message) {
    return 'An authentication error occurred: $message';
  }

  @override
  String get newCategoryTitle => 'New Category';

  @override
  String get newCategoryHint => 'Category name (e.g. Gaming)';

  @override
  String get newCategoryAdd => 'Add';

  @override
  String get deleteCategoryConfirm =>
      'Delete this category? Saved links will keep the tag but it will no longer appear as a filter.';

  @override
  String get linkEditLabel => 'Edit';

  @override
  String get linkDeleteLabel => 'Delete';

  @override
  String get linkDeleteTitle => 'Delete Link?';

  @override
  String get linkDeleteMessage => 'This action cannot be undone.';
}
