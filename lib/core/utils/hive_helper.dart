import 'package:hive_flutter/hive_flutter.dart';

import '../../features/links/models/category_model.dart';
import '../../features/links/models/link_model.dart';
import '../models/conflict_record.dart';
import '../models/sync_operation.dart';
import '../models/sync_tombstone.dart';

import '../constants/hive_constants.dart';

class HiveHelper {
  /// Initialize Hive, register adapters, and open all required boxes.
  /// This should be called once in main().
  Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(LinkModelAdapter());
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(SyncOperationAdapter());
    Hive.registerAdapter(SyncTombstoneAdapter());
    Hive.registerAdapter(ConflictRecordAdapter());

    // Open Boxes
    await Hive.openBox(HiveConstants.settingsBox);
    await Hive.openBox<LinkModel>(HiveConstants.linksBox);
    await Hive.openBox<LinkModel>(HiveConstants.baseLinksBox);
    await Hive.openBox<LinkModel>(HiveConstants.conflictLinksBox);
    await Hive.openBox<CategoryModel>(HiveConstants.categoriesBox);
    await Hive.openBox<SyncOperation>(HiveConstants.syncOperationsBox);
    await Hive.openBox<SyncTombstone>(HiveConstants.syncTombstonesBox);
    await Hive.openBox<ConflictRecord>(HiveConstants.conflictRecordsBox);
  }

  // Box Getters
  Box get settingsBox => Hive.box(HiveConstants.settingsBox);
  Box<LinkModel> get linksBox => Hive.box<LinkModel>(HiveConstants.linksBox);
  Box<LinkModel> get baseLinksBox =>
      Hive.box<LinkModel>(HiveConstants.baseLinksBox);
  Box<LinkModel> get conflictLinksBox =>
      Hive.box<LinkModel>(HiveConstants.conflictLinksBox);
  Box<CategoryModel> get categoriesBox =>
      Hive.box<CategoryModel>(HiveConstants.categoriesBox);
  Box<SyncOperation> get syncOperationsBox =>
      Hive.box<SyncOperation>(HiveConstants.syncOperationsBox);
  Box<SyncTombstone> get syncTombstonesBox =>
      Hive.box<SyncTombstone>(HiveConstants.syncTombstonesBox);
  Box<ConflictRecord> get conflictRecordsBox =>
      Hive.box<ConflictRecord>(HiveConstants.conflictRecordsBox);
}
