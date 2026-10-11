import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/constants/hive_constants.dart';
import 'package:link_hive/core/models/conflict_record.dart';
import 'package:link_hive/core/models/sync_operation.dart';
import 'package:link_hive/core/models/sync_tombstone.dart';
import 'package:link_hive/core/utils/hive_helper.dart';
import 'package:link_hive/features/links/models/category_model.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';

import '../../helpers/fake_firebase_firestore_service.dart';

/// Two accounts using one phone, with a real Hive store and a fake cloud.
///
/// See `.ai/context/sync-contract.md` for the rules these tests protect.
void main() {
  const accountA = 'account-a';
  const accountB = 'account-b';

  late Directory hiveDirectory;
  late FakeFirebaseFirestoreService cloud;
  late LinkRepository repository;
  String? currentUid;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'linkhive-accounts-test-',
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

    currentUid = null;
    cloud = FakeFirebaseFirestoreService();
    repository = LinkRepository(
      firebaseService: cloud,
      hiveHelper: HiveHelper(),
      uidProvider: () => currentUid,
    );
  });

  tearDown(() => Hive.close());
  tearDownAll(() => hiveDirectory.delete(recursive: true));

  LinkModel link(String id, {int createdAt = 100}) => LinkModel(
    id: id,
    url: 'https://example.com/$id',
    title: id,
    createdAt: createdAt,
  );

  List<String> localIds() =>
      (repository.queryLinks(limit: 100).map((l) => l.id).toList()..sort());

  test('guest links merge into the first account that syncs', () async {
    cloud.seedLink(accountA, link('a-1'), syncedAt: 1000);
    await repository.addLink(link('guest-1'));
    await repository.addLink(link('guest-2'));

    currentUid = accountA;
    await repository.syncPendingLinks();
    await repository.pullFromCloud();

    expect(localIds(), ['a-1', 'guest-1', 'guest-2']);
    expect(cloud.linksOf(accountA).map((l) => l.id).toSet(), {
      'a-1',
      'guest-1',
      'guest-2',
    });
  });

  test(
    'switching accounts without a wipe still shows the new account\'s older links (#7)',
    () async {
      cloud.seedLink(accountA, link('a-1'), syncedAt: 1000);
      cloud.seedLink(accountB, link('b-1'), syncedAt: 1000);
      cloud.seedLink(accountB, link('b-2'), syncedAt: 2000);

      currentUid = accountA;
      await repository.pullFromCloud(); // the cursor is now "just now"
      currentUid = accountB; // sign-out cleared nothing
      await repository.pullFromCloud();

      expect(localIds(), ['b-1', 'b-2']);
    },
    skip: 'Fails until the owner check lands (#7); enabled in that commit.',
  );

  test(
    'another account\'s queued delete is not pushed into the new account (#8)',
    () async {
      cloud.seedLink(accountA, link('a-1'), syncedAt: 1000);

      currentUid = accountA;
      await repository.pullFromCloud();
      currentUid = null; // signed out, nothing wiped
      await repository.deleteLink('a-1'); // queues a delete operation
      currentUid = accountB;
      await repository.syncPendingLinks();

      expect(cloud.deletedLinkIdsOf(accountB), isEmpty);
      expect(cloud.linksOf(accountA).map((l) => l.id), ['a-1']);
    },
    skip: 'Fails until the owner check lands (#8); enabled in that commit.',
  );
}
