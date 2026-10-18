import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/constants/hive_constants.dart';
import 'package:link_hive/core/models/conflict_record.dart';
import 'package:link_hive/core/models/sync_operation.dart';
import 'package:link_hive/core/models/sync_tombstone.dart';
import 'package:link_hive/core/services/cloud_sync_service.dart';
import 'package:link_hive/core/utils/hive_helper.dart';
import 'package:link_hive/features/links/models/category_model.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:link_hive/features/links/repository/local_data_store.dart';

import '../../helpers/fake_firebase_firestore_service.dart';

/// Push behavior that lives in [CloudSyncService] itself, with a real store
/// and a fake cloud.
void main() {
  const uid = 'account-a';

  late Directory hiveDirectory;
  late FakeFirebaseFirestoreService cloud;
  late _FlakyRepository repository;
  late CloudSyncService cloudSync;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'linkhive-cloud-sync-test-',
    );
    Hive.init(hiveDirectory.path);
    Hive.registerAdapter(LinkModelAdapter());
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(SyncOperationAdapter());
    Hive.registerAdapter(SyncTombstoneAdapter());
    Hive.registerAdapter(ConflictRecordAdapter());
  });

  setUp(() async {
    await Hive.openBox(HiveConstants.settingsBox);
    await Hive.openBox<LinkModel>(HiveConstants.linksBox);
    await Hive.openBox<LinkModel>(HiveConstants.baseLinksBox);
    await Hive.openBox<LinkModel>(HiveConstants.conflictLinksBox);
    await Hive.openBox<CategoryModel>(HiveConstants.categoriesBox);
    await Hive.openBox<SyncOperation>(HiveConstants.syncOperationsBox);
    await Hive.openBox<SyncTombstone>(HiveConstants.syncTombstonesBox);
    await Hive.openBox<ConflictRecord>(HiveConstants.conflictRecordsBox);
    await Future.wait([
      Hive.box(HiveConstants.settingsBox).clear(),
      Hive.box<LinkModel>(HiveConstants.linksBox).clear(),
      Hive.box<LinkModel>(HiveConstants.baseLinksBox).clear(),
      Hive.box<LinkModel>(HiveConstants.conflictLinksBox).clear(),
      Hive.box<CategoryModel>(HiveConstants.categoriesBox).clear(),
      Hive.box<SyncOperation>(HiveConstants.syncOperationsBox).clear(),
      Hive.box<SyncTombstone>(HiveConstants.syncTombstonesBox).clear(),
      Hive.box<ConflictRecord>(HiveConstants.conflictRecordsBox).clear(),
    ]);

    cloud = FakeFirebaseFirestoreService();
    repository = _FlakyRepository();
    cloudSync = CloudSyncService(
      firebaseService: cloud,
      store: repository,
      uidProvider: () => uid,
    );
  });

  tearDown(() => Hive.close());
  tearDownAll(() => hiveDirectory.delete(recursive: true));

  test('a phone write that fails after a successful upload keeps the change '
      'queued for a retry', () async {
    await repository.addLink(
      const LinkModel(
        id: 'a-1',
        url: 'https://example.com/a-1',
        title: 'a-1',
        createdAt: 100,
      ),
    );
    repository.failNextFinish = true;

    await cloudSync.push();

    expect(cloud.linksOf(uid).single.id, 'a-1');
    final operation = repository.pendingSyncOperations.single;
    expect(operation.state, SyncOperation.failed);
    expect(operation.attemptCount, 1);
    expect(cloudSync.lastFailure, isNotNull);
    expect(repository.getLinkById('a-1')!.isSynced, isFalse);
  });
}

/// A real store whose next "record the upload" write fails, like a full disk.
class _FlakyRepository extends LinkRepository {
  _FlakyRepository() : super(hiveHelper: HiveHelper());

  bool failNextFinish = false;

  @override
  Future<bool> finishPushed(SyncRunToken run, SyncOperation operation) {
    if (failNextFinish) {
      failNextFinish = false;
      throw const FileSystemException('No space left on device');
    }
    return super.finishPushed(run, operation);
  }
}
