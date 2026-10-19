class HiveConstants {
  HiveConstants._();

  // Boxes
  static const String settingsBox = 'settings_box';
  static const String linksBox = 'links_box';
  static const String baseLinksBox = 'base_links_box';
  static const String conflictLinksBox = 'conflict_links_box';
  static const String categoriesBox = 'categories_box';
  static const String syncOperationsBox = 'sync_operations_box';
  static const String syncTombstonesBox = 'sync_tombstones_box';
  static const String conflictRecordsBox = 'conflict_records_box';

  // Settings Keys
  static const String themeKey = 'theme_mode';
  static const String localeKey = 'locale_language';
  static const String lastPulledAtKey = 'last_pulled_at';

  /// The uid whose data the sync boxes hold. Absent for a guest.
  static const String ownerUidKey = 'owner_uid';

  /// Set while the phone is being wiped, so an interrupted wipe is finished at
  /// the next launch.
  static const String wipePendingKey = 'wipe_pending';

  /// The uid whose "Delete cloud data" has not finished yet. Survives a wipe:
  /// the next sync for that account finishes the delete first.
  static const String cloudDeletePendingUidKey = 'cloud_delete_pending_uid';
}
