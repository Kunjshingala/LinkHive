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

  /// deletedAt — used in deleted_links collection
  static const String linkDeletedAt = 'deletedAt';

  // Category Fields
  /// name
  static const String categoryName = 'name';
}
