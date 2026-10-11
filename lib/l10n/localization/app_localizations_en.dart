// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get categoryAlreadyExists => 'This category already exists.';

  @override
  String get homeNoResultsTitle => 'No matching links';

  @override
  String get homeNoResultsSubtitle => 'Try changing your search or filters.';

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
  String get searchClearTooltip => 'Clear search';

  @override
  String get categoryAll => 'All';

  @override
  String get homeSectionToday => 'Today';

  @override
  String get homeSectionThisWeek => 'This week';

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
  String get catWatch => 'Watch';

  @override
  String get catShop => 'Shop';

  @override
  String get catRecipes => 'Recipes';

  @override
  String get catTravel => 'Travel';

  @override
  String get catLearn => 'Learn';

  @override
  String get catWork => 'Work';

  @override
  String get catIdeas => 'Ideas';

  @override
  String get addLinkUrlLabel => 'URL';

  @override
  String get addLinkUrlHint => 'https://example.com';

  @override
  String get addLinkUrlEmptyError => 'Please enter a URL';

  @override
  String get addLinkInvalidUrlError => 'Please enter a valid URL';

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
  String get addLinkWhenLabel => 'When should this come back?';

  @override
  String get addLinkWhenTonight => 'Tonight';

  @override
  String get addLinkWhenWeekend => 'Weekend';

  @override
  String get addLinkWhenSomeday => 'Someday';

  @override
  String get addLinkCategoriesLabel => 'Categories';

  @override
  String get saveLinkButton => 'Save Link';

  @override
  String get linkSavedSuccess => 'Link saved!';

  @override
  String get sharedSaveConfirm => 'Saved to LinkHive';

  @override
  String get sharedAddDetails => 'Add details';

  @override
  String get sharedUndo => 'Undo';

  @override
  String get inboxTitle => 'Inbox';

  @override
  String get inboxEmptyTitle => 'Inbox zero';

  @override
  String get inboxEmptySubtitle =>
      'Links you save in a hurry land here. Add details to file them away.';

  @override
  String get todayTitle => 'Today';

  @override
  String get todayEmptyTitle => 'All caught up';

  @override
  String get todayEmptySubtitle => 'Nothing waiting to be read right now.';

  @override
  String get todayOpen => 'Open';

  @override
  String get todayArchive => 'Archive';

  @override
  String get todaySnooze => 'Snooze';

  @override
  String get todaySnoozedConfirm => 'Snoozed for later';

  @override
  String get todayArchivedConfirm => 'Archived';

  @override
  String get todayBrowseLibrary => 'Browse links';

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
  String get accountSignOutDesc =>
      'Everything is saved in your account. Signing out clears this phone, and your links come back when you sign in.';

  @override
  String accountSignOutPending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes are not synced yet. If you sign out now, they are lost.',
      one: '1 change is not synced yet. If you sign out now, it is lost.',
    );
    return '$_temp0';
  }

  @override
  String accountSignOutSyncing(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Syncing $count changes. Wait for them to finish, or sign out and lose them.',
      one: 'Syncing 1 change. Wait for it to finish, or sign out and lose it.',
    );
    return '$_temp0';
  }

  @override
  String accountSignOutWaiting(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes are waiting for internet. If you sign out now, they are lost.',
      one: '1 change is waiting for internet. If you sign out now, it is lost.',
    );
    return '$_temp0';
  }

  @override
  String accountSignOutFailed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes could not sync. Try again, or sign out and lose them.',
      one: '1 change could not sync. Try again, or sign out and lose it.',
    );
    return '$_temp0';
  }

  @override
  String get accountSignOutConflicts =>
      'Some edits need your decision before they can sync. If you sign out now, they are lost.';

  @override
  String get accountSignOutSyncNow => 'Sync now';

  @override
  String get accountSignOutAnyway => 'Sign out anyway';

  @override
  String get accountSignedOutSuccess =>
      'Signed out. This phone\'s copy was cleared.';

  @override
  String get accountSignOutError => 'Couldn\'t sign out. Please try again.';

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
  String get accountSyncFail => 'Sync failed. Please try again.';

  @override
  String get accountSyncStatusReady => 'Ready to sync';

  @override
  String get accountSyncStatusSyncing => 'Syncing…';

  @override
  String get accountSyncStatusFailed => 'Sync failed';

  @override
  String get accountSyncStatusConflict => 'Conflicts need attention';

  @override
  String get accountSyncStatusWaiting => 'Waiting for internet';

  @override
  String get accountSyncStatusSynced => 'All synced';

  @override
  String get accountSyncStatusPending => 'Waiting to sync';

  @override
  String accountSyncLastSynced(String time) {
    return 'Last synced $time';
  }

  @override
  String get accountSyncNever => 'Not synced yet';

  @override
  String accountSyncPendingDetail(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes have not reached the cloud yet.',
      one: '1 change has not reached the cloud yet.',
    );
    return '$_temp0';
  }

  @override
  String accountSyncWaitingDetail(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes will sync when you are back online.',
      one: '1 change will sync when you are back online.',
    );
    return '$_temp0';
  }

  @override
  String accountSyncConflictDetail(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count edits need your decision.',
      one: '1 edit needs your decision.',
    );
    return '$_temp0';
  }

  @override
  String get accountSyncFailureTimeout => 'The cloud did not answer in time.';

  @override
  String get accountSyncFailurePermission =>
      'This account is not allowed to sync.';

  @override
  String get accountSyncFailureUnavailable =>
      'The cloud cannot be reached right now.';

  @override
  String get accountSyncFailureUnknown => 'Something went wrong while syncing.';

  @override
  String get accountRetry => 'Retry';

  @override
  String get accountResolveConflicts => 'Resolve conflicts';

  @override
  String get accountDeleteTitle => 'Delete Local Data?';

  @override
  String get accountDeleteConfirm =>
      'This clears the links on this phone. Everything synced comes back on the next sync.';

  @override
  String accountDeleteConfirmUnsynced(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This clears the links on this phone. $count changes that are not synced yet will be lost. Everything synced comes back on the next sync.',
      one:
          'This clears the links on this phone. 1 change that is not synced yet will be lost. Everything synced comes back on the next sync.',
    );
    return '$_temp0';
  }

  @override
  String get accountDeleteConfirmGuest =>
      'This clears every link on this phone. Nothing is saved in an account, so this cannot be undone.';

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
  String get accountDeleteCloudData => 'Delete Cloud Data';

  @override
  String get accountDeleteCloudTitle => 'Delete cloud data?';

  @override
  String accountDeleteCloudConfirm(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This permanently deletes the $count links saved in your account and clears this phone. This cannot be undone.',
      one:
          'This permanently deletes the 1 link saved in your account and clears this phone. This cannot be undone.',
      zero: 'No links are saved in your account. This only clears this phone.',
    );
    return '$_temp0';
  }

  @override
  String get accountDeleteCloudAction => 'Delete for good';

  @override
  String get accountDeleteCloudSuccess => 'Cloud data deleted';

  @override
  String get accountDeleteCloudFail =>
      'Could not delete cloud data. Try again.';

  @override
  String get accountActionReconfirm =>
      'Something changed while you were confirming. Please try again.';

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
  String get authErrInvalidCredential =>
      'Incorrect email or password. Please try again.';

  @override
  String authErrDefault(Object message) {
    return 'An authentication error occurred: $message';
  }

  @override
  String get authErrGoogleUnavailable =>
      'Google sign-in isn\'t available right now. Please sign in with your email.';

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

  @override
  String get linkUrlCopied => 'Link copied to clipboard';

  @override
  String linkOpenFailed(Object url) {
    return 'Could not open $url';
  }

  @override
  String sharedAlreadySaved(String date) {
    return 'Already saved $date, it\'ll come back in Today';
  }

  @override
  String sharedUnarchived(String date) {
    return 'You archived this $date, it\'ll come back in Today';
  }

  @override
  String get sharedAnotherVersion =>
      'Saved another version of this link, it\'ll come back in Today';

  @override
  String addAlreadySavedKept(String date) {
    return 'Already saved $date. Kept your existing details.';
  }

  @override
  String get sharedSaveFailed => 'Couldn\'t save this link. Try sharing again.';

  @override
  String get sharedOnlyUrls => 'Only URL links can be saved to LinkHive';

  @override
  String get dateToday => 'today';

  @override
  String get dateYesterday => 'yesterday';

  @override
  String todaySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved $count×',
    );
    return '$_temp0';
  }

  @override
  String todaySavedCountA11y(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved $count times',
      one: 'Saved once',
    );
    return '$_temp0';
  }

  @override
  String get versionPickerTitle => 'Which version?';

  @override
  String get versionPickerSavedFirst => 'Saved first';

  @override
  String get versionPickerNoTracking => 'no tracking';

  @override
  String get versionPickerKeepOnly => 'Keep only this one';

  @override
  String libraryLinkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links',
      one: '1 link',
    );
    return '$_temp0';
  }

  @override
  String get libraryUnread => 'Unread';

  @override
  String get librarySavedTwice => 'Saved 2×+';

  @override
  String get libraryRead => 'Read';

  @override
  String get listTabAll => 'All';

  @override
  String get listFilterSource => 'Source';

  @override
  String get listSortTitle => 'Sort by';

  @override
  String get sortNewest => 'Newest first';

  @override
  String get sortOldest => 'Oldest first';

  @override
  String get sortPriority => 'Priority';

  @override
  String get sortMostSaved => 'Most saved';

  @override
  String get sortSite => 'By site';

  @override
  String listSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get listSelectAll => 'Select all';

  @override
  String get listCancelSelection => 'Cancel selection';

  @override
  String get bulkMarkRead => 'Mark read';

  @override
  String get bulkCategory => 'Category';

  @override
  String bulkDeleteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count links?',
      one: 'Delete 1 link?',
    );
    return '$_temp0';
  }

  @override
  String get bulkCategoryTitle => 'Add a category';

  @override
  String bulkCategorySuggested(String host) {
    return 'Suggested for $host';
  }

  @override
  String get bulkCategoryAll => 'All categories';

  @override
  String bulkCategoryApply(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add to $count links',
      one: 'Add to 1 link',
    );
    return '$_temp0';
  }

  @override
  String linksSearchHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Search $count links...',
      one: 'Search 1 link...',
    );
    return '$_temp0';
  }

  @override
  String sourceSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sites',
      one: '1 site',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchHint => 'Find a site...';

  @override
  String get sourceAll => 'All sites';

  @override
  String get categoryNone => 'No category';

  @override
  String get listSelectTitle => 'Select links';

  @override
  String get listSelect => 'Select';

  @override
  String get editLinkTitle => 'Update Link';

  @override
  String get updateLinkButton => 'Update Link';

  @override
  String get linkCopyUrl => 'Copy URL';

  @override
  String get linkShare => 'Share';

  @override
  String get conflictsEmpty => 'No conflicts require attention.';

  @override
  String get conflictDeletedInCloud => 'Deleted in cloud';

  @override
  String conflictLocalVersion(String title) {
    return 'Local: $title';
  }

  @override
  String conflictCloudVersion(String title) {
    return 'Cloud: $title';
  }

  @override
  String conflictFields(String fields) {
    return 'Fields: $fields';
  }

  @override
  String get conflictKeepLocal => 'Keep local';

  @override
  String get conflictKeepCloud => 'Keep cloud';

  @override
  String get notificationTitle => 'Links waiting';

  @override
  String get notificationBody =>
      'You saved something worth another look — tap to see one.';

  @override
  String get notificationChannelName => 'Daily Resurface';

  @override
  String get notificationChannelDescription =>
      'One daily reminder to look at a saved link';

  @override
  String get widgetTodaysPick => 'Today\'s pick';

  @override
  String get widgetNothingWaiting => 'Nothing waiting';
}
