class FirebaseConstants {
  FirebaseConstants._();

  // Collections
  /// users
  static const String usersCol = 'users';

  /// links
  static const String linksCol = 'links';

  /// categories
  static const String categoriesCol = 'categories';

  /// deleted_links
  static const String deletedLinksCol = 'deleted_links';
  static const String deletedCategoriesCol = 'deleted_categories';

  // Link Fields
  /// url
  static const String linkUrl = 'url';

  /// title
  static const String linkTitle = 'title';

  /// description
  static const String linkDescription = 'description';

  /// image
  static const String linkImage = 'image';

  /// categories
  static const String linkCategories = 'categories';

  /// priority
  static const String linkPriority = 'priority';

  /// createdAt
  static const String linkCreatedAt = 'createdAt';

  /// syncedAt — set by Firestore server timestamp on sync
  static const String linkSyncedAt = 'syncedAt';

  /// isRead — true once the user has opened the link at least once
  static const String linkIsRead = 'isRead';

  /// isQuickSaved — true for instant share-saves not yet organized (Inbox)
  static const String linkIsQuickSaved = 'isQuickSaved';

  /// resurfaceAt — when the Daily Resurface engine should next offer this link
  static const String linkResurfaceAt = 'resurfaceAt';

  /// lastResurfacedAt — last time this link was picked by Daily Resurface
  static const String linkLastResurfacedAt = 'lastResurfacedAt';

  /// deletedAt — used in deleted_links collection
  static const String linkDeletedAt = 'deletedAt';

  // Category Fields
  /// name
  static const String categoryName = 'name';
}
